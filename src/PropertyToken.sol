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

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract PropertyToken is ERC20 {
    /////////////////
    // Errors    //
    ////////////////
    error PropertyToken__NotEnoughTokensToTransfer(uint256 balance, uint256 amountToTransfer);
    error PropertyToken__NotEnoughAllowance(uint256 allowance, uint256 amount);

    ////////////////////////
    // State Variables    //
    ///////////////////////
    address[] public owners;
    address public largestOwner;
    uint256 public constant TOTAL_TOKENS = 1000000;

    ///////////////////
    // Events     //
    ///////////////////

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner, uint256 amount);
    event PropertyOwnershipUpdated(address indexed owner);

    constructor() ERC20("PropertyToken", "PT") {
        _mint(msg.sender, TOTAL_TOKENS);
        owners.push(msg.sender);
        largestOwner = msg.sender;
    }

    /**
     * @dev Transfers tokens from the sender's account to another account.
     * @param recipient The address to receive the tokens.
     * @param amount The amount of tokens to transfer.
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        // Check if the sender has enough tokens to transfer
        if (balanceOf(msg.sender) < amount) {
            revert PropertyToken__NotEnoughTokensToTransfer(balanceOf(msg.sender), amount);
        }

        // Perform the transfer to the new owner
        _transfer(msg.sender, recipient, amount);

        // Update the owners list
        updateOwners(recipient);

        // Emit an event to log the ownership transfer
        emit OwnershipTransferred(msg.sender, recipient, amount);

        return true;
    }

    /**
     * @dev Transfers tokens from one account to another if approved by the sender.
     * @param sender The sender's address.
     * @param recipient The address to receive the tokens.
     * @param amount The amount of tokens to transfer.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        // Check if the sender has enough tokens to transfer
        if (balanceOf(sender) < amount) {
            revert PropertyToken__NotEnoughTokensToTransfer(balanceOf(sender), amount);
        }

        // check allowance of sender and msg.sender
        if (allowance(sender, msg.sender) < amount) {
            revert PropertyToken__NotEnoughAllowance(allowance(sender, msg.sender), amount);
        }

        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, allowance(sender, msg.sender) - amount);

        updateOwners(recipient);
        emit OwnershipTransferred(sender, recipient, amount);
        return true;
    }

    /**
     * @dev Approves another address to spend tokens on the sender's behalf.
     * @param spender The address to be approved.
     * @param amount The maximum amount they can spend.
     */
    function approve(address spender, uint256 amount) public override returns (bool) {
        // increment the amount the spender can spend on behalf of the sender by the amount plus the current allowance
        _approve(msg.sender, spender, amount);
        return true;
    }

    // function transferPropertyOwnership(address newOwner, uint256 amount) public returns (bool) {
    //     // Check if the sender has enough tokens to transfer
    //     if (balanceOf(msg.sender) < amount) {
    //         revert PropertyToken__NotEnoughTokensToTransfer(balanceOf(msg.sender), amount);
    //     }

    //     // Perform the transfer to the new owner
    //     _transfer(msg.sender, newOwner, amount);

    //     // Update the owners list
    //     updateOwners(newOwner);

    //     // Emit an event to log the ownership transfer
    //     emit OwnershipTransferred(msg.sender, newOwner, amount);

    //     return true;
    // }

    // function transferPropertyOwnershipFrom(address sender, address recipient, uint256 amount) public returns (bool) {
    //     // Check if the sender has enough tokens to transfer
    //     if (balanceOf(sender) < amount) {
    //         revert PropertyToken__NotEnoughTokensToTransfer(balanceOf(sender), amount);
    //     }
    //     _transfer(sender, recipient, amount);
    //     _approve(sender, msg.sender, allowance(sender, msg.sender) - amount);

    //     emit OwnershipTransferred(sender, recipient, amount);
    //     return true;
    // }

    function getBalance(address account) public view returns (uint256) {
        return balanceOf(account);
    }

    function updateOwners(address newOwner) internal {
        // Check if the new owner is already in the list
        bool ownerExists = false;
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == newOwner) {
                ownerExists = true;
                break;
            }
        }

        // If the new owner is not in the list, add them
        if (!ownerExists) {
            owners.push(newOwner);
        }

        // Update the property owner in the properties mapping
        // The owner is the owner with the most tokens

        uint256 maxTokens = balanceOf(largestOwner);

        for (uint256 i = 0; i < owners.length; i++) {
            if (balanceOf(owners[i]) > maxTokens) {
                maxTokens = balanceOf(owners[i]);
                largestOwner = owners[i];

                emit PropertyOwnershipUpdated(largestOwner);
            }
        }
    }

    // // function to get the allowance of a spender for a specific owner
    // function getAllowance(address owner, address spender) public view returns (uint256) {
    //     return allowance(owner, spender);
    // }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }
}
