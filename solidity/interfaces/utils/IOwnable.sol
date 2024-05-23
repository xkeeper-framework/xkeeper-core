// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

/**
 * @title  IOwnable
 * @notice This contract is used to manage ownership
 */

interface IOwnable {
  /*///////////////////////////////////////////////////////////////
                              EVENTS  
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the owner is proposed to change
   * @param  _pendingOwner The address that is being proposed
   */
  event ChangeOwner(address indexed _pendingOwner);

  /**
   * @notice Emitted when the owner is accepted
   * @param  _owner The address of the new owner
   */
  event AcceptOwner(address indexed _owner);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the caller is not the owner
   */
  error Ownable_OnlyOwner();

  /**
   * @notice Thrown when the caller is not the pending owner
   */
  error Ownable_OnlyPendingOwner();

  /*///////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS  
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the owner address
   * @return _owner The address of the owner
   */
  function owner() external view returns (address _owner);

  /**
   * @notice Returns the pending owner address
   * @return _pendingOwner The address of the pending owner
   */
  function pendingOwner() external view returns (address _pendingOwner);

  /*///////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS 
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Propose a new owner for the contract
   * @dev    The new owner will need to accept the ownership before it is transferred
   * @param  _pendingOwner The address of the new owner
   */
  function changeOwner(address _pendingOwner) external;

  /**
   * @notice Accepts the ownership of the contract
   */
  function acceptOwner() external;
}
