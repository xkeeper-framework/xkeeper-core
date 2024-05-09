// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

interface IStealthVault {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/
  event ChangeOwner(address indexed _pendingOwner);
  event AcceptOwner(address indexed _owner);
  event ChangeManager(address indexed _pendingManager);
  event AcceptManager(address indexed _manager);
  event PenaltySet(uint256 _penalty);
  event Bonded(address indexed _caller, uint256 _amount, uint256 _finalBond);
  event Unbonded(address indexed _caller, uint256 _amount, uint256 _finalBond);
  event WithdrawFunds(address indexed _token, uint256 _amount, address indexed _receiver);
  event ReportedHash(bytes32 _hash, address _reportedBy);
  event PenaltyApplied(bytes32 _hash, address _caller, uint256 _penalty, address _reportedBy);
  event ValidatedHash(bytes32 _hash, address _caller, uint256 _penalty);

  /*///////////////////////////////////////////////////////////////
                          ERRORS
  //////////////////////////////////////////////////////////////*/

  error StealthVault_ZeroPenalty();
  error StealthVault_ZeroAmount();
  error StealthVault_AmountHigh();
  error StealthVault_UnbondCooldown();
  error StealthVault_PaymentFailed();
  error StealthVault_WrongBlock();
  error StealthVault_GasBufferHigh();
  error StealthVault_NotEOA();
  error StealthVault_NotEnoughBonded();
  error StealthVault_Unbonding();
  error StealthVault_HashAlreadyReported();
  error StealthVault_GasLimit();
  error StealthVault_OnlyOwner();
  error StealthVault_OnlyPendingOwner();
  error StealthVault_OnlyManager();
  error StealthVault_OnlyPendingManager();
}

//   /*///////////////////////////////////////////////////////////////
//                           VIEW FUNCTIONS
//   //////////////////////////////////////////////////////////////*/
//   function isStealthVault() external pure returns (bool);

//   function callers() external view returns (address[] memory _callers);

//   function callerContracts(address _caller) external view returns (address[] memory _contracts);

//   // global bond
//   function gasBuffer() external view returns (uint256 _gasBuffer);

//   function totalBonded() external view returns (uint256 _totalBonded);

//   function bonded(address _caller) external view returns (uint256 _bond);

//   function canUnbondAt(address _caller) external view returns (uint256 _canUnbondAt);

//   // global caller
//   function caller(address _caller) external view returns (bool _enabled);

//   function callerStealthContract(address _caller, address _contract) external view returns (bool _enabled);

//   // global hash
//   function hashReportedBy(bytes32 _hash) external view returns (address _reportedBy);

//   // governor
//   function setGasBuffer(uint256 _gasBuffer) external;

//   function transferGovernorBond(address _caller, uint256 _amount) external;

//   function transferBondToGovernor(address _caller, uint256 _amount) external;

//   // caller
//   function bond() external payable;

//   function startUnbond() external;

//   function cancelUnbond() external;

//   function unbondAll() external;

//   function unbond(uint256 _amount) external;

//   function enableStealthContract(address _contract) external;

//   function enableStealthContracts(address[] calldata _contracts) external;

//   function disableStealthContract(address _contract) external;

//   function disableStealthContracts(address[] calldata _contracts) external;

//   // stealth-contract
//   function validateHash(address _caller, bytes32 _hash, uint256 _penalty) external returns (bool);

//   // watcher
//   function reportHash(bytes32 _hash) external;

//   function reportHashAndPay(bytes32 _hash) external payable;
// }
