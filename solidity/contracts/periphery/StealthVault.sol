// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {ReentrancyGuard} from 'openzeppelin/security/ReentrancyGuard.sol';
import {IERC20, SafeERC20} from 'openzeppelin/token/ERC20/utils/SafeERC20.sol';
import {_NATIVE_TOKEN} from '../../utils/Constants.sol';

import {IStealthVault} from '../../interfaces/periphery/IStealthVault.sol';

/*
 * StealthVault
 */
contract StealthVault is IStealthVault, ReentrancyGuard {
  using SafeERC20 for IERC20;

  address public owner;
  address public pendingOwner;
  address public manager;
  address public pendingManager;
  uint256 public totalBonded;

  uint256 public gasBuffer = 69_420;
  uint256 public penalty = 1 ether;

  mapping(address _caller => uint256 _amount) public bonded;
  mapping(address _caller => uint256 _unboundAt) public canUnbondAt;
  mapping(bytes32 _hash => address _reportedBy) public hashReportedBy;

  constructor(address _owner, address _manager) {
    owner = _owner;
    manager = _manager;
  }

  function isStealthVault() external pure returns (bool) {
    return true;
  }

  function changeOwner(address _pendingOwner) external onlyOwner {
    pendingOwner = _pendingOwner;
    emit ChangeOwner(_pendingOwner);
  }

  function acceptOwner() external onlyPendingOwner {
    pendingOwner = address(0);
    owner = msg.sender;
    emit AcceptOwner(msg.sender);
  }

  function changeManager(address _pendingManager) external onlyOwner {
    pendingManager = _pendingManager;
    emit ChangeManager(_pendingManager);
  }

  function acceptManager() external onlyPendingManager {
    manager = pendingManager;
    pendingManager = address(0);
    emit AcceptManager(msg.sender);
  }

  function setPenalty(uint256 _penalty) external onlyOwner {
    if (_penalty == 0) revert StealthVault_ZeroPenalty();
    penalty = _penalty;
    emit PenaltySet(_penalty);
  }

  function bond() external payable nonReentrant {
    if (msg.value == 0) revert StealthVault_ZeroAmount();
    uint256 _bondedAmount = bonded[msg.sender] + msg.value;
    bonded[msg.sender] = _bondedAmount;
    totalBonded = totalBonded + msg.value;
    emit Bonded(msg.sender, msg.value, _bondedAmount);
  }

  function unbondAll() external {
    unbond(bonded[msg.sender]);
  }

  function startUnbond() public nonReentrant {
    canUnbondAt[msg.sender] = block.timestamp + 4 days;
  }

  function cancelUnbond() public nonReentrant {
    canUnbondAt[msg.sender] = 0;
  }

  function unbond(uint256 _amount) public nonReentrant {
    if (_amount > bonded[msg.sender]) revert StealthVault_AmountHigh();

    uint256 _canUnbondAt = canUnbondAt[msg.sender];
    if (_canUnbondAt > block.timestamp) revert StealthVault_UnbondCooldown();

    bonded[msg.sender] -= _amount;
    totalBonded -= _amount;
    canUnbondAt[msg.sender] = 0;

    (bool _success,) = payable(msg.sender).call{value: _amount}('');
    if (!_success) revert StealthVault_PaymentFailed();
    emit Unbonded(msg.sender, _amount, bonded[msg.sender]);
  }

  function preHook(
    address _relayCaller,
    address _relay,
    bytes memory _dataToExecute
  ) external returns (bytes memory _returnData) {
    (bytes memory _decodeData, bytes32 _hash, uint256 _blockNumber) =
      abi.decode(_dataToExecute, (bytes, bytes32, uint256));

    if (_blockNumber != block.number) revert StealthVault_WrongBlock();

    if (_validateHash(_relayCaller, _hash, penalty)) {
      _returnData = _decodeData;
    }
  }

  function reportHash(bytes32 _hash) external nonReentrant {
    _reportHash(_hash);
  }

  function reportHashAndPay(bytes32 _hash) external payable nonReentrant {
    _reportHash(_hash);
    (bool _success,) = block.coinbase.call{value: msg.value}('');
    if (!_success) revert StealthVault_PaymentFailed();
  }

  function setGasBuffer(uint256 _gasBuffer) external virtual onlyManager {
    uint256 _gasLimit = (block.gaslimit * 63) / 64;
    if (_gasBuffer > _gasLimit) revert StealthVault_GasBufferHigh();
    gasBuffer = _gasBuffer;
  }

  function transferOwnerBond(address _caller, uint256 _amount) external onlyOwner {
    bonded[owner] -= _amount;
    bonded[_caller] += _amount;
  }

  function transferBondToOwner(address _caller, uint256 _amount) external onlyOwner {
    bonded[_caller] -= _amount;
    bonded[owner] += _amount;
  }

  function sendDust(address _receiver, address _token, uint256 _amount) external onlyOwner {
    // If the token is the native token, transfer the funds to the receiver, otherwise transfer the tokens
    if (_token == _NATIVE_TOKEN) {
      (bool _success,) = _receiver.call{value: _amount}('');
      if (!_success) revert StealthVault_PaymentFailed();
    } else {
      IERC20(_token).safeTransfer(_receiver, _amount);
    }

    // Emit the event
    emit WithdrawFunds(_token, _amount, _receiver);
  }

  function _validateHash(
    address _caller,
    bytes32 _hash,
    uint256 _penalty
  ) internal OnlyOneCallStack nonReentrant returns (bool _valid) {
    // Caller is required to be an EOA to avoid on-chain hash generation to bypass penalty.
    // solhint-disable-next-line avoid-tx-origin
    if (_caller != tx.origin) revert StealthVault_NotEOA();
    if (_penalty > bonded[_caller]) revert StealthVault_NotEnoughBonded();
    if (canUnbondAt[_caller] != 0) revert StealthVault_Unbonding();

    address _reportedBy = hashReportedBy[_hash];
    if (_reportedBy != address(0)) {
      // User reported this TX as public, locking penalty away
      _penalize(_caller, _penalty, _reportedBy);

      // invalid: has was reported
      _valid = false;
      emit PenaltyApplied(_hash, _caller, _penalty, _reportedBy);
    }

    // valid: hash was not reported
    _valid = true;
    emit ValidatedHash(_hash, _caller, _penalty);
  }

  function _penalize(address _caller, uint256 _penalty, address _reportedBy) internal {
    bonded[_caller] -= _penalty;
    uint256 _amountReward = _penalty / 10;
    bonded[_reportedBy] += _amountReward;
    bonded[owner] += (_penalty - _amountReward);
  }

  function _reportHash(bytes32 _hash) internal {
    if (hashReportedBy[_hash] != address(0)) revert StealthVault_HashAlreadyReported();
    hashReportedBy[_hash] = msg.sender;
    emit ReportedHash(_hash, msg.sender);
  }

  modifier OnlyOneCallStack() {
    uint256 _gasLeftPlusBuffer = gasleft() + gasBuffer;
    uint256 _gasLimit = (block.gaslimit * 63) / 64;
    if (_gasLimit > _gasLeftPlusBuffer) revert StealthVault_GasLimit();
    _;
  }

  /**
   * @notice Checks that the caller is the owner
   */
  modifier onlyOwner() {
    address _owner = owner;
    if (msg.sender != _owner) revert StealthVault_OnlyOwner();
    _;
  }

  /**
   * @notice Checks that the caller is the pending owner
   */
  modifier onlyPendingOwner() {
    address _pendingOwner = pendingOwner;
    if (msg.sender != _pendingOwner) revert StealthVault_OnlyPendingOwner();
    _;
  }

  modifier onlyManager() {
    address _manager = manager;
    if (msg.sender != _manager) revert StealthVault_OnlyManager();
    _;
  }

  modifier onlyPendingManager() {
    address _pendingManager = pendingManager;
    if (msg.sender != _pendingManager) revert StealthVault_OnlyPendingManager();
    _;
  }
}
