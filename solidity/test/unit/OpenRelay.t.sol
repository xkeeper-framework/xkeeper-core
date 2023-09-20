// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

// solhint-disable-next-line
import 'forge-std/Test.sol';

import {OpenRelay, IOpenRelay} from '@contracts/OpenRelay.sol';
import {IAutomationVault} from '@interfaces/IAutomationVault.sol';
import {_ETH} from '@contracts/utils/Constants.sol';

/**
 * @title OpenRelay Unit tests
 */
contract OpenRelayUnitTest is Test {
  // Events
  event AutomationVaultExecuted(
    address indexed _automationVault,
    address indexed _relayCaller,
    IAutomationVault.ExecData[] _execData,
    IAutomationVault.FeeData[] _feeData
  );

  // OpenRelay contract
  OpenRelay public openRelay;

  // Mock contracts
  address public relayCaller;

  function setUp() public virtual {
    relayCaller = makeAddr('RelayCaller');

    openRelay = new OpenRelay();
  }
}

contract UnitOpenRelayConstructor is OpenRelayUnitTest {
  function testSetGasBonus() public {
    assertEq(openRelay.GAS_BONUS(), 40_000);
  }

  function testSetGasMultiplier() public {
    assertEq(openRelay.GAS_MULTIPLIER(), 12_000);
  }

  function testSetBase() public {
    assertEq(openRelay.BASE(), 10_000);
  }
}

contract UnitOpenRelayExec is OpenRelayUnitTest {
  modifier happyPath(address _automationVault, IAutomationVault.ExecData[] memory _execData) {
    vm.assume(_execData.length > 0);

    assumeNoPrecompiles(_automationVault);
    vm.assume(_automationVault != address(vm));
    vm.mockCall(_automationVault, abi.encodeWithSelector(IAutomationVault.exec.selector), abi.encode());

    vm.startPrank(relayCaller);
    _;
  }

  function testRevertIfNoExecData(
    address _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    address _feeRecipient
  ) public happyPath(_automationVault, _execData) {
    _execData = new IAutomationVault.ExecData[](0);

    vm.expectRevert(IOpenRelay.OpenRelay_NoExecData.selector);

    openRelay.exec(_automationVault, _execData, _feeRecipient);
  }

  function testCallAutomationVaultExecJobFunction(
    address _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    address _feeRecipient
  ) public happyPath(_automationVault, _execData) {
    vm.expectCall(
      _automationVault,
      abi.encodeCall(IAutomationVault.exec, (relayCaller, _execData, new IAutomationVault.FeeData[](0))),
      1
    );

    openRelay.exec(_automationVault, _execData, _feeRecipient);
  }

  function testCallAutomationVaultExecIssuePayment(
    address _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    address _feeRecipient
  ) public happyPath(_automationVault, _execData) {
    IAutomationVault.FeeData[] memory _feeData = new IAutomationVault.FeeData[](1);
    _feeData[0] = IAutomationVault.FeeData(_feeRecipient, _ETH, 0);

    vm.expectCall(
      _automationVault,
      abi.encodeCall(IAutomationVault.exec, (relayCaller, new IAutomationVault.ExecData[](0), _feeData)),
      1
    );

    openRelay.exec(_automationVault, _execData, _feeRecipient);
  }

  function testEmitAutomationVaultExecuted(
    address _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    address _feeRecipient
  ) public happyPath(_automationVault, _execData) {
    IAutomationVault.FeeData[] memory _feeData = new IAutomationVault.FeeData[](1);
    _feeData[0] = IAutomationVault.FeeData(_feeRecipient, _ETH, 0);

    vm.expectEmit();
    emit AutomationVaultExecuted(_automationVault, relayCaller, _execData, _feeData);

    openRelay.exec(_automationVault, _execData, _feeRecipient);
  }
}