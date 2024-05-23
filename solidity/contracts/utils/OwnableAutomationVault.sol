// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {IAutomationVault} from '../../interfaces/core/IAutomationVault.sol';
import {IOwnableAutomationVault} from '../../interfaces/utils/IOwnableAutomationVault.sol';

/**
 * @title  OwnableAutomationVault
 * @notice This contract is used to secure function calls to only the automation vault owner
 */
contract OwnableAutomationVault is IOwnableAutomationVault {
  modifier onlyAutomationVaultOwner(IAutomationVault _automationVault) {
    if (_automationVault.owner() != msg.sender) {
      revert OwnableAutomationVault_OnlyAutomationVaultOwner();
    }
    _;
  }
}
