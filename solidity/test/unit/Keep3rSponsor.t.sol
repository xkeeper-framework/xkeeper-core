// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {Test} from 'forge-std/Test.sol';

import {
  Keep3rSponsor,
  IKeep3rSponsor,
  IOpenRelay,
  IAutomationVault,
  IKeep3rV2,
  IKeep3rHelper,
  EnumerableSet
} from '../../contracts/periphery/Keep3rSponsor.sol';
import {IOwnable} from '../../contracts/utils/Ownable.sol';

contract Keep3rSponsorForTest is Keep3rSponsor {
  using EnumerableSet for EnumerableSet.AddressSet;

  constructor(
    address _owner,
    address _feeRecipient,
    IOpenRelay _openRelay,
    IKeep3rV2 _keep3rV2,
    IKeep3rHelper _keep3rHelper
  ) Keep3rSponsor(_owner, _feeRecipient, _openRelay, _keep3rV2, _keep3rHelper) {}

  function addSponsorJobsForTest(address[] memory _jobs) external {
    for (uint256 _i; _i < _jobs.length;) {
      _sponsoredJobs.add(_jobs[_i]);

      unchecked {
        ++_i;
      }
    }
  }

  function setPendingOwnerForTest(address _pendingOwner) public {
    pendingOwner = _pendingOwner;
  }
}

/**
 * @title Keep3rSponsor Unit tests
 */
contract Keep3rSponsorUnitTest is Test {
  // Events
  event JobExecuted(address _job);
  event FeeRecipientSetted(address indexed _feeRecipient);
  event OpenRelaySetted(IOpenRelay indexed _openRelay);
  event ApproveSponsoredJob(address indexed _job);
  event DeleteSponsoredJob(address indexed _job);
  event BonusSetted(uint256 indexed _bonus);

  // Keep3rSponsor contract
  Keep3rSponsorForTest public keep3rSponsor;

  // External contracts
  IOpenRelay public openRelay;
  IKeep3rV2 public keep3rV2;
  IKeep3rHelper public keep3rHelper;

  /// EOAs
  address public owner;
  address public pendingOwner;
  address public feeRecipient;

  function setUp() public virtual {
    owner = makeAddr('Owner');
    pendingOwner = makeAddr('PendingOwner');
    feeRecipient = makeAddr('FeeRecipient');

    openRelay = IOpenRelay(makeAddr('OpenRelay'));
    keep3rV2 = IKeep3rV2(makeAddr('Keep3rV2'));
    keep3rHelper = IKeep3rHelper(makeAddr('Keep3rHelper'));

    keep3rSponsor = new Keep3rSponsorForTest(owner, feeRecipient, openRelay, keep3rV2, keep3rHelper);
  }

  /**
   * @notice Helper function to change the prank and expect revert if the caller is not the owner
   */
  function _revertOnlyOwner() internal {
    vm.expectRevert(abi.encodeWithSelector(IOwnable.Ownable_OnlyOwner.selector));
    changePrank(pendingOwner);
  }
}

contract UnitKeep3rSponsorConstructor is Keep3rSponsorUnitTest {
  function testParamsAreSet() public {
    assertEq(keep3rSponsor.owner(), owner);
    assertEq(keep3rSponsor.feeRecipient(), feeRecipient);
    assertEq(address(keep3rSponsor.openRelay()), address(openRelay));
    assertEq(address(keep3rSponsor.KEEP3R_V2()), address(keep3rV2));
    assertEq(address(keep3rSponsor.KEEP3R_HELPER()), address(keep3rHelper));
  }
}

contract UnitKeep3rSponsorGetSponsoredJob is Keep3rSponsorUnitTest {
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet internal _cleanJobs;

  modifier happyPath(address[] memory _sponsoredJobs) {
    vm.assume(_sponsoredJobs.length > 0 && _sponsoredJobs.length < 30);
    // Clean the array to avoid duplicates
    for (uint256 _i; _i < _sponsoredJobs.length; ++_i) {
      _cleanJobs.add(_sponsoredJobs[_i]);
    }

    keep3rSponsor.addSponsorJobsForTest(_sponsoredJobs);
    _;
  }

  function testSponsoredJobs(address[] memory _sponsoredJobs) public happyPath(_sponsoredJobs) {
    address[] memory _cleanSponsoredJobs = _cleanJobs.values();
    address[] memory _getSponsoredJobs = keep3rSponsor.getSponsoredJobs();

    assertEq(_cleanSponsoredJobs.length, _getSponsoredJobs.length);

    for (uint256 _i; _i < _cleanSponsoredJobs.length; ++_i) {
      assertEq(_cleanSponsoredJobs[_i], _getSponsoredJobs[_i]);
    }
  }
}

