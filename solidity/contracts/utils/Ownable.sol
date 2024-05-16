// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {IOwnable} from '../../interfaces/utils/IOwnable.sol';

/**
 * @title  Ownable
 * @notice This contract is used to manage ownership
 */
contract Ownable is IOwnable {
  /// @inheritdoc IOwnable
  address public owner;
  /// @inheritdoc IOwnable
  address public pendingOwner;

  /**
   * @param _owner The address of the owner
   */
  constructor(address _owner) {
    owner = _owner;
  }

  /// @inheritdoc IOwnable
  function changeOwner(address _pendingOwner) external onlyOwner {
    pendingOwner = _pendingOwner;
    emit ChangeOwner(_pendingOwner);
  }

  /// @inheritdoc IOwnable
  function acceptOwner() external onlyPendingOwner {
    pendingOwner = address(0);
    owner = msg.sender;
    emit AcceptOwner(msg.sender);
  }

  /**
   * @notice Checks that the caller is the owner
   */
  modifier onlyOwner() {
    address _owner = owner;
    if (msg.sender != _owner) revert Ownable_OnlyOwner();
    _;
  }

  /**
   * @notice Checks that the caller is the pending owner
   */
  modifier onlyPendingOwner() {
    address _pendingOwner = pendingOwner;
    if (msg.sender != _pendingOwner) revert Ownable_OnlyPendingOwner();
    _;
  }
}
