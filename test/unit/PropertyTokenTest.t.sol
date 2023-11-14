// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {PropertyToken} from "../../src/PropertyToken.sol";

contract PropertyTokenTest is StdCheats, Test {
    address bob;
    address alice;
    address jayden;
    PropertyToken public propertyToken;

    function setUp() public {
        bob = makeAddr("bob");
        alice = makeAddr("alice");
        jayden = makeAddr("jayden");
        vm.prank(bob);
        // Deploy a new PropertyToken contract with an initial supply of 1000 tokens
        propertyToken = new PropertyToken();
    }

    function testERC20TokenInitialSupply() public {
        // Verify that the total supply is set to 1000
        assertEq(propertyToken.totalSupply(), 1000000);

        // Check the balance of the sender, which should be 1000 since the constructor mints all initial supply to the sender
        assertEq(propertyToken.getBalance(bob), 1000000);

        assertEq(propertyToken.balanceOf(alice), 0);

        // Verify that the owner of the contract is the sender
        assertEq(propertyToken.largestOwner(), bob);

        // verify that bob is in the owners list
        assertEq(propertyToken.owners(0), bob);
    }

    // function test transfering tokens from one account to another
    function testERC20TokenTransfer() public {
        vm.prank(bob);
        propertyToken.transfer(alice, 700000);

        assertEq(propertyToken.getBalance(bob), 300000);

        assertEq(propertyToken.getBalance(alice), 700000);

        assertEq(propertyToken.largestOwner(), alice);

        // check that alice and bob are in the owners list by looping through the list
        assertEq(propertyToken.owners(0), bob);
        assertEq(propertyToken.owners(1), alice);
    }

    // function test approve and transferFrom
    function testERC20TokenTransferFrom() public {
        vm.prank(bob);
        propertyToken.approve(jayden, 500000);

        assertEq(propertyToken.allowance(bob, jayden), 500000);

        vm.prank(jayden);
        propertyToken.transferFrom(bob, alice, 500000);

        assertEq(propertyToken.getBalance(bob), 500000);

        assertEq(propertyToken.getBalance(alice), 500000);

        // check allowance

        assertEq(propertyToken.allowance(bob, jayden), 0);
    }

    // function test transferFrom but expect revert because of not enough allowance

    function testERC20TokenTransferFromFail() public {
        vm.prank(bob);
        propertyToken.approve(jayden, 100000);

        assertEq(propertyToken.allowance(bob, jayden), 100000);

        vm.expectRevert(
            abi.encodeWithSelector(
                PropertyToken.PropertyToken__NotEnoughAllowance.selector,
                (propertyToken.allowance(bob, jayden)),
                (500000)
            )
        );
        vm.prank(jayden);
        propertyToken.transferFrom(bob, alice, 500000);
    }
}