contract UnitKeep3rSponsorSetFeeRecipient is Keep3rSponsorUnitTest {
  function setUp() public override {
    Keep3rSponsorUnitTest.setUp();

    vm.startPrank(owner);
  }

  function testRevertIfCallerIsNotOwner(address _feeRecipient) public {
    _revertOnlyOwner();
    keep3rSponsor.setFeeRecipient(_feeRecipient);
  }

  function testSetFeeRecipient(address _feeRecipient) public {
    keep3rSponsor.setFeeRecipient(_feeRecipient);

    assertEq(keep3rSponsor.feeRecipient(), _feeRecipient);
  }

  function testEmitFeeRecipientSetted(address _feeRecipient) public {
    vm.expectEmit();
    emit FeeRecipientSetted(_feeRecipient);

    keep3rSponsor.setFeeRecipient(_feeRecipient);
  }
}

contract UnitKeep3rSponsorSetOpenRelay is Keep3rSponsorUnitTest {
  function setUp() public override {
    Keep3rSponsorUnitTest.setUp();

    vm.startPrank(owner);
  }

  function testRevertIfCallerIsNotOwner(IOpenRelay _openRelay) public {
    _revertOnlyOwner();
    keep3rSponsor.setOpenRelay(_openRelay);
  }

  function testSetOpenRelay(IOpenRelay _openRelay) public {
    keep3rSponsor.setOpenRelay(_openRelay);

    assertEq(address(keep3rSponsor.openRelay()), address(_openRelay));
  }

  function testEmitOpenRelaySetted(IOpenRelay _openRelay) public {
    vm.expectEmit();
    emit OpenRelaySetted(_openRelay);

    keep3rSponsor.setOpenRelay(_openRelay);
  }
}

contract UnitKeep3rSponsorSetBonus is Keep3rSponsorUnitTest {
  modifier happyPath(uint256 _bonus) {
    vm.assume(_bonus > keep3rSponsor.BASE());
    vm.startPrank(owner);
    _;
  }

  function testRevertIfCallerIsNotOwner(uint256 _bonus) public happyPath(_bonus) {
    _revertOnlyOwner();
    keep3rSponsor.setBonus(_bonus);
  }

  function testRevertIfBonusIsLow(uint256 _bonus) public {
    vm.assume(_bonus < keep3rSponsor.BASE());
    vm.startPrank(owner);
    vm.expectRevert(abi.encodeWithSelector(IKeep3rSponsor.Keep3rSponsor_LowBonus.selector));

    keep3rSponsor.setBonus(_bonus);
  }

  function testSetBonus(uint256 _bonus) public happyPath(_bonus) {
    keep3rSponsor.setBonus(_bonus);

    assertEq(keep3rSponsor.bonus(), _bonus);
  }

  function testEmitBonusSetted(uint256 _bonus) public happyPath(_bonus) {
    vm.expectEmit();
    emit BonusSetted(_bonus);

    keep3rSponsor.setBonus(_bonus);
  }
}

contract UnitKeep3rSponsorAddSponsoredJobs is Keep3rSponsorUnitTest {
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet internal _cleanJobs;

  modifier happyPath(address[] memory _jobs) {
    vm.assume(_jobs.length > 0 && _jobs.length < 30);

    // Clean the array to avoid duplicates
    for (uint256 _i; _i < _jobs.length; ++_i) {
      _cleanJobs.add(_jobs[_i]);
    }
    _;
  }

  function setUp() public override {
    Keep3rSponsorUnitTest.setUp();

    vm.startPrank(owner);
  }

  function testRevertIfCallerIsNotOwner(address[] memory _jobs) public {
    _revertOnlyOwner();
    keep3rSponsor.addSponsoredJobs(_jobs);
  }

  function testAddSponsoredJobs(address[] memory _jobs) public happyPath(_jobs) {
    keep3rSponsor.addSponsoredJobs(_jobs);

    address[] memory _sponsoredJobs = keep3rSponsor.getSponsoredJobs();

    for (uint256 _i; _i < _sponsoredJobs.length; ++_i) {
      assert(_cleanJobs.contains(_sponsoredJobs[_i]));
    }
  }

  function testEmitApproveSponsoredJobs(address[] memory _jobs) public happyPath(_jobs) {
    address[] memory _cleanSponsoredJobs = _cleanJobs.values();

    for (uint256 _i; _i < _cleanSponsoredJobs.length; ++_i) {
      vm.expectEmit();
      emit ApproveSponsoredJob(_cleanSponsoredJobs[_i]);
    }

    keep3rSponsor.addSponsoredJobs(_jobs);
  }
}

