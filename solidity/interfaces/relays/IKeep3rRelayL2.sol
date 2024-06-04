// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {IAutomationVault} from '../../interfaces/core/IAutomationVault.sol';
import {IKeep3rRelay} from './IKeep3rRelay.sol';

interface IKeep3rRelayL2 is IKeep3rRelay {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the USD per gas unit is setted
   * @param  _automationVault The address of the automation vault
   * @param  _usdPerGasUnit The USD per gas unit
   */
  event UsdPerGasUnitSetted(IAutomationVault _automationVault, uint256 _usdPerGasUnit);

  /*///////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Get the USD per gas unit per automation vault
   * @param  _automationVault The address of the automation vault
   * @return _usdPerGasUnit The USD per gas unit
   */
  function usdPerGasUnitPerVault(IAutomationVault _automationVault) external view returns (uint256 _usdPerGasUnit);

  /*///////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Set the USD per gas unit
   * @param  _automationVault The address of the automation vault
   * @param  _usdPerGasUnit The USD per gas unit
   */
  function setUsdPerGasUnit(IAutomationVault _automationVault, uint256 _usdPerGasUnit) external;
}
