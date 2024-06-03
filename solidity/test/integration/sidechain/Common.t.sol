// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from 'forge-std/Test.sol';

import {BasicJob} from '../../../contracts/for-test/BasicJob.sol';
import {Deploy} from '../../../script/Deploy.s.sol';
import {IAutomate} from '../../../interfaces/external/IAutomate.sol';
import {IKeep3rV2} from '../../../interfaces/external/IKeep3rV2.sol';

import {_KEEP3R_V2_OP, _AUTOMATE_OP} from '../Constants.sol';

contract DeployForTest is Deploy {
  uint256 private constant _FORK_BLOCK = 120_397_000;

  function setUp() public virtual {
    // OP fork
    vm.createSelectFork(vm.envString('OPTIMISM_MAINNET_RPC'), _FORK_BLOCK);

    // Deployer setup
    _deployerPk = vm.deriveKey('test test test test test test test test test test test junk', 0);

    // AutomationVault setup
    owner = makeAddr('Owner');
  }
}

abstract contract CommonIntegrationTest is DeployForTest, Test {
  // Events
  event Worked();

  // ForTest contracts
  BasicJob public basicJob;

  // EOAs
  address public bot;

  function setUp() public virtual override {
    DeployForTest.setUp();

    gelatoAutomate = IAutomate(_AUTOMATE_OP);
    keep3rV2 = IKeep3rV2(_KEEP3R_V2_OP);
    isMainnet = false;

    bot = makeAddr('Bot');

    basicJob = new BasicJob();

    run();
  }
}
