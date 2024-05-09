// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

/**
 * @title  Hook
 * @notice This contract is used for managing the hooks calls
 * @dev If you want to use the hooks, you need to implement this interface
 */

interface IHook {
  /*///////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Executes the pre-hook
   * @param  _relayCaller The caller of the relay
   * @param  _relay The relay address
   * @param  _dataToExecute The data to execute
   * @return _returnedData The data returned by the pre-hook
   */
  function preHook(
    address _relayCaller,
    address _relay,
    bytes memory _dataToExecute
  ) external returns (bytes memory _returnedData);

  /**
   * @notice Executes the post-hook
   * @param  _relayCaller The caller of the relay
   * @param  _relay The relay address
   * @param  _dataToExecute The data to execute
   */
  function postHook(address _relayCaller, address _relay, bytes memory _dataToExecute) external;
}
