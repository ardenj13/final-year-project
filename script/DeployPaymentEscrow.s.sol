// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {PaymentEscrow} from "../src/PaymentEscrow.sol";

import {console} from "forge-std/console.sol";

contract DeployPaymentEscrow is Script {
    uint256 public DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 public deployerKey;
    address public propertyTokenisationAddress;

    function run(address propertyTokenisation) external returns (PaymentEscrow) {
        if (block.chainid == 31337) {
            deployerKey = DEFAULT_ANVIL_PRIVATE_KEY;
            propertyTokenisationAddress = propertyTokenisation;
        } else {
            deployerKey = vm.envUint("PRIVATE_KEY");
            propertyTokenisationAddress = 0xc3458a4158F89a74f47a981dac8727A8482Ae3f7;
        }
        vm.startBroadcast(deployerKey);
        PaymentEscrow paymentEscrow = new PaymentEscrow(propertyTokenisationAddress);
        vm.stopBroadcast();
        return paymentEscrow;
    }

    // function runAnvil(address propertyTokenisation) external returns (PaymentEscrow) {
    //     vm.startBroadcast(deployerKey);
    //     PaymentEscrow paymentEscrow = new PaymentEscrow(propertyTokenisation);
    //     vm.stopBroadcast();
    //     return paymentEscrow;
    // }
}
