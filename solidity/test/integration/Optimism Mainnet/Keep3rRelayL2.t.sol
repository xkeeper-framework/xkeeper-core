// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {CommonIntegrationTest} from './Common.t.sol';

import {IKeep3rJobWorkableRated} from '../../../interfaces/external/IKeep3rJobWorkableRated.sol';

import {IAutomationVault} from '../../../interfaces/core/IAutomationVault.sol';
import {IKeep3rV2} from '../../../interfaces/external/IKeep3rV2.sol';
import {IKeep3rHelper} from '../../../interfaces/external/IKeep3rHelper.sol';
import {IKeep3rV1} from '../../../interfaces/external/IKeep3rV1.sol';
import {_KEEP3R_V2_OP, _KEEP3R_HELPER_OP, _KEEP3R_V1_OP, _KEEP3R_GOVERNOR_OP, _KP3R_WHALE} from '../Constants.sol';

contract IntegrationKeep3rRelayL2 is CommonIntegrationTest {
  // Events
  event KeeperValidation(uint256 _gasLeft);
  event KeeperWork(
    address indexed _credit, address indexed _job, address indexed _keeper, uint256 _amount, uint256 _gasLeft
  );

  // Keep3r contracts
  IKeep3rV2 public keep3r;
  IKeep3rHelper public keep3rHelper;
  IKeep3rV1 public kp3r;

  // EOAs
  address public keep3rGovernor;

  function setUp() public override {
    // AutomationVault setup
    CommonIntegrationTest.setUp();

    // Keep3r setup
    keep3rGovernor = _KEEP3R_GOVERNOR_OP;
    keep3r = IKeep3rV2(_KEEP3R_V2_OP);
    keep3rHelper = IKeep3rHelper(_KEEP3R_HELPER_OP);
    kp3r = IKeep3rV1(_KEEP3R_V1_OP);

    _addJobAndLiquidity(address(automationVault), 1000 ether);

    // Keep3r callers array
    address[] memory _keepers = new address[](1);
    _keepers[0] = bot;

    // Keep3r selectors array
    bytes4[] memory _keep3rSelectors = new bytes4[](2);
    _keep3rSelectors[0] = keep3r.isKeeper.selector;
    _keep3rSelectors[1] = IKeep3rJobWorkableRated.worked.selector;

    // Job selectors array
    bytes4[] memory _jobSelectors = new bytes4[](2);
    _jobSelectors[0] = basicJob.work.selector;
    _jobSelectors[1] = basicJob.workHard.selector;

    // Job data array
    IAutomationVault.JobData[] memory _jobsData = new IAutomationVault.JobData[](2);
    _jobsData[0] = IAutomationVault.JobData(address(keep3r), _keep3rSelectors);
    _jobsData[1] = IAutomationVault.JobData(address(basicJob), _jobSelectors);

    vm.startPrank(owner);

    keep3rRelayL2.setUsdPerGasUnit(automationVault, 100_000);

    // AutomationVault approve relay data
    automationVault.addRelay(address(keep3rRelayL2), _keepers, _jobsData);
  }

  function _addJobAndLiquidity(address _job, uint256 _amount) internal {
    keep3r.addJob(_job);

    vm.prank(keep3rGovernor);
    keep3r.forceLiquidityCreditsToJob(_job, _amount);
  }

  function _bondAndActivateKeeper(address _keeper, uint256 _bondAmount) internal {
    changePrank(_KP3R_WHALE);
    kp3r.transfer(_keeper, _bondAmount);

    vm.startPrank(_keeper);
    kp3r.approve(address(keep3r), _bondAmount);
    keep3r.bond(address(kp3r), _bondAmount);

    skip(keep3r.bondTime() + 1);

    keep3r.activate(address(kp3r));
    changePrank(bot);
  }

  function test_executeJobKeep3rL2() public {
    // Bond and activate keep3r
    _bondAndActivateKeeper(bot, 0);

    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] = IAutomationVault.ExecData(address(basicJob), abi.encodeWithSelector(basicJob.work.selector));

    vm.expectEmit(true, true, true, false, address(keep3r));
    emit KeeperValidation(0);
    vm.expectEmit(address(basicJob));
    emit Worked();
    vm.expectEmit(true, true, true, false, address(keep3r));
    emit KeeperWork(address(kp3r), address(automationVault), bot, 0, 0);

    keep3rRelayL2.exec(automationVault, _execData);
  }

  function test_executeAndGetPaymentFromKeep3rL2(uint64 _fee, uint8 _howHard) public {
    vm.assume(_howHard > 20);
    vm.assume(_fee > 30 gwei && _fee < 200 gwei);
    vm.fee(_fee);

    // Bond and activate keep3r
    _bondAndActivateKeeper(bot, 0);

    // Check that the keeper has no bonded KP3R
    uint256 _payment = keep3r.bonds(bot, address(kp3r));
    assertEq(_payment, 0);

    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] =
      IAutomationVault.ExecData(address(basicJob), abi.encodeWithSelector(basicJob.workHard.selector, _howHard));

    // Initializes storage variables
    keep3rRelayL2.exec(automationVault, _execData);
    uint256 _paymentBefore = keep3r.bonds(bot, address(kp3r));

    // Execure the job
    keep3rRelayL2.exec(automationVault, _execData);

    // Check that the keeper has bonded KP3R
    uint256 _paymentAfter = keep3r.bonds(bot, address(kp3r));

    assertGt(_paymentAfter, _paymentBefore);
  }
}
