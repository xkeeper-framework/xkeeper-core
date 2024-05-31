// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {CommonIntegrationTest} from '../integration/Common.t.sol';

import {IERC20} from 'openzeppelin/token/ERC20/utils/SafeERC20.sol';

import {IAutomationVault} from '../../interfaces/core/IAutomationVault.sol';
import {IOpenRelay} from '../../interfaces/relays/IOpenRelay.sol';

import {_NATIVE_TOKEN} from '../../utils/Constants.sol';

contract IntegrationOpenRelay is CommonIntegrationTest {
  IERC20 public dai;

  function setUp() public override {
    // AutomationVault setup
    CommonIntegrationTest.setUp();

    // Deploy DAI token
    dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    // Bot callers array
    address[] memory _bots = new address[](1);
    _bots[0] = bot;

    // Job selectors array
    bytes4[] memory _jobSelectors = new bytes4[](2);
    _jobSelectors[0] = basicJob.work.selector;
    _jobSelectors[1] = basicJob.workHard.selector;

    // Job data array
    IAutomationVault.JobData[] memory _jobsData = new IAutomationVault.JobData[](1);
    _jobsData[0] = IAutomationVault.JobData(address(basicJob), _jobSelectors);

    startHoax(owner);

    // AutomationVault approve relay data
    automationVault.addRelay(address(openRelay), _bots, _jobsData);
    address(automationVault).call{value: 100 ether}('');

    deal(address(dai), address(automationVault), 1000 ether);

    changePrank(bot);
  }

  function test_executeJobOpenRelay() public {
    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] = IAutomationVault.ExecData(address(basicJob), abi.encodeWithSelector(basicJob.work.selector));

    vm.expectEmit(address(basicJob));
    emit Worked();

    openRelay.exec(automationVault, _execData, bot);
  }

  function test_executeGetNormalPayment(uint16 _howHard) public {
    vm.assume(_howHard <= 1000);

    assertEq(bot.balance, 0);

    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] =
      IAutomationVault.ExecData(address(basicJob), abi.encodeWithSelector(basicJob.workHard.selector, _howHard));

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

  function test_executeGetBonusPayment(uint16 _howHard, uint256 _amountOrPercentage) public {
    vm.assume(_howHard <= 1000);
    vm.assume(_amountOrPercentage > 10_000 && _amountOrPercentage <= 100_000);

    assertEq(bot.balance, 0);

    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] =
      IAutomationVault.ExecData(address(basicJob), abi.encodeWithSelector(basicJob.workHard.selector, _howHard));

    changePrank(owner);
    openRelay.setExtraPayment(
      automationVault, address(basicJob), IOpenRelay.PaymentData(IERC20(_NATIVE_TOKEN), _amountOrPercentage)
    );

    changePrank(bot);

    // Calculate the exec gas cost
    uint256 _gasBeforeExec = gasleft();
    openRelay.exec(automationVault, _execData, bot);
    uint256 _gasAfterExec = gasleft();

    // Calculate tx cost
    uint256 _txCost = (_gasBeforeExec - _gasAfterExec) * block.basefee;

    // Calculate payment
    uint256 _payment = _txCost * _amountOrPercentage / openRelay.BASE();

    assertGt(bot.balance, _payment);
    assertLt(bot.balance, _payment * openRelay.GAS_MULTIPLIER() / openRelay.BASE());
  }

  function test_executeGetTokenPayment(uint16 _howHard, uint256 _amountOrPercentage) public {
    vm.assume(_howHard <= 1000);
    vm.assume(_amountOrPercentage > 10 && _amountOrPercentage <= 100);

    assertEq(dai.balanceOf(bot), 0);

    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] =
      IAutomationVault.ExecData(address(basicJob), abi.encodeWithSelector(basicJob.workHard.selector, _howHard));

    changePrank(owner);
    openRelay.setExtraPayment(automationVault, address(basicJob), IOpenRelay.PaymentData(dai, _amountOrPercentage));

    changePrank(bot);

    // Calculate the exec gas cost
    openRelay.exec(automationVault, _execData, bot);

    assertEq(dai.balanceOf(bot), _amountOrPercentage);
  }
}
