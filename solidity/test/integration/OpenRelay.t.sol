// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {CommonIntegrationTest} from '../integration/Common.t.sol';

import {IAutomationVault} from '../../interfaces/core/IAutomationVault.sol';
import {BasicJob} from '../../contracts/for-test/BasicJob.sol';
import {BasicJobWithPreHook} from '../../contracts/for-test/BasicJobWithPreHook.sol';

contract IntegrationOpenRelay is CommonIntegrationTest {
  function setUp() public override {
    // AutomationVault setup
    CommonIntegrationTest.setUp();

    // Bot callers array
    address[] memory _bots = new address[](1);
    _bots[0] = bot;

    // Job selectors with hooks data array
    IAutomationVault.SelectorData[] memory _jobSelectorsDataHooks = new IAutomationVault.SelectorData[](2);
    _jobSelectorsDataHooks[0] = IAutomationVault.SelectorData(
      BasicJobWithPreHook.work.selector,
      IAutomationVault.HookData({
        selectorType: IAutomationVault.JobSelectorType.ENABLED_WITH_PREHOOK,
        preHook: address(basicJobWithPreHook),
        postHook: address(0)
      })
    );

    _jobSelectorsDataHooks[1] = IAutomationVault.SelectorData(
      BasicJobWithPreHook.workHard.selector,
      IAutomationVault.HookData({
        selectorType: IAutomationVault.JobSelectorType.ENABLED_WITH_PREHOOK,
        preHook: address(basicJobWithPreHook),
        postHook: address(0)
      })
    );

    // Job selectors data array
    IAutomationVault.SelectorData[] memory _jobSelectorsData = new IAutomationVault.SelectorData[](2);
    _jobSelectorsData[0] = IAutomationVault.SelectorData(
      BasicJob.work.selector,
      IAutomationVault.HookData({
        selectorType: IAutomationVault.JobSelectorType.ENABLED,
        preHook: address(0),
        postHook: address(0)
      })
    );

    _jobSelectorsData[1] = IAutomationVault.SelectorData(
      BasicJob.workHard.selector,
      IAutomationVault.HookData({
        selectorType: IAutomationVault.JobSelectorType.ENABLED,
        preHook: address(0),
        postHook: address(0)
      })
    );

    // Job data array
    IAutomationVault.JobData[] memory _jobsData = new IAutomationVault.JobData[](2);
    _jobsData[0] = IAutomationVault.JobData(address(basicJobWithPreHook), _jobSelectorsDataHooks);
    _jobsData[1] = IAutomationVault.JobData(address(basicJob), _jobSelectorsData);

    // Set prehook requirements
    basicJobWithPreHook.setCaller(bot);
    basicJobWithPreHook.setRelay(address(openRelay));

    startHoax(owner);

    // AutomationVault approve relay data
    automationVault.addRelay(address(openRelay), _bots, _jobsData);
    address(automationVault).call{value: 100 ether}('');

    changePrank(bot);
  }

  function test_executeJobOpenRelay() public {
    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] = IAutomationVault.ExecData(address(basicJob), abi.encodeWithSelector(basicJob.work.selector));

    vm.expectEmit(address(basicJob));
    emit Worked();

    openRelay.exec(automationVault, _execData, bot);
  }

  function test_executeAndGetPayment(uint16 _howHard) public {
    vm.assume(_howHard <= 500);

    assertEq(bot.balance, 0);

    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] =
      IAutomationVault.ExecData(address(basicJob), abi.encodeWithSelector(BasicJob.workHard.selector, _howHard));

    // Calculate the exec gas cost
    uint256 _gasBeforeExec = gasleft();
    openRelay.exec(automationVault, _execData, bot);
    uint256 _gasAfterExec = gasleft();

    // Calculate tx cost
    uint256 _txCost = (_gasBeforeExec - _gasAfterExec) * block.basefee;

    // Calculate payment
    uint256 _payment = _txCost * openRelay.GAS_MULTIPLIER() / openRelay.BASE();

    assertGt(bot.balance, _payment);
    assertLt(bot.balance, _payment * openRelay.GAS_MULTIPLIER() / openRelay.BASE());
  }

  function test_executeHooksAndGetPayment(uint16 _howHard) public {
    vm.assume(_howHard <= 500);

    assertEq(bot.balance, 0);

    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] = IAutomationVault.ExecData(
      address(basicJobWithPreHook), abi.encodeWithSelector(BasicJobWithPreHook.workHard.selector, _howHard)
    );

    vm.expectCall(
      address(basicJobWithPreHook),
      abi.encodeWithSelector(
        basicJobWithPreHook.preHook.selector,
        bot,
        address(openRelay),
        abi.encodeWithSelector(BasicJobWithPreHook.workHard.selector, _howHard)
      )
    );

    // Calculate the exec gas cost
    uint256 _gasBeforeExec = gasleft();
    openRelay.exec(automationVault, _execData, bot);
    uint256 _gasAfterExec = gasleft();

    // Calculate tx cost
    uint256 _txCost = (_gasBeforeExec - _gasAfterExec) * block.basefee;

    // Calculate payment
    uint256 _payment = _txCost * openRelay.GAS_MULTIPLIER() / openRelay.BASE();

    assertGt(bot.balance, _payment);
    assertLt(bot.balance, _payment * openRelay.GAS_MULTIPLIER() / openRelay.BASE());
  }
}
