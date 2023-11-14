// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {PropertyTokenisation} from "../../src/PropertyTokenisation.sol";
import {DeployPropertyTokenisation} from "../../script/DeployPropertyTokenisation.s.sol";

import {PaymentEscrow} from "../../src/PaymentEscrow.sol";
import {DeployPaymentEscrow} from "../../script/DeployPaymentEscrow.s.sol";

import {PropertyToken} from "../../src/PropertyToken.sol";

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract PaymentEscrowTest is StdCheats, Test {
    DeployPropertyTokenisation public deployerPropertyTokenisation;
    DeployPaymentEscrow public deployerPaymentEscrow;

    PropertyTokenisation public propertyTokenisation;
    PaymentEscrow public paymentEscrowContract;

    address public deployerAddress;
    address bob;
    address alice;
    address jayden;

    PropertyTokenisation.Property public defaultProperty;

    uint256 public constant PRICE_PER_TOKEN = 1e13;
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
        deployerPropertyTokenisation = new DeployPropertyTokenisation();
        propertyTokenisation = deployerPropertyTokenisation.run();

        deployerPaymentEscrow = new DeployPaymentEscrow();
        paymentEscrowContract = deployerPaymentEscrow.run(address(propertyTokenisation));
        bob = makeAddr("bob");
        alice = makeAddr("alice");
        jayden = makeAddr("jayden");

        deployerAddress = vm.addr(deployerPaymentEscrow.deployerKey());
    }

    // Test placing a sell order
    function testEscrowPlaceSellOrder() public registerProperty {
        // place a sell order
        uint256 orderTokens = 100000;
        PropertyToken propertyToken = PropertyToken(propertyTokenisation.getPropertyToken(defaultProperty.id));
        vm.startPrank(bob);
        propertyToken.approve(address(paymentEscrowContract), orderTokens);
        string memory orderId = paymentEscrowContract.placeSellOrder(defaultProperty.id, orderTokens, PRICE_PER_TOKEN);

        // check that the sell order was placed
        (string memory id, address user,, string memory propertyId, uint256 tokens, uint256 price) =
            paymentEscrowContract.orderMap(orderId);
        vm.stopPrank();
        assertEq(id, orderId);
        assertEq(user, bob);
        assertEq(propertyId, defaultProperty.id);
        assertEq(tokens, orderTokens);
        assertEq(price, PRICE_PER_TOKEN);
    }

    // Test placing a buy order
    function testEscrowPlaceBuyOrder() public registerProperty {
        uint256 orderTokens = 100000;
        uint256 purchaseAmount = PRICE_PER_TOKEN * orderTokens;
        vm.deal(alice, 10 ether);
        vm.startPrank(alice);
        string memory orderId =
            paymentEscrowContract.placeBuyOrder{value: purchaseAmount}(defaultProperty.id, orderTokens, PRICE_PER_TOKEN);

        // check that the sell order was placed
        (string memory id, address user,, string memory propertyId, uint256 tokens, uint256 price) =
            paymentEscrowContract.orderMap(orderId);
        vm.stopPrank();
        assertEq(id, orderId);
        assertEq(user, alice);
        assertEq(propertyId, defaultProperty.id);
        assertEq(tokens, orderTokens);
        assertEq(price, PRICE_PER_TOKEN);

        assertEq(address(paymentEscrowContract).balance, purchaseAmount);
    }

    // test invalid sell order
    function testEscrowInvalidSellOrder() public registerProperty {
        // place a sell order
        uint256 orderTokens = 0;
        PropertyToken propertyToken = PropertyToken(propertyTokenisation.getPropertyToken(defaultProperty.id));
        vm.startPrank(bob);
        propertyToken.approve(address(paymentEscrowContract), orderTokens);
        vm.expectRevert(
            abi.encodeWithSelector(
                PaymentEscrow.Escrow__InvalidOrder.selector, (orderTokens), (PRICE_PER_TOKEN), (defaultProperty.id)
            )
        );
        paymentEscrowContract.placeSellOrder(defaultProperty.id, orderTokens, PRICE_PER_TOKEN);
        vm.stopPrank();
    }

    // test invalid buy order
    function testEscrowInvalidBuyOrder() public registerProperty {
        // place a sell order
        uint256 orderTokens = 0;
        uint256 purchaseAmount = PRICE_PER_TOKEN * orderTokens;
        vm.deal(alice, 10 ether);
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                PaymentEscrow.Escrow__InvalidOrder.selector, (orderTokens), (PRICE_PER_TOKEN), (defaultProperty.id)
            )
        );
        paymentEscrowContract.placeBuyOrder{value: purchaseAmount}(defaultProperty.id, orderTokens, PRICE_PER_TOKEN);
        vm.stopPrank();
    }

    // test buy order not enough eth sent
    function testEscrowBuyOrderNotEnoughEthSent() public registerProperty {
        // place a sell order
        uint256 orderTokens = 100000;
        uint256 purchaseAmount = PRICE_PER_TOKEN * orderTokens;
        vm.deal(alice, 10 ether);
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                PaymentEscrow.Escrow__NotEnoughEthSent.selector, (defaultProperty.id), (alice), (purchaseAmount - 1)
            )
        );
        paymentEscrowContract.placeBuyOrder{value: purchaseAmount - 1}(defaultProperty.id, orderTokens, PRICE_PER_TOKEN);
        vm.stopPrank();
    }

    // test sell order not enough tokens to sell
    function testEscrowSellOrderNotEnoughTokensToSell() public registerProperty {
        // place a sell order
        uint256 orderTokens = 1000000;
        PropertyToken propertyToken = PropertyToken(propertyTokenisation.getPropertyToken(defaultProperty.id));
        vm.startPrank(bob);
        propertyToken.approve(address(paymentEscrowContract), orderTokens);
        vm.expectRevert(
            abi.encodeWithSelector(
                PaymentEscrow.Escrow__NotEnoughTokensToSell.selector,
                (defaultProperty.id),
                (bob),
                (propertyToken.balanceOf(bob)),
                (orderTokens + 1)
            )
        );
        paymentEscrowContract.placeSellOrder(defaultProperty.id, orderTokens + 1, PRICE_PER_TOKEN);
        vm.stopPrank();
    }

    // test sell order not enough allowance
    function testEscrowSellOrderNotEnoughAllowance() public registerProperty {
        // place a sell order
        uint256 orderTokens = 100000;
        PropertyToken propertyToken = PropertyToken(propertyTokenisation.getPropertyToken(defaultProperty.id));
        vm.startPrank(bob);
        propertyToken.approve(address(paymentEscrowContract), orderTokens - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                PaymentEscrow.Escrow__NotEnoughAllowance.selector,
                (defaultProperty.id),
                (bob),
                (propertyToken.allowance(bob, address(paymentEscrowContract))),
                (orderTokens)
            )
        );
        paymentEscrowContract.placeSellOrder(defaultProperty.id, orderTokens, PRICE_PER_TOKEN);
        vm.stopPrank();
    }

    // test execute orders
    function testEscrowExecuteOrders() public registerProperty {
        // place a sell order
        uint256 orderTokens = 100000;
        PropertyToken propertyToken = PropertyToken(propertyTokenisation.getPropertyToken(defaultProperty.id));
        vm.startPrank(bob);
        propertyToken.approve(address(paymentEscrowContract), orderTokens);
        paymentEscrowContract.placeSellOrder(defaultProperty.id, orderTokens, PRICE_PER_TOKEN);

        // place a buy order
        uint256 purchaseAmount = PRICE_PER_TOKEN * orderTokens;
        vm.deal(alice, 10 ether);
        vm.startPrank(alice);
        paymentEscrowContract.placeBuyOrder{value: purchaseAmount}(defaultProperty.id, orderTokens, PRICE_PER_TOKEN);
        vm.stopPrank();

        // execute orders
        vm.startPrank(deployerAddress);
        paymentEscrowContract.executeOrders();
        vm.stopPrank();

        // check that the tokens were transferred and the ether was transferred
        assertEq(propertyToken.balanceOf(alice), orderTokens);
        assertEq(propertyToken.balanceOf(bob), TOTAL_PROPERTY_TOKENS - orderTokens);

        assertEq(address(paymentEscrowContract).balance, 0);
        assertEq(bob.balance, purchaseAmount);
        assertEq(alice.balance, 10 ether - purchaseAmount);
        assertEq(propertyToken.allowance(bob, address(paymentEscrowContract)), 0);
    }

    // test execute single buy order
    function testEscrowExecuteBuyOrder() public registerProperty {
        PropertyToken propertyToken = PropertyToken(propertyTokenisation.getPropertyToken(defaultProperty.id));
        // place a buy order
        uint256 orderTokens = 100000;
        uint256 purchaseAmount = PRICE_PER_TOKEN * orderTokens;
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        string memory orderId =
            paymentEscrowContract.placeBuyOrder{value: purchaseAmount}(defaultProperty.id, orderTokens, PRICE_PER_TOKEN);

        // execute single buy order

        vm.startPrank(bob);
        propertyToken.approve(address(paymentEscrowContract), orderTokens);
        bool result = paymentEscrowContract.executeBuyOrder(orderId);
        vm.stopPrank();

        assertEq(result, true);

        // check that the tokens were transferred and the ether was transferred
        assertEq(propertyToken.balanceOf(alice), orderTokens);
        assertEq(propertyToken.balanceOf(bob), TOTAL_PROPERTY_TOKENS - orderTokens);
    }

    // test execute single buy order that does not exist
    function testEscrowExecuteBuyOrderNotExist() public registerProperty {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(PaymentEscrow.Escrow__OrderDoesNotExist.selector, ("order-id")));
        paymentEscrowContract.executeBuyOrder("order-id");
        vm.stopPrank();
    }

    // test execute single buy order without enough tokens
    function testEscrowExecuteBuyOrderNotEnoughTokens() public registerProperty {
        PropertyToken propertyToken = PropertyToken(propertyTokenisation.getPropertyToken(defaultProperty.id));
        // place a buy order
        uint256 orderTokens = 100000;
        uint256 purchaseAmount = PRICE_PER_TOKEN * orderTokens;
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        string memory orderId =
            paymentEscrowContract.placeBuyOrder{value: purchaseAmount}(defaultProperty.id, orderTokens, PRICE_PER_TOKEN);

        vm.startPrank(jayden);
        vm.expectRevert(
            abi.encodeWithSelector(
                PaymentEscrow.Escrow__NotEnoughTokensToSell.selector,
                (defaultProperty.id),
                (jayden),
                (propertyToken.balanceOf(jayden)),
                (orderTokens)
            )
        );
        paymentEscrowContract.executeBuyOrder(orderId);
        vm.stopPrank();
    }

    // test execute single buy order without enough allowance
    function testEscrowExecuteBuyOrderNotEnoughAllowance() public registerProperty {
        PropertyToken propertyToken = PropertyToken(propertyTokenisation.getPropertyToken(defaultProperty.id));
        // place a buy order
        uint256 orderTokens = 100000;
        uint256 purchaseAmount = PRICE_PER_TOKEN * orderTokens;
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        string memory orderId =
            paymentEscrowContract.placeBuyOrder{value: purchaseAmount}(defaultProperty.id, orderTokens, PRICE_PER_TOKEN);

        vm.startPrank(bob);
        propertyToken.approve(address(paymentEscrowContract), orderTokens - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                PaymentEscrow.Escrow__NotEnoughAllowance.selector,
                (defaultProperty.id),
                (bob),
                (propertyToken.allowance(bob, address(paymentEscrowContract))),
                (orderTokens)
            )
        );
        paymentEscrowContract.executeBuyOrder(orderId);
        vm.stopPrank();
    }
}
