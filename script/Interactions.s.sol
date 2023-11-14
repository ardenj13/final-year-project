// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {PropertyTokenisation} from "../src/PropertyTokenisation.sol";

contract RegisterProperty is Script {
    function run() external {
        address mostRecentlyPropertyTokenisationAddress = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
        // DevOpsTools.get_most_recent_deployment("PropertyTokenisation", block.chainid);
        registerPropertyWithContract(mostRecentlyPropertyTokenisationAddress);
    }

    function registerPropertyWithContract(address propertyTokenisationAddress) public {
        vm.startBroadcast();
        PropertyTokenisation.Property memory property = PropertyTokenisation(propertyTokenisationAddress)
            .registerProperty(
            "symphony courts",
            "agura road, royal gardens estate, ajah lagos Nigeria",
            "Group of 5 duplex houses",
            200000,
            0,
            4,
            4,
            10000
        );
        console.log("Property registered with id: %s", property.id);
        console.log("Property registered name: %s", property.name);
        vm.stopBroadcast();
    }
}

contract GetProperty is Script {
    function run() external {
        address mostRecentlyPropertyTokenisationAddress = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
        // DevOpsTools.get_most_recent_deployment("PropertyTokenisation", block.chainid);
        getProperty(
            mostRecentlyPropertyTokenisationAddress,
            "PROP-84740031436689766486799662925355719978437433477846016078775259185331407332477"
        );
    }

    function getProperty(address propertyTokenisationAddress, string memory propertyId) public {
        vm.startBroadcast();
        console.log("Property id: %s", propertyId);
        PropertyTokenisation propertyTokenisation = PropertyTokenisation(propertyTokenisationAddress);

        PropertyTokenisation.Property memory property = propertyTokenisation.getProperty(propertyId);

        console.log("Property registered with id: %s", property.id);
        console.log("Property registered name: %s", property.name);

        vm.stopBroadcast();
    }
}

contract GetPropertyOwnerBalance is Script {
    function run() external {
        address mostRecentlyPropertyTokenisationAddress = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
        // DevOpsTools.get_most_recent_deployment("PropertyTokenisation", block.chainid);
        getPropertyOwnerBalance(
            mostRecentlyPropertyTokenisationAddress,
            "PROP-84740031436689766486799662925355719978437433477846016078775259185331407332477"
        );
    }

    function getPropertyOwnerBalance(address propertyTokenisationAddress, string memory propertyId) public {
        vm.startBroadcast();
        console.log("Property id: %s", propertyId);
        PropertyTokenisation propertyTokenisation = PropertyTokenisation(propertyTokenisationAddress);

        address ownerAddress = propertyTokenisation.getPropertyOwner(propertyId);
        console.log("Property Owner Address: %s", ownerAddress);
        uint256 ownerBalance = propertyTokenisation.getPropertyOwnerBalance(propertyId, ownerAddress);
        console.log("Property Owner Balance: %s", ownerBalance);

        vm.stopBroadcast();
    }
}
