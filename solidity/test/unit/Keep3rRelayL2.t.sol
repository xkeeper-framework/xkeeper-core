// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {Test} from 'forge-std/Test.sol';

import {Keep3rRelayL2, IKeep3rRelay, IAutomationVault} from '../../contracts/relays/Keep3rRelayL2.sol';
import {IKeep3rV2} from '../../interfaces/external/IKeep3rV2.sol';
import {IKeep3rJobWorkableRated} from '../../interfaces/external/IKeep3rJobWorkableRated.sol';

import {IOwnableAutomationVault} from '../../interfaces/utils/IOwnableAutomationVault.sol';
import {IOwnable} from '../../interfaces/utils/IOwnable.sol';

contract Keep3rRelayL2ForTest is Keep3rRelayL2 {
  constructor(IKeep3rV2 _keep3rV2) Keep3rRelayL2(_keep3rV2) {}

  function setUsdPerGasUnitForTest(IAutomationVault _automationVault, uint256 _usdPerGasUnit) public {
    usdPerGasUnitPerVault[_automationVault] = _usdPerGasUnit;
  }
}

/**
 * @title Keep3rRelayL2 Unit tests
 */
contract Keep3rRelayL2UnitTest is Test {
  // Events
  event AutomationVaultExecuted(
    IAutomationVault indexed _automationVault, address indexed _relayCaller, IAutomationVault.ExecData[] _execData
  );
  event UsdPerGasUnitSetted(IAutomationVault _automationVault, uint256 _usdPerGasUnit);

  // Keep3rRelay contract
  Keep3rRelayL2ForTest public keep3rRelayL2;

  // Keep3r V2 contract
  IKeep3rV2 public keep3rV2;

  // Owner
  address public owner;

  function setUp() public virtual {
    keep3rV2 = IKeep3rV2(makeAddr('KEEP3R_V2'));
    keep3rRelayL2 = new Keep3rRelayL2ForTest(keep3rV2);

    owner = makeAddr('Owner');
  }
}

contract UnitKeep3rRelayL2SetUsdPerUnit is Keep3rRelayL2UnitTest {
  modifier happyPath(IAutomationVault _automationVault, uint256 _usdPerGasUnit) {
    vm.assume(_usdPerGasUnit > 0);
    vm.startPrank(owner);

    vm.mockCall(address(_automationVault), abi.encodeWithSelector(IOwnable.owner.selector), abi.encode(owner));
    _;
  }

  function testRevertIfNotVaultOwner(
    IAutomationVault _automationVault,
    uint256 _usdPerGasUnit,
    address _notOwner
  ) public happyPath(_automationVault, _usdPerGasUnit) {
    vm.assume(owner != _notOwner);

    vm.expectRevert(
      abi.encodeWithSelector(IOwnableAutomationVault.OwnableAutomationVault_OnlyAutomationVaultOwner.selector)
    );

    changePrank(_notOwner);
    keep3rRelayL2.setUsdPerGasUnit(_automationVault, _usdPerGasUnit);
  }

  function testEmitUsdPerGasUnitSetted(
    IAutomationVault _automationVault,
    uint256 _usdPerGasUnit
  ) public happyPath(_automationVault, _usdPerGasUnit) {
    vm.expectEmit();
    emit UsdPerGasUnitSetted(_automationVault, _usdPerGasUnit);

    keep3rRelayL2.setUsdPerGasUnit(_automationVault, _usdPerGasUnit);
  }
}

