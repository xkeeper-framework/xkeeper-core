// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IBasicJobWithPreHook} from '../../interfaces/for-test/IBasicJobWithPreHook.sol';
import {IBasicJob} from '../../interfaces/for-test/IBasicJob.sol';

/**
 * @notice This contract is a basic job that can be automated by any automation vault
 * @dev This contract is for testing purposes only
 */
contract BasicJob is IBasicJobWithPreHook, IBasicJob {
  /**
   * @notice Mapping of the dataset
   * @dev This mapping is for test a job that uses a lot of gas
   */
  mapping(uint256 => address) internal _dataset;

  /**
   * @notice Nonce of the dataset
   */
  uint256 internal _nonce;

  /**
   * @notice Valid caller
   */
  address internal _validCaller;

  /// @inheritdoc IBasicJobWithPreHook
  function setCaller(address _caller) external {
    _validCaller = _caller;
  }

  /// @inheritdoc IBasicJob
  function work() external {
    emit Worked();
  }

  /// @inheritdoc IBasicJob
  function workHard(uint256 _howHard) external {
    for (uint256 _i; _i < _howHard;) {
      _dataset[_nonce] = address(this);

      unchecked {
        ++_i;
        ++_nonce;
      }
    }
  }

  /// @inheritdoc IBasicJobWithPreHook
  function preHook(
    address _relayCaller,
    address _relay,
    bytes memory _dataToExecute
  ) external view returns (bool _success, bytes memory _returnedData) {
    if (_relayCaller != _validCaller) revert BasicJobWithPreHookChecker_InvalidCaller();
    _success = true;
    _returnedData = _dataToExecute;
  }
}
