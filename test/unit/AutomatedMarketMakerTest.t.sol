// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {PropertyTokenisation} from "../../src/PropertyTokenisation.sol";
import {DeployPropertyTokenisation} from "../../script/DeployPropertyTokenisation.s.sol";

import {AutomatedMarketMaker} from "../../src/AutomatedMarketMaker.sol";
import {DeployAutomatedMarketMaker} from "../../script/DeployAutomatedMarketMaker.s.sol";

import {PropertyToken} from "../../src/PropertyToken.sol";

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract AutomatedMarketMakerTest is StdCheats, Test {
    DeployPropertyTokenisation public deployerPropertyTokenisation;
    DeployAutomatedMarketMaker public deployerAutomatedMarketMaker;

    PropertyTokenisation public propertyTokenisation;
    AutomatedMarketMaker public automatedMarketMakerContract;
    PropertyToken public propertyTokenContract;

    address public deployerAddress;
    address bob;
    address alice;
    address jayden;

    PropertyTokenisation.Property public defaultProperty;

    uint256 public constant PRICE_PER_TOKEN = 1e13;
    uint256 public constant TOTAL_PROPERTY_TOKENS = 1000000;
    uint256 public constant STARTING_BALANCE = 2000 ether;

    uint256 public constant INITIAL_LIQUIDITY_TOKENS = 500000;
    uint256 public constant INITIAL_LIQUIDITY_ETH = 50 ether;
    uint256 public constant ADDITIONAL_LIQUIDITY_TOKENS = 100000;

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

    modifier createPool() {
        address propertyTokenAddress = propertyTokenisation.getPropertyToken(defaultProperty.id);
        propertyTokenContract = PropertyToken(propertyTokenAddress);

        vm.startPrank(bob);
        automatedMarketMakerContract.createPool(propertyTokenAddress);
        vm.stopPrank();
        _;
    }

    modifier addLiquidity() {
        vm.deal(bob, STARTING_BALANCE);
        vm.startPrank(bob);
        propertyTokenContract.approve(address(automatedMarketMakerContract), INITIAL_LIQUIDITY_TOKENS);
        automatedMarketMakerContract.addLiquidity{value: INITIAL_LIQUIDITY_ETH}(
            address(propertyTokenContract), INITIAL_LIQUIDITY_TOKENS
        );
        vm.stopPrank();
        _;
    }

    function setUp() public {
        deployerPropertyTokenisation = new DeployPropertyTokenisation();
        propertyTokenisation = deployerPropertyTokenisation.run();

        deployerAutomatedMarketMaker = new DeployAutomatedMarketMaker();
        automatedMarketMakerContract = deployerAutomatedMarketMaker.run();

        bob = makeAddr("bob");
        alice = makeAddr("alice");
        jayden = makeAddr("jayden");

        deployerAddress = vm.addr(deployerPropertyTokenisation.deployerKey());
    }

    // Test placing add liquidity
    function testAMMAddLiquidity() public registerProperty createPool addLiquidity {
        assertEq(address(automatedMarketMakerContract).balance, INITIAL_LIQUIDITY_ETH);
        assertEq(propertyTokenContract.balanceOf(address(automatedMarketMakerContract)), INITIAL_LIQUIDITY_TOKENS);

        (, uint256 reservePropertyToken, uint256 reserveEth) =
            automatedMarketMakerContract.pools(address(propertyTokenContract));
        assertEq(reservePropertyToken, INITIAL_LIQUIDITY_TOKENS);
        assertEq(reserveEth, INITIAL_LIQUIDITY_ETH);

        assertEq(
            automatedMarketMakerContract.balanceOf(address(propertyTokenContract), bob),
            automatedMarketMakerContract.totalSupply(address(propertyTokenContract))
        );
    }

    // Test placing remove liquidity
    function testAMMRemoveLiquidity() public registerProperty createPool addLiquidity {
        vm.startPrank(bob);
        uint256 shares = automatedMarketMakerContract.balanceOf(address(propertyTokenContract), bob);
        automatedMarketMakerContract.removeLiquidity(address(propertyTokenContract), shares);
        vm.stopPrank();

        (, uint256 reservePropertyToken, uint256 reserveEth) =
            automatedMarketMakerContract.pools(address(propertyTokenContract));

        assertEq(automatedMarketMakerContract.balanceOf(address(propertyTokenContract), bob), 0);
        assertEq(automatedMarketMakerContract.totalSupply(address(propertyTokenContract)), 0);

        assertEq(reservePropertyToken, 0);
        assertEq(reserveEth, 0);

        assertEq(address(automatedMarketMakerContract).balance, 0);
        assertEq(propertyTokenContract.balanceOf(address(automatedMarketMakerContract)), 0);

        assertEq(propertyTokenContract.balanceOf(bob), TOTAL_PROPERTY_TOKENS);
        assertEq(bob.balance, STARTING_BALANCE);
    }

    // // test swap eth for tokens
    function testAMMSwapEthForTokens() public registerProperty createPool addLiquidity {
        uint256 amountIn = 10 ether;
        vm.deal(alice, STARTING_BALANCE);
        vm.startPrank(alice);
        uint256 amountOut =
            automatedMarketMakerContract.swapEthForTokens{value: amountIn}(address(propertyTokenContract));
        vm.stopPrank();

        (, uint256 reservePropertyToken, uint256 reserveEth) =
            automatedMarketMakerContract.pools(address(propertyTokenContract));

        assertEq(reservePropertyToken, INITIAL_LIQUIDITY_TOKENS - amountOut);
        assertEq(reserveEth, amountIn + INITIAL_LIQUIDITY_ETH);

        assertEq(address(automatedMarketMakerContract).balance, amountIn + INITIAL_LIQUIDITY_ETH);
        assertEq(
            propertyTokenContract.balanceOf(address(automatedMarketMakerContract)), INITIAL_LIQUIDITY_TOKENS - amountOut
        );

        assertEq(propertyTokenContract.balanceOf(alice), amountOut);
        assertEq(alice.balance, STARTING_BALANCE - amountIn);
    }

    // // test swap tokens for eth
    function testAMMSwapTokensForEth() public registerProperty createPool addLiquidity {
        uint256 amountIn = 100000;
        vm.startPrank(bob);
        propertyTokenContract.transfer(alice, amountIn);
        vm.stopPrank();

        vm.startPrank(alice);
        propertyTokenContract.approve(address(automatedMarketMakerContract), amountIn);
        uint256 amountOut = automatedMarketMakerContract.swapTokensForEth(address(propertyTokenContract), amountIn);
        vm.stopPrank();

        (, uint256 reservePropertyToken, uint256 reserveEth) =
            automatedMarketMakerContract.pools(address(propertyTokenContract));

        assertEq(reservePropertyToken, INITIAL_LIQUIDITY_TOKENS + amountIn);
        assertEq(reserveEth, INITIAL_LIQUIDITY_ETH - amountOut);

        assertEq(address(automatedMarketMakerContract).balance, INITIAL_LIQUIDITY_ETH - amountOut);
        assertEq(
            propertyTokenContract.balanceOf(address(automatedMarketMakerContract)), INITIAL_LIQUIDITY_TOKENS + amountIn
        );

        assertEq(propertyTokenContract.balanceOf(alice), 0);
        assertEq(alice.balance, amountOut);
    }

    function testAMMGetEstimatedTokensForEth() public registerProperty createPool addLiquidity {
        uint256 amountIn = 10 ether;
        vm.deal(alice, STARTING_BALANCE);

        uint256 expectedTokens =
            automatedMarketMakerContract.getEstimatedTokensForEth(address(propertyTokenContract), amountIn);
        vm.startPrank(alice);
        uint256 amountOut =
            automatedMarketMakerContract.swapEthForTokens{value: amountIn}(address(propertyTokenContract));
        vm.stopPrank();

        assertEq(expectedTokens, amountOut);
    }

    function testAMMGetEstimatedEthForTokens() public registerProperty createPool addLiquidity {
        uint256 amountIn = 100000;
        vm.startPrank(bob);
        propertyTokenContract.transfer(alice, amountIn);
        vm.stopPrank();

        uint256 expectedEth =
            automatedMarketMakerContract.getEstimatedEthForTokens(address(propertyTokenContract), amountIn);
        vm.startPrank(alice);
        propertyTokenContract.approve(address(automatedMarketMakerContract), amountIn);
        uint256 amountOut = automatedMarketMakerContract.swapTokensForEth(address(propertyTokenContract), amountIn);
        vm.stopPrank();

        assertEq(expectedEth, amountOut);
    }

    // function creates a new pool buy first creating a new property token
    function testAMMCreateNewPool() public registerProperty createPool addLiquidity {
        vm.prank(bob);
        PropertyToken pt = new PropertyToken();

        vm.startPrank(bob);
        automatedMarketMakerContract.createPool(address(pt));
        vm.stopPrank();

        (PropertyToken createdPt,,) = automatedMarketMakerContract.pools(address(pt));

        assertEq(address(createdPt), address(pt));
    }

    function testAMMCreateNewPoolAddLiquidity() public registerProperty createPool addLiquidity {
        vm.prank(bob);
        PropertyToken pt = new PropertyToken();

        vm.startPrank(bob);
        automatedMarketMakerContract.createPool(address(pt));

        pt.approve(address(automatedMarketMakerContract), INITIAL_LIQUIDITY_TOKENS);
        automatedMarketMakerContract.addLiquidity{value: INITIAL_LIQUIDITY_ETH}(address(pt), INITIAL_LIQUIDITY_TOKENS);
        vm.stopPrank();

        assertEq(address(automatedMarketMakerContract).balance, INITIAL_LIQUIDITY_ETH + INITIAL_LIQUIDITY_ETH);
        assertEq(pt.balanceOf(address(automatedMarketMakerContract)), INITIAL_LIQUIDITY_TOKENS);

        (, uint256 reservePropertyToken, uint256 reserveEth) = automatedMarketMakerContract.pools(address(pt));
        assertEq(reservePropertyToken, INITIAL_LIQUIDITY_TOKENS);
        assertEq(reserveEth, INITIAL_LIQUIDITY_ETH);

        assertEq(
            automatedMarketMakerContract.balanceOf(address(pt), bob),
            automatedMarketMakerContract.totalSupply(address(pt))
        );
    }

    function testAMMCreateNewPoolRemoveLiquidity() public registerProperty createPool addLiquidity {
        vm.prank(bob);
        PropertyToken pt = new PropertyToken();

        vm.startPrank(bob);
        automatedMarketMakerContract.createPool(address(pt));

        pt.approve(address(automatedMarketMakerContract), INITIAL_LIQUIDITY_TOKENS);
        automatedMarketMakerContract.addLiquidity{value: INITIAL_LIQUIDITY_ETH}(address(pt), INITIAL_LIQUIDITY_TOKENS);

        uint256 shares = automatedMarketMakerContract.balanceOf(address(pt), bob);
        automatedMarketMakerContract.removeLiquidity(address(pt), shares);
        vm.stopPrank();

        (, uint256 reservePropertyToken, uint256 reserveEth) = automatedMarketMakerContract.pools(address(pt));

        assertEq(automatedMarketMakerContract.balanceOf(address(pt), bob), 0);
        assertEq(automatedMarketMakerContract.totalSupply(address(pt)), 0);

        assertEq(reservePropertyToken, 0);
        assertEq(reserveEth, 0);

        assertEq(address(automatedMarketMakerContract).balance, INITIAL_LIQUIDITY_ETH);
        assertEq(pt.balanceOf(address(automatedMarketMakerContract)), 0);

        assertEq(pt.balanceOf(bob), TOTAL_PROPERTY_TOKENS);
        assertEq(bob.balance, STARTING_BALANCE - INITIAL_LIQUIDITY_ETH);
    }

    // Test add additonal liquidity to an existing pool
    function testAMMAddLiquidityTwice() public registerProperty createPool addLiquidity {
        assertEq(address(automatedMarketMakerContract).balance, INITIAL_LIQUIDITY_ETH);
        assertEq(propertyTokenContract.balanceOf(address(automatedMarketMakerContract)), INITIAL_LIQUIDITY_TOKENS);

        (, uint256 reservePropertyToken, uint256 reserveEth) =
            automatedMarketMakerContract.pools(address(propertyTokenContract));
        assertEq(reservePropertyToken, INITIAL_LIQUIDITY_TOKENS);
        assertEq(reserveEth, INITIAL_LIQUIDITY_ETH);

        assertEq(
            automatedMarketMakerContract.balanceOf(address(propertyTokenContract), bob),
            automatedMarketMakerContract.totalSupply(address(propertyTokenContract))
        );

        vm.startPrank(bob);
        propertyTokenContract.approve(address(automatedMarketMakerContract), ADDITIONAL_LIQUIDITY_TOKENS);
        (, uint256 newReservePropertyToken, uint256 newReserveEth) =
            automatedMarketMakerContract.pools(address(propertyTokenContract));

        uint256 additional_liquidity_eth = (newReserveEth * ADDITIONAL_LIQUIDITY_TOKENS) / newReservePropertyToken;
        automatedMarketMakerContract.addLiquidity{value: additional_liquidity_eth}(
            address(propertyTokenContract), ADDITIONAL_LIQUIDITY_TOKENS
        );
        vm.stopPrank();

        assertEq(address(automatedMarketMakerContract).balance, INITIAL_LIQUIDITY_ETH + additional_liquidity_eth);
        assertEq(
            propertyTokenContract.balanceOf(address(automatedMarketMakerContract)),
            INITIAL_LIQUIDITY_TOKENS + ADDITIONAL_LIQUIDITY_TOKENS
        );

        (, uint256 latestReservePropertyToken, uint256 latestReserveEth) =
            automatedMarketMakerContract.pools(address(propertyTokenContract));

        assertEq(latestReservePropertyToken, INITIAL_LIQUIDITY_TOKENS + ADDITIONAL_LIQUIDITY_TOKENS);
        assertEq(latestReserveEth, INITIAL_LIQUIDITY_ETH + additional_liquidity_eth);

        assertEq(
            automatedMarketMakerContract.balanceOf(address(propertyTokenContract), bob),
            automatedMarketMakerContract.totalSupply(address(propertyTokenContract))
        );
    }

    // Test add additonal liquidity to an existing pool after a swap has been made
    function testAMMAddLiquidityTwiceAfterSwap() public registerProperty createPool addLiquidity {
        assertEq(address(automatedMarketMakerContract).balance, INITIAL_LIQUIDITY_ETH);
        assertEq(propertyTokenContract.balanceOf(address(automatedMarketMakerContract)), INITIAL_LIQUIDITY_TOKENS);

        (, uint256 reservePropertyToken, uint256 reserveEth) =
            automatedMarketMakerContract.pools(address(propertyTokenContract));
        assertEq(reservePropertyToken, INITIAL_LIQUIDITY_TOKENS);
        assertEq(reserveEth, INITIAL_LIQUIDITY_ETH);

        assertEq(
            automatedMarketMakerContract.balanceOf(address(propertyTokenContract), bob),
            automatedMarketMakerContract.totalSupply(address(propertyTokenContract))
        );

        // Swap eth for tokens

        uint256 amountIn = 10 ether;
        vm.deal(alice, STARTING_BALANCE);
        vm.startPrank(alice);
        uint256 amountOut =
            automatedMarketMakerContract.swapEthForTokens{value: amountIn}(address(propertyTokenContract));
        vm.stopPrank();

        assertEq(address(automatedMarketMakerContract).balance, amountIn + INITIAL_LIQUIDITY_ETH);
        assertEq(
            propertyTokenContract.balanceOf(address(automatedMarketMakerContract)), INITIAL_LIQUIDITY_TOKENS - amountOut
        );

        // Additional liquidity added
        vm.startPrank(bob);
        propertyTokenContract.approve(address(automatedMarketMakerContract), ADDITIONAL_LIQUIDITY_TOKENS);
        (, uint256 newReservePropertyToken, uint256 newReserveEth) =
            automatedMarketMakerContract.pools(address(propertyTokenContract));

        uint256 additional_liquidity_eth = (newReserveEth * ADDITIONAL_LIQUIDITY_TOKENS) / newReservePropertyToken;
        automatedMarketMakerContract.addLiquidity{value: additional_liquidity_eth}(
            address(propertyTokenContract), ADDITIONAL_LIQUIDITY_TOKENS
        );
        vm.stopPrank();

        assertEq(address(automatedMarketMakerContract).balance, INITIAL_LIQUIDITY_ETH + additional_liquidity_eth + amountIn);
        assertEq(
            propertyTokenContract.balanceOf(address(automatedMarketMakerContract)),
            INITIAL_LIQUIDITY_TOKENS + ADDITIONAL_LIQUIDITY_TOKENS - amountOut
        );

        (, uint256 latestReservePropertyToken, uint256 latestReserveEth) =
            automatedMarketMakerContract.pools(address(propertyTokenContract));

        assertEq(latestReservePropertyToken, INITIAL_LIQUIDITY_TOKENS + ADDITIONAL_LIQUIDITY_TOKENS - amountOut);
        assertEq(latestReserveEth, INITIAL_LIQUIDITY_ETH + additional_liquidity_eth + amountIn);

        assertEq(
            automatedMarketMakerContract.balanceOf(address(propertyTokenContract), bob),
            automatedMarketMakerContract.totalSupply(address(propertyTokenContract))
        );
    }

    function _roundUpToCustom(uint256 value, uint256 custom) private pure returns (uint256) {
        return (value + custom - 1) / custom * custom;
    }
}
