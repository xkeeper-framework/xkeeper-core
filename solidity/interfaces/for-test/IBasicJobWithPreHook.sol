// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IBasicJobWithPreHook {
  /*///////////////////////////////////////////////////////////////
                        ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Error emitted when the caller is invalid
   */
  error BasicJobWithPreHook_InvalidCaller();

  /**
   * @notice Error emitted when the relay is invalid
   */
  error BasicJobWithPreHook_InvalidRelay();
  /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice This function sets the valid caller for the job
   * @param _caller The caller
   */
  function setCaller(address _caller) external;

  /**
   * @notice This function sets the valid relay for the job
   * @param _relay The relay
   */
  function setRelay(address _relay) external;

  /**
   * @notice This function checks whether the job can be executed by the automation vault
   * @param _relayCaller The caller of the relay
   * @param _relay The relay that will execute the job
   * @param _dataToExecute The data that will be executed
   * @return _returnedData The returned data that will be executed
   */
  function preHook(
    address _relayCaller,
    address _relay,
    bytes memory _dataToExecute
  ) external view returns (bytes memory _returnedData);
}
