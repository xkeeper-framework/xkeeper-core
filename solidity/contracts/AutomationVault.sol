// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IAutomationVault} from '@interfaces/IAutomationVault.sol';
import {IERC20, SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';
import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';
import {_ETH, _NULL} from '@contracts/utils/Constants.sol';

contract AutomationVault is IAutomationVault {
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableSet for EnumerableSet.Bytes32Set;

  /// @inheritdoc IAutomationVault
  address public owner;
  /// @inheritdoc IAutomationVault
  address public pendingOwner;
  /// @inheritdoc IAutomationVault
  string public organizationName;

  mapping(address _relay => EnumerableSet.AddressSet _enabledCallers) internal _relayEnabledCallers;

  function relayEnabledCallers(address _relay) external view returns (address[] memory _enabledCallers) {
    return _relayEnabledCallers[_relay].values();
  }

  mapping(address _job => EnumerableSet.Bytes32Set _enabledSelectors) internal _jobEnabledFunctions;

  function jobEnabledFunctions(address _job) external view returns (bytes32[] memory _enabledSelectors) {
    return _jobEnabledFunctions[_job].values();
  }

  EnumerableSet.AddressSet internal _relays;

  function relays() external view returns (address[] memory __relays) {
    return _relays.values();
  }

  EnumerableSet.AddressSet internal _jobs;

  function jobs() external view returns (address[] memory __jobs) {
    return _jobs.values();
  }

  constructor(address _owner, string memory _organizationName) payable {
    owner = _owner;
    organizationName = _organizationName;
  }

  /// @inheritdoc IAutomationVault
  function changeOwner(address _pendingOwner) external onlyOwner {
    pendingOwner = _pendingOwner;
    emit ChangeOwner(_pendingOwner);
  }

  /// @inheritdoc IAutomationVault
  function acceptOwner() external onlyPendingOwner {
    pendingOwner = address(0);
    owner = msg.sender;
    emit AcceptOwner(msg.sender);
  }

  /// @inheritdoc IAutomationVault
  function withdrawFunds(address _token, uint256 _amount, address _receiver) external payable onlyOwner {
    if (_token == _ETH) {
      (bool _success,) = _receiver.call{value: _amount}('');
      if (!_success) revert AutomationVault_ETHTransferFailed();
    } else {
      IERC20(_token).safeTransfer(_receiver, _amount);
    }

    emit WithdrawFunds(_token, _amount, _receiver);
  }

  /// @inheritdoc IAutomationVault
  function approveRelayCallers(address _relay, address[] calldata _callers) external onlyOwner {
    EnumerableSet.AddressSet storage _enabledCallers = _relayEnabledCallers[_relay];
    if (_relays.add(_relay)) {
      emit ApproveRelay(_relay);
    }

    for (uint256 _i; _i < _callers.length;) {
      if (_enabledCallers.add(_callers[_i])) {
        emit ApproveRelayCaller(_relay, _callers[_i]);
      }

      unchecked {
        ++_i;
      }
    }
  }

  /// @inheritdoc IAutomationVault
  function revokeRelayCallers(address _relay, address[] calldata _callers) external onlyOwner {
    EnumerableSet.AddressSet storage _enabledCallers = _relayEnabledCallers[_relay];

    for (uint256 _i; _i < _callers.length;) {
      if (_enabledCallers.remove(_callers[_i])) {
        emit RevokeRelayCaller(_relay, _callers[_i]);
      }

      unchecked {
        ++_i;
      }
    }

    if (_enabledCallers.length() == 0) {
      _relays.remove(_relay);
      emit RevokeRelay(_relay);
    }
  }

  /// @inheritdoc IAutomationVault
  function approveJobFunctions(address _job, bytes4[] calldata _functionSelectors) external onlyOwner {
    EnumerableSet.Bytes32Set storage _enabledSelectors = _jobEnabledFunctions[_job];
    if (_jobs.add(_job)) {
      emit ApproveJob(_job);
    }

    for (uint256 _i; _i < _functionSelectors.length;) {
      if (_enabledSelectors.add(_functionSelectors[_i])) {
        emit ApproveJobFunction(_job, _functionSelectors[_i]);
      }

      unchecked {
        ++_i;
      }
    }
  }

  /// @inheritdoc IAutomationVault
  function revokeJobFunctions(address _job, bytes4[] calldata _functionSelectors) external onlyOwner {
    EnumerableSet.Bytes32Set storage _enabledSelectors = _jobEnabledFunctions[_job];

    for (uint256 _i; _i < _functionSelectors.length;) {
      if (_enabledSelectors.remove(_functionSelectors[_i])) {
        emit RevokeJobFunction(_job, _functionSelectors[_i]);
      }

      unchecked {
        ++_i;
      }
    }

    if (_enabledSelectors.length() == 0) {
      _jobs.remove(_job);
      emit RevokeJob(_job);
    }
  }

  /// @inheritdoc IAutomationVault
  function exec(address _relayCaller, ExecData[] calldata _execData, FeeData[] calldata _feeData) external payable {
    if (!_relayEnabledCallers[msg.sender].contains(_relayCaller) && !_relayEnabledCallers[msg.sender].contains(_NULL)) {
      revert AutomationVault_NotApprovedRelayCaller();
    }

    ExecData memory _execDatum;
    uint256 _dataLength = _execData.length;
    uint256 _i;
    bool _success;

    for (_i; _i < _dataLength;) {
      _execDatum = _execData[_i];

      if (!_jobEnabledFunctions[_execDatum.job].contains(bytes4(_execDatum.jobData))) {
        revert AutomationVault_NotApprovedJobFunction();
      }
      (_success,) = _execDatum.job.call(_execDatum.jobData);
      if (!_success) revert AutomationVault_ExecFailed();

      emit JobExecuted(msg.sender, _relayCaller, _execDatum.job, _execDatum.jobData);

      unchecked {
        ++_i;
      }
    }

    FeeData memory _feeDatum;
    _dataLength = _feeData.length;
    _i = 0;

    for (_i; _i < _dataLength;) {
      _feeDatum = _feeData[_i];

      if (_feeDatum.feeToken == _ETH) {
        (_success,) = _feeDatum.feeRecipient.call{value: _feeDatum.fee}('');
        if (!_success) revert AutomationVault_ETHTransferFailed();
      } else {
        IERC20(_feeDatum.feeToken).safeTransfer(_feeDatum.feeRecipient, _feeDatum.fee);
      }

      emit IssuePayment(msg.sender, _relayCaller, _feeDatum.feeRecipient, _feeDatum.feeToken, _feeDatum.fee);

      unchecked {
        ++_i;
      }
    }
  }

  modifier onlyOwner() {
    address _owner = owner;
    if (msg.sender != _owner) revert AutomationVault_OnlyOwner(_owner);
    _;
  }

  modifier onlyPendingOwner() {
    address _pendingOwner = pendingOwner;
    if (msg.sender != _pendingOwner) revert AutomationVault_OnlyPendingOwner(_pendingOwner);
    _;
  }

  receive() external payable {}
}