contract UnitKeep3rRelayL2Exec is Keep3rRelayL2UnitTest {
  modifier happyPath(
    address _relayCaller,
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    uint256 _usdPerGasUnit
  ) {
    assumeNoPrecompiles(address(_automationVault));
    vm.assume(address(_automationVault) != address(vm));
    vm.mockCall(address(_automationVault), abi.encodeWithSelector(IAutomationVault.exec.selector), abi.encode());

    vm.assume(_execData.length > 0 && _execData.length < 30);
    for (uint256 _i; _i < _execData.length; ++_i) {
      vm.assume(_execData[_i].job != address(keep3rV2));
    }

    vm.assume(_usdPerGasUnit > 0);

    vm.mockCall(address(keep3rV2), abi.encodeWithSelector(IKeep3rV2.isKeeper.selector, _relayCaller), abi.encode(true));

    keep3rRelayL2.setUsdPerGasUnitForTest(_automationVault, _usdPerGasUnit);

    vm.startPrank(_relayCaller);
    _;
  }

  function testRevertIfNoExecData(
    address _relayCaller,
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    uint256 _usdPerGasUnit
  ) public happyPath(_relayCaller, _automationVault, _execData, _usdPerGasUnit) {
    _execData = new IAutomationVault.ExecData[](0);

    vm.expectRevert(IKeep3rRelay.Keep3rRelay_NoExecData.selector);

    keep3rRelayL2.exec(_automationVault, _execData);
  }

  function testRevertIfCallerIsNotKeeper(
    address _relayCaller,
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    uint256 _usdPerGasUnit
  ) public happyPath(_relayCaller, _automationVault, _execData, _usdPerGasUnit) {
    address _newCaller = makeAddr('newCaller');
    changePrank(_newCaller);

    vm.mockCall(address(keep3rV2), abi.encodeWithSelector(IKeep3rV2.isKeeper.selector, _newCaller), abi.encode(false));
    vm.expectRevert(IKeep3rRelay.Keep3rRelay_NotKeeper.selector);

    keep3rRelayL2.exec(_automationVault, _execData);
  }

  function testRevertIfExecDataContainsKeep3rV2(
    address _relayCaller,
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    uint256 _usdPerGasUnit
  ) public happyPath(_relayCaller, _automationVault, _execData, _usdPerGasUnit) {
    vm.assume(_execData.length > 3);
    _execData[1].job = address(keep3rV2);

    vm.expectRevert(IKeep3rRelay.Keep3rRelay_Keep3rNotAllowed.selector);

    keep3rRelayL2.exec(_automationVault, _execData);
  }

  function testExpectCallIsKeep3r(
    address _relayCaller,
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    uint256 _usdPerGasUnit
  ) public happyPath(_relayCaller, _automationVault, _execData, _usdPerGasUnit) {
    vm.expectCall(address(keep3rV2), abi.encodeWithSelector(IKeep3rV2.isKeeper.selector, _relayCaller));

    keep3rRelayL2.exec(_automationVault, _execData);
  }

  function testExpectCallWithCorrectsParams(
    address _relayCaller,
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    uint256 _usdPerGasUnit
  ) public happyPath(_relayCaller, _automationVault, _execData, _usdPerGasUnit) {
    IAutomationVault.ExecData[] memory _execDataKeep3r = _buildExecDataKeep3r(_automationVault, _execData, _relayCaller);

    vm.expectCall(
      address(_automationVault),
      abi.encodeWithSelector(
        IAutomationVault.exec.selector, _relayCaller, _execDataKeep3r, new IAutomationVault.FeeData[](0)
      )
    );

    keep3rRelayL2.exec(_automationVault, _execData);
  }

  function testEmitJobExecuted(
    address _relayCaller,
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    uint256 _usdPerGasUnit
  ) public happyPath(_relayCaller, _automationVault, _execData, _usdPerGasUnit) {
    IAutomationVault.ExecData[] memory _execDataKeep3r = _buildExecDataKeep3r(_automationVault, _execData, _relayCaller);

    vm.expectEmit();
    emit AutomationVaultExecuted(_automationVault, _relayCaller, _execDataKeep3r);

    keep3rRelayL2.exec(_automationVault, _execData);
  }

  function _buildExecDataKeep3r(
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    address _relayCaller
  ) internal view returns (IAutomationVault.ExecData[] memory _execDataKeep3r) {
    uint256 _execDataKeep3rLength = _execData.length + 2;
    _execDataKeep3r = new IAutomationVault.ExecData[](_execDataKeep3rLength);

    _execDataKeep3r[0] = IAutomationVault.ExecData({
      job: address(keep3rV2),
      jobData: abi.encodeWithSelector(IKeep3rV2.isKeeper.selector, _relayCaller)
    });

    for (uint256 _i; _i < _execData.length; ++_i) {
      _execDataKeep3r[_i + 1] = _execData[_i];
    }

    _execDataKeep3r[_execData.length + 1] = IAutomationVault.ExecData({
      job: address(keep3rV2),
      jobData: abi.encodeWithSelector(
        IKeep3rJobWorkableRated.worked.selector, _relayCaller, keep3rRelayL2.usdPerGasUnitPerVault(_automationVault)
        )
    });
  }
}
