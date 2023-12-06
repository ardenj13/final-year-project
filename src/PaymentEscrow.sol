// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {PropertyTokenisation} from "./PropertyTokenisation.sol";
import {PropertyToken} from "./PropertyToken.sol";

/**
 * @title Property Escrow
 * @author Arden Elegbe
 *
 * The Payment Escrow contract is for handling payments for properties.
 * It is a contract that holds funds in escrow until the property is sold.
 */

contract PaymentEscrow {
    // Error messages
    error Escrow__NotEnoughTokensToSell(string propertyId, address seller, uint256 balance, uint256 tokens);
    error Escrow__NotEnoughEthSent(string propertyId, address buyer, uint256 amountSent);
    error Escrow__TransferTokensFromEscrowFailed(string propertyId, uint256 tokens, address seller);
    error Escrow__InvalidOrder(uint256 amount, uint256 price, string propertyId);
    error Escrow__NotEnoughAllowance(string propertyId, address seller, uint256 allowance, uint256 amount);
    error Escrow__OrderDoesNotExist(string orderId);
    error Escrow__OrderNotBuyOrder(string orderId);
    error Escrow__OrderNotSellOrder(string orderId);
    error Escrow__InvalidUser(string orderId, address user);

    PropertyTokenisation public propertyTokenisationContract;

    enum OrderType {
        BUY,
        SELL
    }

    struct Order {
        string id;
        address user;
        OrderType orderType;
        string propertyId;
        uint256 tokens;
        uint256 price;
    }

    Order[] public buyOrders;
    Order[] public sellOrders;

    mapping(string => Order) public orderMap;

    event EscrowBuyOrderPlaced(string propertyId, address buyer, uint256 tokens, uint256 price);
    event EscrowSellOrderPlaced(string propertyId, address seller, uint256 tokens, uint256 price);
    event EscrowOrderExecuted(
        string buyOrderId,
        string sellOrderId,
        string propertyId,
        address buyer,
        address seller,
        uint256 tokens,
        uint256 price
    );

    constructor(address _propertyTokenisationContract) {
        propertyTokenisationContract = PropertyTokenisation(_propertyTokenisationContract);
    }

    function placeBuyOrder(string memory _propertyId, uint256 _tokens, uint256 _price)
        external
        payable
        returns (string memory)
    {
        if (_tokens == 0 || _price == 0 || propertyTokenisationContract.getPropertyToken(_propertyId) == address(0)) {
            revert Escrow__InvalidOrder(_tokens, _price, _propertyId);
        }

        if (msg.value < _price * _tokens) {
            revert Escrow__NotEnoughEthSent(_propertyId, msg.sender, msg.value);
        }

        string memory id = generateEscrowID(_propertyId);

        buyOrders.push(Order(id, msg.sender, OrderType.BUY, _propertyId, _tokens, _price));
        orderMap[id] = Order(id, msg.sender, OrderType.BUY, _propertyId, _tokens, _price);

        // Transfer the received Ether to the escrow identified by escrowId
        // payable(address(this)).transfer(msg.value);

        emit EscrowBuyOrderPlaced(_propertyId, msg.sender, _tokens, _price);

        return id;
    }

    function placeSellOrder(string memory _propertyId, uint256 _tokens, uint256 _price)
        external
        returns (string memory)
    {
        if (_tokens == 0 || _price == 0 || propertyTokenisationContract.getPropertyToken(_propertyId) == address(0)) {
            revert Escrow__InvalidOrder(_tokens, _price, _propertyId);
        }

        PropertyToken propertyToken = PropertyToken(propertyTokenisationContract.getPropertyToken(_propertyId));

        // check that seller has enough tokens to sell
        if (propertyToken.balanceOf(msg.sender) < _tokens) {
            revert Escrow__NotEnoughTokensToSell(_propertyId, msg.sender, propertyToken.balanceOf(msg.sender), _tokens);
        }

        // check the seller has given the escrow enough allowance to transfer tokens
        if (propertyToken.allowance(msg.sender, address(this)) < _tokens) {
            revert Escrow__NotEnoughAllowance(
                _propertyId, msg.sender, propertyToken.allowance(msg.sender, address(this)), _tokens
            );
        }

        string memory id = generateEscrowID(_propertyId);

        sellOrders.push(Order(id, msg.sender, OrderType.SELL, _propertyId, _tokens, _price));
        orderMap[id] = Order(id, msg.sender, OrderType.SELL, _propertyId, _tokens, _price);

        emit EscrowSellOrderPlaced(_propertyId, msg.sender, _tokens, _price);

        return id;
    }

    function executeOrders() external payable {
        uint256 buyIndex = 0;
        uint256 sellIndex = 0;

        while (buyIndex < buyOrders.length && sellIndex < sellOrders.length) {
            Order storage buyOrder = buyOrders[buyIndex];
            Order storage sellOrder = sellOrders[sellIndex];

            if (
                buyOrder.price >= sellOrder.price
                    && keccak256(abi.encodePacked(buyOrder.propertyId)) == keccak256(abi.encodePacked(sellOrder.propertyId))
            ) {
                uint256 matchedTokens = buyOrder.tokens < sellOrder.tokens ? buyOrder.tokens : sellOrder.tokens;

                PropertyToken propertyToken =
                    PropertyToken(propertyTokenisationContract.getPropertyToken(buyOrder.propertyId));

                // Execute the trade, transfer tokens from the seller to the buyer
                bool transferSuccessful = propertyToken.transferFrom(sellOrder.user, buyOrder.user, matchedTokens);
                if (!transferSuccessful) {
                    revert Escrow__TransferTokensFromEscrowFailed(buyOrder.propertyId, matchedTokens, sellOrder.user);
                }

                // and transfer ether from the buyer to the seller
                payable(sellOrder.user).transfer(matchedTokens * sellOrder.price);

                buyOrder.tokens -= matchedTokens;
                sellOrder.tokens -= matchedTokens;

                orderMap[buyOrder.id].tokens -= matchedTokens;
                orderMap[sellOrder.id].tokens -= matchedTokens;

                emit EscrowOrderExecuted(
                    buyOrder.id,
                    sellOrder.id,
                    buyOrder.propertyId,
                    buyOrder.user,
                    sellOrder.user,
                    matchedTokens,
                    sellOrder.price
                );

                // Remove orders if they are completely matched
                if (buyOrder.tokens == 0) {
                    buyIndex++;
                }
                if (sellOrder.tokens == 0) {
                    sellIndex++;
                }
            } else {
                break; // No more matching orders at the current price
            }
        }
    }

    // this function takes an order id that is a buy order and attempts to sell tokens to the buyer at the price of the buy order for all tokens in the buy order
    function executeBuyOrder(string memory _orderId) external payable returns (bool) {
        // check that the order exists
        if (keccak256(abi.encodePacked(orderMap[_orderId].id)) != keccak256(abi.encodePacked(_orderId))) {
            revert Escrow__OrderDoesNotExist(_orderId);
        }

        // check that the order is a buy order
        if (orderMap[_orderId].orderType != OrderType.BUY) {
            revert Escrow__OrderNotBuyOrder(_orderId);
        }

        // check that the order is not already executed
        if (orderMap[_orderId].tokens == 0) {
            return false;
        }

        Order storage buyOrder = orderMap[_orderId];

        PropertyToken propertyToken = PropertyToken(propertyTokenisationContract.getPropertyToken(buyOrder.propertyId));

        // check that the seller has enough tokens to sell
        if (propertyToken.balanceOf(msg.sender) < buyOrder.tokens) {
            revert Escrow__NotEnoughTokensToSell(
                buyOrder.propertyId, msg.sender, propertyToken.balanceOf(msg.sender), buyOrder.tokens
            );
        }

        // check the seller has given the escrow enough allowance to transfer tokens
        if (propertyToken.allowance(msg.sender, address(this)) < buyOrder.tokens) {
            revert Escrow__NotEnoughAllowance(
                buyOrder.propertyId, msg.sender, propertyToken.allowance(msg.sender, address(this)), buyOrder.tokens
            );
        }

        // Execute the trade, transfer tokens from the seller to the buyer and ether from the buyer to the seller

        // Transfer the tokens from the seller to the buyer
        bool transferSuccessful = propertyToken.transferFrom(msg.sender, buyOrder.user, buyOrder.tokens);
        if (!transferSuccessful) {
            revert Escrow__TransferTokensFromEscrowFailed(buyOrder.propertyId, buyOrder.tokens, msg.sender);
        }

        // Transfer ether from the buyer to the seller
        payable(msg.sender).transfer(buyOrder.tokens * buyOrder.price);

        // Update the order in the order map and the buy orders array
        orderMap[_orderId].tokens = 0;

        for (uint256 i = 0; i < buyOrders.length; i++) {
            if (keccak256(abi.encodePacked(buyOrders[i].id)) == keccak256(abi.encodePacked(_orderId))) {
                buyOrders[i].tokens = 0;
                buyOrders[i] = buyOrders[buyOrders.length - 1];
                buyOrders.pop();
                break;
            }
        }

        return true;
    }

    // this function takes an order id that is a sell order and attempts to buy tokens at the price of the sell order for all tokens in the sell order
    function executeSellOrder(string memory _orderId) external payable returns (bool) {
        // check that the order exists
        if (keccak256(abi.encodePacked(orderMap[_orderId].id)) != keccak256(abi.encodePacked(_orderId))) {
            revert Escrow__OrderDoesNotExist(_orderId);
        }

        // check that the order is a sell order
        if (orderMap[_orderId].orderType != OrderType.SELL) {
            revert Escrow__OrderNotSellOrder(_orderId);
        }

        // check that the order is not already executed
        if (orderMap[_orderId].tokens == 0) {
            return false;
        }

        Order storage sellOrder = orderMap[_orderId];

        // check that the buyer has sent enough ether
        if (msg.value < sellOrder.tokens * sellOrder.price) {
            revert Escrow__NotEnoughEthSent(sellOrder.propertyId, msg.sender, msg.value);
        }

        // Check that the seller has enough tokens to sell
        PropertyToken propertyToken = PropertyToken(propertyTokenisationContract.getPropertyToken(sellOrder.propertyId));

        if (propertyToken.balanceOf(sellOrder.user) < sellOrder.tokens) {
            revert Escrow__NotEnoughTokensToSell(
                sellOrder.propertyId, sellOrder.user, propertyToken.balanceOf(sellOrder.user), sellOrder.tokens
            );
        }

        // Check the seller has given the escrow enough allowance to transfer tokens
        if (propertyToken.allowance(sellOrder.user, address(this)) < sellOrder.tokens) {
            revert Escrow__NotEnoughAllowance(
                sellOrder.propertyId, sellOrder.user, propertyToken.allowance(sellOrder.user, address(this)), sellOrder.tokens
            );
        }

        // Execute the trade, transfer tokens from the seller to the buyer and ether from the buyer to the seller
        bool transferSuccessful = propertyToken.transferFrom(sellOrder.user, msg.sender, sellOrder.tokens);
        if (!transferSuccessful) {
            revert Escrow__TransferTokensFromEscrowFailed(sellOrder.propertyId, sellOrder.tokens, sellOrder.user);
        }

        // Transfer ether from the buyer to the seller
        payable(sellOrder.user).transfer(sellOrder.tokens * sellOrder.price);

        // Update the order in the order map and the sell orders array
        orderMap[_orderId].tokens = 0;

        for (uint256 i = 0; i < sellOrders.length; i++) {
            if (keccak256(abi.encodePacked(sellOrders[i].id)) == keccak256(abi.encodePacked(_orderId))) {
                sellOrders[i].tokens = 0;
                sellOrders[i] = sellOrders[sellOrders.length - 1];
                sellOrders.pop();
                break;
            }
        }

        return true;
        
    }

    // function to cancel an order
    function cancelOrder(string memory _orderId) external returns (bool) {
        // check that the order exists
        if (keccak256(abi.encodePacked(orderMap[_orderId].id)) != keccak256(abi.encodePacked(_orderId))) {
            revert Escrow__OrderDoesNotExist(_orderId);
        }

        Order storage order = orderMap[_orderId];

        // check that msg.sender is the user who placed the order
        if (msg.sender != order.user) {
            revert Escrow__InvalidUser(_orderId, msg.sender);
        }

        // check that the order is a buy order
        if (order.orderType == OrderType.BUY && order.tokens != 0) {
            // return the ether to the buyer
            payable(order.user).transfer(order.tokens * order.price);
        }

        // Update the order in the order map and the buy orders array
        orderMap[_orderId].tokens = 0;

        if (order.orderType == OrderType.BUY) {
            // remove the order from the buy orders array
            for (uint256 i = 0; i < buyOrders.length; i++) {
                if (keccak256(abi.encodePacked(buyOrders[i].id)) == keccak256(abi.encodePacked(_orderId))) {
                    buyOrders[i].tokens = 0;
                    buyOrders[i] = buyOrders[buyOrders.length - 1];
                    buyOrders.pop();
                    break;
                }
            }
        } else {
            for (uint256 i = 0; i < sellOrders.length; i++) {
                if (keccak256(abi.encodePacked(sellOrders[i].id)) == keccak256(abi.encodePacked(_orderId))) {
                    sellOrders[i].tokens = 0;
                    sellOrders[i] = sellOrders[sellOrders.length - 1];
                    sellOrders.pop();
                    break;
                }
            }
        }

        return true;
    }

    // function to get the number of buy orders
    function getNumberOfBuyOrders() external view returns (uint256) {
        return buyOrders.length;
    }

    // function to get the number of sell orders
    function getNumberOfSellOrders() external view returns (uint256) {
        return sellOrders.length;
    }

    // Function to remove orders with tokens == 0
    // function removeOrdersWithZeroTokens() public {
    //     // Create a memory array to temporarily hold the filtered elements
    //     Order[] memory filteredOrders = new Order[](buyOrders.length);
    //     uint256 writeIndex = 0;

    //     for (uint256 readIndex = 0; readIndex < buyOrders.length; readIndex++) {
    //         if (buyOrders[readIndex].tokens != 0) {
    //             filteredOrders[writeIndex] = buyOrders[readIndex];
    //             writeIndex++;
    //         }
    //     }

    //     // Resize the storage array and copy filtered elements back
    //     buyOrders.length = writeIndex;
    //     for (uint256 i = 0; i < writeIndex; i++) {
    //         buyOrders[i] = filteredOrders[i];
    //     }
    // }

    function generateEscrowID(string memory propertyId) internal view returns (string memory) {
        // Generate a unique escrow ID based on property Id, timestamp and sender address
        uint256 timestamp = block.timestamp;
        bytes32 hash = keccak256(abi.encodePacked(propertyId, timestamp, msg.sender));
        return string(abi.encodePacked("ESCROW-", uintToString(uint256(hash))));
    }

    function uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 length;
        while (temp != 0) {
            length++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(length);
        while (value != 0) {
            length -= 1;
            buffer[length] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
