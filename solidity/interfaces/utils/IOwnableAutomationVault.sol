// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

interface IOwnableAutomationVault {
  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Error when the caller is not the automation vault owner
   */
  error OwnableAutomationVault_OnlyAutomationVaultOwner();
}
