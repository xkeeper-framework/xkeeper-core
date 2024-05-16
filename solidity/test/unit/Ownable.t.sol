/// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {Test} from 'forge-std/Test.sol';

import {Ownable, IOwnable} from '../../contracts/utils/Ownable.sol';

contract OwnableForTest is Ownable {
  constructor(address _owner) Ownable(_owner) {}

  function setPendingOwnerForTest(address _pendingOwner) public {
    pendingOwner = _pendingOwner;
  }
}

abstract contract OwnableUnitTest is Test {
  /// Events
  event ChangeOwner(address indexed _pendingOwner);
  event AcceptOwner(address indexed _owner);

  /// Ownable contract
  OwnableForTest public ownable;

  /// EOAs
  address public owner;
  address public pendingOwner;

  function setUp() public virtual {
    owner = makeAddr('Owner');
    pendingOwner = makeAddr('PendingOwner');

    ownable = new OwnableForTest(owner);
  }

  /**
   * @notice Helper function to change the prank and expect revert if the caller is not the owner
   */
  function _revertOnlyOwner() internal {
    vm.expectRevert(abi.encodeWithSelector(IOwnable.Ownable_OnlyOwner.selector));
    changePrank(pendingOwner);
  }
}

contract UnitOwnableChangeOwner is OwnableUnitTest {
  function setUp() public override {
    OwnableUnitTest.setUp();

    vm.startPrank(owner);
  }

  /**
   * @notice Checks that the test has to revert if the caller is not the owner
   */
  function testRevertIfCallerIsNotOwner() public {
    _revertOnlyOwner();
    ownable.changeOwner(pendingOwner);
  }

  /**
   * @notice Check that the pending owner is set correctly
   */
  function testSetPendingOwner() public {
    ownable.changeOwner(pendingOwner);

    assertEq(ownable.pendingOwner(), pendingOwner);
  }

  /**
   * @notice  Emit ChangeOwner event when the pending owner is set
   */
  function testEmitChangeOwner() public {
    vm.expectEmit();
    emit ChangeOwner(pendingOwner);

    ownable.changeOwner(pendingOwner);
  }
}

contract UnitOwnableAcceptOwner is OwnableUnitTest {
  function setUp() public override {
    OwnableUnitTest.setUp();

    ownable.setPendingOwnerForTest(pendingOwner);

    vm.startPrank(pendingOwner);
  }

  /**
   * @notice Check that the test has to revert if the caller is not the pending owner
   */
  function testRevertIfCallerIsNotPendingOwner() public {
    vm.expectRevert(abi.encodeWithSelector(IOwnable.Ownable_OnlyPendingOwner.selector));

    changePrank(owner);
    ownable.acceptOwner();
  }

  /**
   * @notice Check that the pending owner accepts the ownership
   */
  function testSetJobOwner() public {
    ownable.acceptOwner();

    assertEq(ownable.owner(), pendingOwner);
  }

  /**
   * @notice Check that the pending owner is set to zero
   */
  function testDeletePendingOwner() public {
    ownable.acceptOwner();

    assertEq(ownable.pendingOwner(), address(0));
  }

  /**
   * @notice Emit AcceptOwner event when the pending owner accepts the ownership
   */
  function testEmitAcceptOwner() public {
    vm.expectEmit();
    emit AcceptOwner(pendingOwner);

    ownable.acceptOwner();
  }
}
