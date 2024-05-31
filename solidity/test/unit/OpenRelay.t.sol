// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin/token/ERC20/utils/SafeERC20.sol';

import {OpenRelay, IOpenRelay} from '../../contracts/relays/OpenRelay.sol';
import {IOwnable} from '../../interfaces/utils/IOwnable.sol';
import {IOwnableAutomationVault} from '../../contracts/utils/OwnableAutomationVault.sol';
import {IAutomationVault} from '../../interfaces/core/IAutomationVault.sol';
import {_NATIVE_TOKEN} from '../../utils/Constants.sol';

contract OpenRelayForTest is OpenRelay {
  function setExtraPaymentForTest(
    IAutomationVault _automationVault,
    address _job,
    IOpenRelay.PaymentData memory _paymentData
  ) external {
    paymentsData[_automationVault][_job] = _paymentData;
  }
}

/**
 * @title OpenRelay Unit tests
 */
contract OpenRelayUnitTest is Test {
  // Events
  event AutomationVaultExecuted(
    IAutomationVault indexed _automationVault,
    address indexed _relayCaller,
    IAutomationVault.ExecData[] _execData,
    IAutomationVault.FeeData[] _feeData
  );

  event ExtraPaymentSetted(
    IAutomationVault indexed _automationVault, address indexed _job, IOpenRelay.PaymentData _paymentData
  );

  // OpenRelay contract
  OpenRelayForTest public openRelay;

  // Mock EOAs
  address public relayCaller;
  address public owner;

  function setUp() public virtual {
    relayCaller = makeAddr('RelayCaller');
    owner = makeAddr('Owner');

    openRelay = new OpenRelayForTest();
  }
}

contract UnitOpenRelayConstructor is OpenRelayUnitTest {
  function testSetGasBonus() public {
    assertEq(openRelay.GAS_BONUS(), 53_000);
  }

  function testSetGasMultiplier() public {
    assertEq(openRelay.GAS_MULTIPLIER(), 12_000);
  }

  function testSetBase() public {
    assertEq(openRelay.BASE(), 10_000);
  }
}

contract UnitOpenRelaySetExtraPayment is OpenRelayUnitTest {
  modifier happyPath(IAutomationVault _automationVault) {
    vm.mockCall(address(_automationVault), abi.encodeWithSelector(IOwnable.owner.selector), abi.encode(owner));
    vm.startPrank(owner);
    _;
  }

  function testRevertIfNotAutomationVaultOwner(
    IAutomationVault _automationVault,
    address _job,
    IOpenRelay.PaymentData memory _paymentData
  ) public happyPath(_automationVault) {
    vm.expectRevert(IOwnableAutomationVault.OwnableAutomationVault_OnlyAutomationVaultOwner.selector);
    changePrank(makeAddr('NotOwner'));
    openRelay.setExtraPayment(_automationVault, _job, _paymentData);
  }

  function testSetExtraPayment(
    IAutomationVault _automationVault,
    address _job,
    IOpenRelay.PaymentData memory _paymentData
  ) public happyPath(_automationVault) {
    openRelay.setExtraPayment(_automationVault, _job, _paymentData);

    (IERC20 _token, uint256 _amountOrPercentage) = openRelay.paymentsData(_automationVault, _job);

    assertEq(address(_token), address(_paymentData.token));
    assertEq(_amountOrPercentage, _paymentData.amountOrPercentage);
  }

  function testEmitExtraPaymentSetted(
    IAutomationVault _automationVault,
    address _job,
    IOpenRelay.PaymentData memory _paymentData
  ) public happyPath(_automationVault) {
    vm.expectEmit();
    emit ExtraPaymentSetted(_automationVault, _job, _paymentData);

    openRelay.setExtraPayment(_automationVault, _job, _paymentData);
  }
}