contract UnitKeep3rSponsorDeleteSponsoredJobs is Keep3rSponsorUnitTest {
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet internal _cleanJobs;

  modifier happyPath(address[] memory _jobs) {
    vm.assume(_jobs.length > 0 && _jobs.length < 30);

    // Clean the array to avoid duplicates
    for (uint256 _i; _i < _jobs.length; ++_i) {
      _cleanJobs.add(_jobs[_i]);
    }

    keep3rSponsor.addSponsorJobsForTest(_jobs);
    _;
  }

  function setUp() public override {
    Keep3rSponsorUnitTest.setUp();

    vm.startPrank(owner);
  }

  function testRevertIfCallerIsNotOwner(address[] memory _jobs) public {
    _revertOnlyOwner();
    keep3rSponsor.deleteSponsoredJobs(_jobs);
  }

  function testDeleteSponsoredJobs(address[] memory _jobs) public happyPath(_jobs) {
    keep3rSponsor.deleteSponsoredJobs(_jobs);

    address[] memory _sponsoredJobs = keep3rSponsor.getSponsoredJobs();

    assertEq(_sponsoredJobs.length, 0);
  }

  function testEmitDeleteSponsoredJobs(address[] memory _jobs) public happyPath(_jobs) {
    address[] memory _cleanSponsoredJobs = _cleanJobs.values();

    for (uint256 _i; _i < _cleanSponsoredJobs.length; ++_i) {
      vm.expectEmit();
      emit DeleteSponsoredJob(_cleanSponsoredJobs[_i]);
    }

    keep3rSponsor.deleteSponsoredJobs(_jobs);
  }
}

contract UnitKeep3rSponsorExec is Keep3rSponsorUnitTest {
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet internal _cleanJobs;

  modifier happyPath(IAutomationVault _automationVault, IAutomationVault.ExecData[] memory _execData) {
    vm.assume(_execData.length > 0 && _execData.length < 5);
    vm.assume(_automationVault != IAutomationVault(address(0)));

    assumeNotPrecompile(address(_automationVault));
    assumeNotForgeAddress(address(_automationVault));

    // Clean the array to avoid duplicates
    for (uint256 _i; _i < _execData.length; ++_i) {
      _cleanJobs.add(_execData[_i].job);
      assumeNotPrecompile(_execData[_i].job);
      assumeNotForgeAddress(_execData[_i].job);
    }

    keep3rSponsor.addSponsorJobsForTest(_cleanJobs.values());

    vm.mockCall(address(keep3rV2), abi.encodeWithSelector(IKeep3rV2.isKeeper.selector, address(this)), abi.encode(true));

    vm.mockCall(
      address(openRelay),
      abi.encodeWithSelector(IOpenRelay.exec.selector, _automationVault, _execData, feeRecipient),
      abi.encode(true)
    );

    _;
  }

  function testRevertIfNoJobs(
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData
  ) public happyPath(_automationVault, _execData) {
    vm.expectRevert(abi.encodeWithSelector(IKeep3rSponsor.Keep3rSponsor_NoJobs.selector));

    keep3rSponsor.exec(_automationVault, new IAutomationVault.ExecData[](0));
  }

  function testRevertIfJobIsNotSponsored(
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData
  ) public {
    vm.assume(_execData.length > 0 && _execData.length < 5);
    vm.expectRevert(abi.encodeWithSelector(IKeep3rSponsor.Keep3rSponsor_JobNotSponsored.selector));
    vm.mockCall(address(keep3rV2), abi.encodeWithSelector(IKeep3rV2.isKeeper.selector, address(this)), abi.encode(true));

    _execData[0].job = makeAddr('JobNotSponsored');

    keep3rSponsor.exec(_automationVault, _execData);
  }

  function testRevertIfIsNotKeep3r(
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData
  ) public happyPath(_automationVault, _execData) {
    vm.expectRevert(abi.encodeWithSelector(IKeep3rSponsor.Keep3rSponsor_NotKeeper.selector));

    vm.mockCall(
      address(keep3rV2), abi.encodeWithSelector(IKeep3rV2.isKeeper.selector, address(this)), abi.encode(false)
    );

    keep3rSponsor.exec(_automationVault, _execData);
  }

  function testExecOpenRelay(
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    uint128 _reward
  ) public happyPath(_automationVault, _execData) {
    vm.assume(_reward > 0);
    vm.expectCall(
      address(openRelay), abi.encodeWithSelector(IOpenRelay.exec.selector, _automationVault, _execData, feeRecipient)
    );

    vm.mockCall(
      address(keep3rHelper), abi.encodeWithSelector(IKeep3rHelper.getRewardAmountFor.selector), abi.encode(_reward)
    );

    vm.mockCall(
      address(keep3rV2),
      abi.encodeWithSelector(IKeep3rV2.bondedPayment.selector, address(this), _reward),
      abi.encode(true)
    );

    keep3rSponsor.exec(_automationVault, _execData);
  }

  function testExecRewardAmount(
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    uint128 _reward
  ) public happyPath(_automationVault, _execData) {
    vm.assume(_reward > 0);

    vm.mockCall(
      address(keep3rHelper), abi.encodeWithSelector(IKeep3rHelper.getRewardAmountFor.selector), abi.encode(_reward)
    );

    uint256 _rewardWithBonus = (_reward * keep3rSponsor.bonus()) / keep3rSponsor.BASE();

    vm.mockCall(
      address(keep3rV2),
      abi.encodeWithSelector(IKeep3rV2.bondedPayment.selector, address(this), _rewardWithBonus),
      abi.encode(true)
    );

    vm.expectCall(
      address(keep3rV2), abi.encodeWithSelector(IKeep3rV2.bondedPayment.selector, address(this), _rewardWithBonus)
    );

    keep3rSponsor.exec(_automationVault, _execData);
  }
}
