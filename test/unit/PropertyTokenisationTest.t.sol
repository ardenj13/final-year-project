// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {PropertyTokenisation} from "../../src/PropertyTokenisation.sol";
import {PropertyToken} from "../../src/PropertyToken.sol";
import {DeployPropertyTokenisation} from "../../script/DeployPropertyTokenisation.s.sol";

import {Test, console} from "forge-std/Test.sol";
// import {Vm} from "forge-std/Vm.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract PropertyTokenisationTest is StdCheats, Test {
    PropertyTokenisation public propertyTokenisation;
    DeployPropertyTokenisation public deployer;
    address public deployerAddress;
    address bob;
    address alice;
    PropertyTokenisation.Property public defaultProperty;
    uint256 public constant TOTAL_PROPERTY_TOKENS = 1000000;

    // modifier to register property

    modifier registerProperty() {
        vm.startPrank(bob);
        defaultProperty = propertyTokenisation.registerProperty(
            "symphony courts",
            "agura road, royal gardens estate, ajah lagos Nigeria",
            "Group of 5 duplex houses",
            200000,
            0,
            4,
            4,
            10000
        );
        // set the propertyToken of the property
        PropertyToken propertyToken = new PropertyToken();
        propertyTokenisation.setPropertyToken(defaultProperty.id, address(propertyToken));
        defaultProperty = propertyTokenisation.getProperty(defaultProperty.id);
        vm.stopPrank();
        _;
    }

    function setUp() public {
        deployer = new DeployPropertyTokenisation();
        propertyTokenisation = deployer.run();
        bob = makeAddr("bob");
        // bob = msg.sender;
        alice = makeAddr("alice");

        deployerAddress = vm.addr(deployer.deployerKey());
    }

    function testTokenisationRegisterProperty() public registerProperty {
        assertEq(defaultProperty.name, "symphony courts");
        assertEq(defaultProperty.location, "agura road, royal gardens estate, ajah lagos Nigeria");
        assertEq(defaultProperty.description, "Group of 5 duplex houses");
        assertEq(defaultProperty.salePrice, 200000);
        assertEq(defaultProperty.rentPrice, 0);
        assertEq(defaultProperty.beds, 4);
        assertEq(defaultProperty.baths, 4);
        assertEq(defaultProperty.sqft, 10000);

        uint256 bobBalance = propertyTokenisation.getPropertyOwnerBalance(defaultProperty.id, bob);
        assertEq(bobBalance, 1000000);
    }

    // Function to test transfering some tokens of the property

    function testTokenisationTransferPropertyTokens() public registerProperty {
        uint256 amountToTransfer = 100000;
        uint256 tokens_per_property = 1000000;
        PropertyToken propertyToken = PropertyToken(propertyTokenisation.getPropertyToken(defaultProperty.id));
        vm.prank(bob);
        propertyToken.transfer(alice, amountToTransfer);
        uint256 aliceBalance = propertyTokenisation.getPropertyOwnerBalance(defaultProperty.id, alice);
        uint256 bobBalance = propertyTokenisation.getPropertyOwnerBalance(defaultProperty.id, bob);
        assertEq(aliceBalance, amountToTransfer);
        assertEq(bobBalance, tokens_per_property - amountToTransfer);

        address[] memory propertyOwners = propertyTokenisation.getPropertyOwners(defaultProperty.id);
        bool isInOwners = false;

        for (uint256 i = 0; i < propertyOwners.length; i++) {
            if (propertyOwners[i] == alice) {
                isInOwners = true;
            }
        }

        assert(isInOwners);
    }

    function testTokenisationUpdatePropertyOwnerAfterTransferPropertyTokens() public registerProperty {
        uint256 amountToTransfer = 700000;
        uint256 tokens_per_property = 1000000;
        PropertyToken propertyToken = PropertyToken(propertyTokenisation.getPropertyToken(defaultProperty.id));
        vm.prank(bob);
        propertyToken.transfer(alice, amountToTransfer);

        uint256 aliceBalance = propertyTokenisation.getPropertyOwnerBalance(defaultProperty.id, alice);
        uint256 bobBalance = propertyTokenisation.getPropertyOwnerBalance(defaultProperty.id, bob);
        assertEq(aliceBalance, amountToTransfer);
        assertEq(bobBalance, tokens_per_property - amountToTransfer);
        // PropertyTokenisation.Property memory property = propertyTokenisation.getProperty(defaultProperty.id);

        assertEq(propertyToken.largestOwner(), alice);
    }

    // function to test attempting to transfer more tokens than the sender has
    function testTokenisationTransferPropertyTokensWithInsufficientBalance() public registerProperty {
        uint256 amountToTransfer = 1000001;
        PropertyToken propertyToken = PropertyToken(propertyTokenisation.getPropertyToken(defaultProperty.id));
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                PropertyToken.PropertyToken__NotEnoughTokensToTransfer.selector,
                (propertyTokenisation.getPropertyOwnerBalance(defaultProperty.id, bob)),
                (amountToTransfer)
            )
        );
        propertyToken.transfer(alice, amountToTransfer);
        vm.stopPrank();
    }

    function testTokenisationGetProperty() public registerProperty {
        PropertyTokenisation.Property memory property = propertyTokenisation.getProperty(defaultProperty.id);
        assertEq(property.name, defaultProperty.name);
        assertEq(property.location, defaultProperty.location);
        assertEq(property.description, defaultProperty.description);
        assertEq(property.salePrice, defaultProperty.salePrice);
        assertEq(property.rentPrice, defaultProperty.rentPrice);
        assertEq(property.beds, defaultProperty.beds);
        assertEq(property.baths, defaultProperty.baths);
        assertEq(property.sqft, defaultProperty.sqft);
    }

    // Test get property but with invalid ID
    // Should revert
    function testTokenisationGetPropertyWithInvalidID() public registerProperty {
        vm.expectRevert(abi.encodeWithSelector(PropertyTokenisation.Property__PropertyNotFound.selector, ("0")));
        propertyTokenisation.getProperty("0");
    }

    // Functions to test getters for the property

    function testTokenisationGetPropertyOwner() public registerProperty {
        assertEq(propertyTokenisation.getPropertyOwner(defaultProperty.id), bob);
    }

    // function testTokenisationGetPropertySalePrice() public registerProperty {
    //     assertEq(propertyTokenisation.getPropertySalePrice(defaultProperty.id), defaultProperty.salePrice);
    // }

    // function testTokenisationGetPropertyRentPrice() public registerProperty {
    //     assertEq(propertyTokenisation.getPropertyRentPrice(defaultProperty.id), defaultProperty.rentPrice);
    // }

    // function testTokenisationGetPropertyBeds() public registerProperty {
    //     assertEq(propertyTokenisation.getPropertyBeds(defaultProperty.id), defaultProperty.beds);
    // }

    // function testTokenisationGetPropertyBaths() public registerProperty {
    //     assertEq(propertyTokenisation.getPropertyBaths(defaultProperty.id), defaultProperty.baths);
    // }

    // function testTokenisationGetPropertySqft() public registerProperty {
    //     assertEq(propertyTokenisation.getPropertySqft(defaultProperty.id), defaultProperty.sqft);
    // }

    // function testTokenisationGetPropertyStatus() public registerProperty {
    //     assert(propertyTokenisation.getPropertyStatus(defaultProperty.id) == defaultProperty.status);
    // }

    // function testTokenisationGetPropertyDescription() public registerProperty {
    //     assertEq(propertyTokenisation.getPropertyDescription(defaultProperty.id), defaultProperty.description);
    // }

    // function testTokenisationGetPropertyLocation() public registerProperty {
    //     assertEq(propertyTokenisation.getPropertyLocation(defaultProperty.id), defaultProperty.location);
    // }

    // function testTokenisationGetPropertyName() public registerProperty {
    //     assertEq(propertyTokenisation.getPropertyName(defaultProperty.id), defaultProperty.name);
    // }

    function testTokenisationGetPropertyToken() public registerProperty {
        assert(propertyTokenisation.getPropertyToken(defaultProperty.id) == defaultProperty.propertyToken);
    }

    // function to test updating the property
    function testTokenisationUpdateProperty() public registerProperty {
        vm.prank(bob);
        propertyTokenisation.updateProperty(
            defaultProperty.id, "new name", "new location", "new description", 50000000, 100000, 10, 10, 8000, "FORSALE"
        );
        PropertyTokenisation.Property memory property = propertyTokenisation.getProperty(defaultProperty.id);
        assertEq(property.name, "new name");
        assertEq(property.location, "new location");
        assertEq(property.description, "new description");
        assertEq(property.salePrice, 50000000);
        assertEq(property.rentPrice, 100000);
        assertEq(property.beds, 10);
        assertEq(property.baths, 10);
        assertEq(property.sqft, 8000);
        assert(property.status == PropertyTokenisation.PropertyStatus.FORSALE);
    }

    // Function to test setting the property when not the owner

    function testTokenisationUpdatePropertyWhenNotOwner() public registerProperty {
        vm.prank(deployerAddress);
        vm.expectRevert(
            abi.encodeWithSelector(PropertyTokenisation.Property__OwnerNotValid.selector, (defaultProperty.id))
        );
        propertyTokenisation.updateProperty(
            defaultProperty.id, "new name", "new location", "new description", 50000000, 100000, 10, 10, 8000, "FORSALE"
        );
    }
}