contract UnitOpenRelayExec is OpenRelayUnitTest {
  modifier happyPath(IAutomationVault _automationVault) {
    assumeNoPrecompiles(address(_automationVault));
    vm.assume(address(_automationVault) != address(vm));
    vm.mockCall(address(_automationVault), abi.encodeWithSelector(IAutomationVault.exec.selector), abi.encode());

    vm.startPrank(relayCaller);
    _;
  }

  function testRevertIfNoExecData(
    IAutomationVault _automationVault,
    address _feeRecipient
  ) public happyPath(_automationVault) {
    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);

    _execData = new IAutomationVault.ExecData[](0);

    vm.expectRevert(IOpenRelay.OpenRelay_NoExecData.selector);

    openRelay.exec(_automationVault, _execData, _feeRecipient);
  }

  function testCallAutomationVaultExecJobFunction(
    IAutomationVault _automationVault,
    IAutomationVault.ExecData memory _execDataOne,
    address _feeRecipient
  ) public happyPath(_automationVault) {
    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] = _execDataOne;

    vm.expectCall(
      address(_automationVault),
      abi.encodeCall(IAutomationVault.exec, (relayCaller, _execData, new IAutomationVault.FeeData[](0))),
      1
    );

    openRelay.exec(_automationVault, _execData, _feeRecipient);
  }

  function testCallAutomationVaultExecIssuePaymentWithoutExtra(
    IAutomationVault _automationVault,
    IAutomationVault.ExecData memory _execDataOne,
    address _feeRecipient
  ) public happyPath(_automationVault) {
    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] = _execDataOne;

    IAutomationVault.FeeData[] memory _feeData = new IAutomationVault.FeeData[](1);
    _feeData[0] = IAutomationVault.FeeData(_feeRecipient, _NATIVE_TOKEN, 0);

    vm.expectCall(
      address(_automationVault),
      abi.encodeCall(IAutomationVault.exec, (relayCaller, new IAutomationVault.ExecData[](0), _feeData)),
      1
    );

    openRelay.exec(_automationVault, _execData, _feeRecipient);
  }

  function testCallAutomationVaultExecIssuePaymentWithExtraPercentage(
    IAutomationVault _automationVault,
    IAutomationVault.ExecData memory _execDataOne,
    address _feeRecipient,
    uint256 _amountOrPercentage
  ) public happyPath(_automationVault) {
    vm.assume(_amountOrPercentage > 10_000 && _amountOrPercentage < 100_000);

    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] = _execDataOne;

    IAutomationVault.FeeData[] memory _feeData = new IAutomationVault.FeeData[](1);
    _feeData[0] = IAutomationVault.FeeData(_feeRecipient, _NATIVE_TOKEN, 0);

    IOpenRelay.PaymentData memory _paymentData = IOpenRelay.PaymentData(IERC20(_NATIVE_TOKEN), _amountOrPercentage);

    openRelay.setExtraPaymentForTest(_automationVault, _execData[0].job, _paymentData);

    vm.expectCall(
      address(_automationVault),
      abi.encodeCall(IAutomationVault.exec, (relayCaller, new IAutomationVault.ExecData[](0), _feeData)),
      1
    );

    openRelay.exec(_automationVault, _execData, _feeRecipient);
  }

  function testCallAutomationVaultExecIssuePaymentWithExtraToken(
    IAutomationVault _automationVault,
    IAutomationVault.ExecData memory _execDataOne,
    address _feeRecipient,
    address _token,
    uint256 _amountOrPercentage
  ) public happyPath(_automationVault) {
    vm.assume(_token != address(0) && _token != _NATIVE_TOKEN);
    vm.assume(_amountOrPercentage > 10_000 && _amountOrPercentage < 100_000);

    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] = _execDataOne;

    IAutomationVault.FeeData[] memory _feeData = new IAutomationVault.FeeData[](1);
    _feeData[0] = IAutomationVault.FeeData(_feeRecipient, _token, _amountOrPercentage);

    IOpenRelay.PaymentData memory _paymentData = IOpenRelay.PaymentData(IERC20(_token), _amountOrPercentage);

    openRelay.setExtraPaymentForTest(_automationVault, _execData[0].job, _paymentData);

    vm.expectCall(
      address(_automationVault),
      abi.encodeCall(IAutomationVault.exec, (relayCaller, new IAutomationVault.ExecData[](0), _feeData)),
      1
    );

    openRelay.exec(_automationVault, _execData, _feeRecipient);
  }

  function testEmitAutomationVaultExecuted(
    IAutomationVault _automationVault,
    IAutomationVault.ExecData memory _execDataOne,
    address _feeRecipient
  ) public happyPath(_automationVault) {
    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] = _execDataOne;

    IAutomationVault.FeeData[] memory _feeData = new IAutomationVault.FeeData[](1);
    _feeData[0] = IAutomationVault.FeeData(_feeRecipient, _NATIVE_TOKEN, 0);

    vm.expectEmit();
    emit AutomationVaultExecuted(_automationVault, relayCaller, _execData, _feeData);

    openRelay.exec(_automationVault, _execData, _feeRecipient);
  }
}
