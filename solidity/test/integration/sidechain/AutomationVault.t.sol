// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {CommonIntegrationTest} from './Common.t.sol';
import {IERC20, SafeERC20} from 'openzeppelin/token/ERC20/utils/SafeERC20.sol';

import {IOwnable} from '../../../interfaces/core/IAutomationVault.sol';
import {_DAI_WHALE_OP, _DAI_OP} from '../Constants.sol';

contract IntegrationAutomationVault is CommonIntegrationTest {
  using SafeERC20 for IERC20;

  // Events
  event ChangeOwner(address indexed _pendingOwner);
  event AcceptOwner(address indexed _owner);

  //EOAs
  address public newOwner;

  function setUp() public override {
    CommonIntegrationTest.setUp();
    newOwner = makeAddr('NewOwner');
  }

  function test_changeOwnerAndWithdrawFunds(uint64 _amount, uint64 _amountToWithdraw) public {
    // The amount to withdraw should be less than the amount transferred
    vm.assume(_amount > _amountToWithdraw);

    // Transfer DAI to automation vault
    vm.prank(_DAI_WHALE_OP);
    _DAI_OP.safeTransfer(address(automationVault), _amount);

    // Propose new owner
    vm.prank(owner);
    automationVault.changeOwner(newOwner);

    vm.startPrank(newOwner);
    // Try to withdraw funds, should fail because new owner has not confirmed
    vm.expectRevert(abi.encodeWithSelector(IOwnable.Ownable_OnlyOwner.selector));
    automationVault.withdrawFunds(address(_DAI_OP), _amount, newOwner);

    // Balance of DAI should be 0
    uint256 _balance = _DAI_OP.balanceOf(address(automationVault));

    // Confirm new owner and withdraw funds
    automationVault.acceptOwner();
    automationVault.withdrawFunds(address(_DAI_OP), _amountToWithdraw, newOwner);

    // Check that funds were withdrawn
    assertEq(_DAI_OP.balanceOf(newOwner), _amountToWithdraw);
    assertEq(_DAI_OP.balanceOf(address(automationVault)), _balance - _amountToWithdraw);

    // Check that the old owner can't withdraw funds
    changePrank(owner);
    vm.expectRevert(abi.encodeWithSelector(IOwnable.Ownable_OnlyOwner.selector));
    automationVault.withdrawFunds(address(_DAI_OP), _balance - _amountToWithdraw, owner);
  }
}
