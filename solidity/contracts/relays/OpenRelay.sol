// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {IOpenRelay} from '../../interfaces/relays/IOpenRelay.sol';
import {IAutomationVault} from '../../interfaces/core/IAutomationVault.sol';
import {OwnableAutomationVault} from '../utils/OwnableAutomationVault.sol';
import {_NATIVE_TOKEN} from '../../utils/Constants.sol';

/**
 * @title  OpenRelay
 * @notice This contract will manage all executions coming from any bot
 */
contract OpenRelay is IOpenRelay, OwnableAutomationVault {
  /// @inheritdoc IOpenRelay
  uint256 public constant GAS_BONUS = 53_000;
  /// @inheritdoc IOpenRelay
  uint256 public constant GAS_MULTIPLIER = 12_000;
  /// @inheritdoc IOpenRelay
  uint32 public constant BASE = 10_000;

  mapping(IAutomationVault _automationVault => mapping(address _job => PaymentData _paymentData)) public paymentsData;

  function setExtraPayment(
    IAutomationVault _automationVault,
    address _job,
    PaymentData memory _paymentData
  ) external onlyAutomationVaultOwner(_automationVault) {
    paymentsData[_automationVault][_job] = _paymentData;

    emit ExtraPaymentSetted(_automationVault, _job, _paymentData);
  }

  /// @inheritdoc IOpenRelay
  function exec(
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] calldata _execData,
    address _feeRecipient
  ) external {
    if (_execData.length == 0) revert OpenRelay_NoExecData();
    IAutomationVault.ExecData[] memory _newExecData = new IAutomationVault.ExecData[](1);
    IAutomationVault.FeeData[] memory _feeData = new IAutomationVault.FeeData[](_execData.length);
    PaymentData memory _paymentData;

    uint256 _initialGas;
    uint256 _gasSpent;
    uint256 _payment;

    for (uint256 _i; _i < _execData.length;) {
      _paymentData = paymentsData[_automationVault][_execData[_i].job];
      _newExecData[0] = _execData[_i];

      // Execute the automation vault counting the gas spent
      _initialGas = gasleft();
      _automationVault.exec(msg.sender, _newExecData, new IAutomationVault.FeeData[](0));
      _gasSpent = _initialGas - gasleft();

      if (address(_paymentData.token) == _NATIVE_TOKEN) {
        _payment = (_gasSpent + GAS_BONUS) * block.basefee * _paymentData.amountOrPercentage / BASE;
        _feeData[_i] = IAutomationVault.FeeData(_feeRecipient, _NATIVE_TOKEN, _payment);
      } else if (address(_paymentData.token) == address(0)) {
        _payment = (_gasSpent + GAS_BONUS) * block.basefee * GAS_MULTIPLIER / BASE;
        _feeData[_i] = IAutomationVault.FeeData(_feeRecipient, _NATIVE_TOKEN, _payment);
      } else {
        _feeData[_i] =
          IAutomationVault.FeeData(_feeRecipient, address(_paymentData.token), _paymentData.amountOrPercentage);
      }

      unchecked {
        ++_i;
      }
    }

    _automationVault.exec(msg.sender, new IAutomationVault.ExecData[](0), _feeData);

    // Emit the event
    emit AutomationVaultExecuted(_automationVault, msg.sender, _execData, _feeData);
  }
}
