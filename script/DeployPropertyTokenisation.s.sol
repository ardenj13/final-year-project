// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {PropertyTokenisation} from "../src/PropertyTokenisation.sol";
import {console} from "forge-std/console.sol";

contract DeployPropertyTokenisation is Script {
    uint256 public DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 public deployerKey;

    function run() external returns (PropertyTokenisation) {
        if (block.chainid == 31337) {
            deployerKey = DEFAULT_ANVIL_PRIVATE_KEY;
        } else {
            deployerKey = vm.envUint("PRIVATE_KEY");
        }
        vm.startBroadcast(deployerKey);
        PropertyTokenisation propertyTokenisation = new PropertyTokenisation();
        vm.stopBroadcast();
        return propertyTokenisation;
    }
}
