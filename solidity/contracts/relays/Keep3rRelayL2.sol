// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {IKeep3rJobWorkableRated} from '../../interfaces/external/IKeep3rJobWorkableRated.sol';

import {IKeep3rRelayL2, IKeep3rRelay, IAutomationVault} from '../../interfaces/relays/IKeep3rRelayL2.sol';
import {IKeep3rV2} from '../../interfaces/external/IKeep3rV2.sol';
import {OwnableAutomationVault} from '../utils/OwnableAutomationVault.sol';

/**
 * @title  Keep3rRelay L2
 * @notice This contract will manage all executions coming from the keep3r network deployed in L2
 */
contract Keep3rRelayL2 is IKeep3rRelayL2, OwnableAutomationVault {
  /// @inheritdoc IKeep3rRelay
  IKeep3rV2 public immutable KEEP3R_V2;

  /// @inheritdoc IKeep3rRelayL2
  mapping(IAutomationVault _automationVault => uint256 _usdPerGasUnit) public usdPerGasUnitPerVault;

  /**
   * @param _keep3rV2 The address of the keep3rV2 contract
   */
  constructor(IKeep3rV2 _keep3rV2) {
    KEEP3R_V2 = _keep3rV2;
  }

  /// @inheritdoc IKeep3rRelayL2
  function setUsdPerGasUnit(
    IAutomationVault _automationVault,
    uint256 _usdPerGasUnit
  ) external onlyAutomationVaultOwner(_automationVault) {
    usdPerGasUnitPerVault[_automationVault] = _usdPerGasUnit;
    emit UsdPerGasUnitSetted(_automationVault, _usdPerGasUnit);
  }

  /// @inheritdoc IKeep3rRelay
  function exec(IAutomationVault _automationVault, IAutomationVault.ExecData[] calldata _execData) external {
    // Ensure that calls are being passed
    uint256 _execDataLength = _execData.length;
    if (_execDataLength == 0) revert Keep3rRelay_NoExecData();

    // The first call to `isKeeper` ensures the caller is a valid keeper
    bool _isKeeper = KEEP3R_V2.isKeeper(msg.sender);
    if (!_isKeeper) revert Keep3rRelay_NotKeeper();

    // Create the array of calls which are going to be executed by the automation vault
    IAutomationVault.ExecData[] memory _execDataKeep3r = new IAutomationVault.ExecData[](_execDataLength + 2);

    // The second call sets the initialGas variable inside Keep3r in the same deepness level than the `worked` call
    // If the second call is not done, the initialGas will have a 63/64 more gas than the `worked`, thus overpaying a lot
    _execDataKeep3r[0] = IAutomationVault.ExecData({
      job: address(KEEP3R_V2),
      jobData: abi.encodeWithSelector(IKeep3rV2.isKeeper.selector, msg.sender)
    });

    // Inject to that array of calls the exec data provided in the arguments
    for (uint256 _i; _i < _execDataLength;) {
      if (_execData[_i].job == address(KEEP3R_V2)) revert Keep3rRelay_Keep3rNotAllowed();
      _execDataKeep3r[_i + 1] = _execData[_i];
      unchecked {
        ++_i;
      }
    }

    // Inject the final call which will issue the payment to the keeper
    _execDataKeep3r[_execDataLength + 1] = IAutomationVault.ExecData({
      job: address(KEEP3R_V2),
      jobData: abi.encodeWithSelector(
        IKeep3rJobWorkableRated.worked.selector, msg.sender, usdPerGasUnitPerVault[_automationVault]
        )
    });

    // Send the array of calls to the automation vault for it to execute them
    _automationVault.exec(msg.sender, _execDataKeep3r, new IAutomationVault.FeeData[](0));

    // Emit the event
    emit AutomationVaultExecuted(_automationVault, msg.sender, _execDataKeep3r);
  }
}
