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

import {PropertyToken} from "./PropertyToken.sol";

/**
 * @title Property Tokenisation
 * @author Arden Elegbe
 *
 * The Property contract is a contract that manages the properties in the project.
 * It is used to store the details of a property.
 * It is also used to store the details of the owner of the property.
 *
 */

contract PropertyTokenisation {
    /////////////////
    // Errors    //
    ////////////////

    error Property__PropertyNotFound(string propertyID);
    error Property__OwnerNotValid(string propertyID);
    error Property__PropertyTokenAlreadySet(string propertyID);
    error Property__PropertyTokenNotSet(string propertyID);

    ///////////////////////
    // interfaces, libraries, contracts //
    //////////////////////

    ////////////////////////
    // Type Declarations  //
    ///////////////////////

    enum PropertyStatus {
        FORSALE,
        FORRENT,
        INACTIVE
    }

    struct Property {
        string id;
        string name;
        string location;
        string description;
        uint256 salePrice;
        uint256 rentPrice;
        uint256 beds;
        uint256 baths;
        uint256 sqft;
        PropertyStatus status;
        address propertyToken;
    }

    ////////////////////////
    // State Variables    //
    ///////////////////////
    mapping(string => Property) public properties;
    // mapping(string => mapping(address => uint256)) public propertyOwnership;
    // mapping(string => address[]) public propertyOwners;
    string[] public propertyIDs;

    uint256 public constant TOKENS_PER_PROPERTY = 1000000;

    ///////////////////
    // Events     //
    ///////////////////

    event PropertyRegistered(
        string indexed propertyID,
        string name,
        string location,
        string description,
        address indexed owner,
        uint256 salePrice,
        uint256 rentPrice,
        uint256 beds,
        uint256 baths,
        uint256 sqft,
        PropertyStatus status,
        address propertyToken
    );
    event PropertyStatusChanged(string indexed propertyID, address indexed owner, PropertyStatus status);
    event PropertyUpdated(
        string indexed propertyID,
        address indexed owner,
        string name,
        string location,
        string description,
        uint256 salePrice,
        uint256 rentPrice,
        uint256 beds,
        uint256 baths,
        uint256 sqft
    );

    /////////////////
    // Modifiers //
    /////////////////

    // Custom modifier to check if a property exists
    modifier propertyExists(string memory propertyID) {
        if (bytes(properties[propertyID].id).length == 0) {
            revert Property__PropertyNotFound(propertyID);
        }
        _;
    }

    // Custom modifier to check if the sender is the owner of the property
    modifier onlyPropertyOwner(string memory propertyID) {
        Property memory property = properties[propertyID];
        if (property.propertyToken == address(0)) {
            revert Property__PropertyTokenNotSet(propertyID);
        }
        PropertyToken propertyToken = PropertyToken(property.propertyToken);
        if (propertyToken.largestOwner() != msg.sender) {
            revert Property__OwnerNotValid(propertyID);
        }
        _;
    }

    /////////////////
    // Functions //
    /////////////////

    constructor() {}

    /////////////////
    // External  //
    /////////////////

    /////////////////
    // Public    //
    /////////////////

    // Function to register a property
    function registerProperty(
        string memory name,
        string memory location,
        string memory description,
        uint256 salePrice,
        uint256 rentPrice,
        uint256 beds,
        uint256 baths,
        uint256 sqft
    ) public returns (Property memory) {
        // Generate a unique property ID based on location and timestamp
        string memory propertyID = generatePropertyID(location);

        properties[propertyID] = Property({
            id: propertyID,
            location: location,
            description: description,
            name: name,
            salePrice: salePrice,
            rentPrice: rentPrice,
            beds: beds,
            baths: baths,
            sqft: sqft,
            status: PropertyStatus.INACTIVE,
            propertyToken: address(0)
        });

        propertyIDs.push(propertyID);

        // Emit an event to log the property registration
        emit PropertyRegistered(
            propertyID,
            name,
            location,
            description,
            msg.sender,
            salePrice,
            rentPrice,
            beds,
            baths,
            sqft,
            PropertyStatus.INACTIVE,
            address(0)
        );

        return properties[propertyID];
    }

    ////////////////
    // Internal  //
    ////////////////

    /////////////////
    // Private   //
    /////////////////

    /////////////////
    // internal & private view & pure functions //
    /////////////////

    function generatePropertyID(string memory location) internal view returns (string memory) {
        // Generate a unique property ID based on location and timestamp
        uint256 timestamp = block.timestamp;
        bytes32 hash = keccak256(abi.encodePacked(location, timestamp, msg.sender));
        return string(abi.encodePacked("PROP-", uintToString(uint256(hash))));
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

    /////////////////
    // external & public view & pure functions //
    /////////////////

    /**
     * Getter Functions
     */

    // Function to get the details of a property
    function getProperty(string memory propertyID) public view propertyExists(propertyID) returns (Property memory) {
        Property memory property = properties[propertyID];
        return property;
    }

    function getPropertyOwnerBalance(string memory propertyID, address owner)
        public
        view
        propertyExists(propertyID)
        returns (uint256)
    {
        // get the balance of the owner for the specified property from the PropertyToken contract
        address propertyTokenAddress = properties[propertyID].propertyToken;
        PropertyToken token = PropertyToken(propertyTokenAddress);
        return token.balanceOf(owner);
    }

    function getPropertyOwners(string memory propertyID)
        public
        view
        propertyExists(propertyID)
        returns (address[] memory)
    {
        Property memory property = properties[propertyID];
        PropertyToken propertyToken = PropertyToken(property.propertyToken);
        return propertyToken.getOwners();
    }

    function getPropertyOwner(string memory propertyID) public view propertyExists(propertyID) returns (address) {
        Property memory property = properties[propertyID];
        PropertyToken propertyToken = PropertyToken(property.propertyToken);
        return propertyToken.largestOwner();
    }

    function getPropertyToken(string memory propertyID) public view propertyExists(propertyID) returns (address) {
        return properties[propertyID].propertyToken;
    }

    /**
     * Setter Functions
     */
    // function to set the address of the PropertyToken contract for a property.
    // only owner of the property can call this function
    // once the property token is set, it cannot be changed
    function setPropertyToken(string memory propertyID, address propertyTokenAddress)
        public
        propertyExists(propertyID)
        returns (bool)
    {
        // check if the property token is already set
        if (properties[propertyID].propertyToken != address(0)) {
            revert Property__PropertyTokenAlreadySet(propertyID);
        }

        // set the property token
        properties[propertyID].propertyToken = propertyTokenAddress;

        return true;
    }

    // function to update the property information
    function updateProperty(
        string memory propertyID,
        string memory name,
        string memory location,
        string memory description,
        uint256 salePrice,
        uint256 rentPrice,
        uint256 beds,
        uint256 baths,
        uint256 sqft,
        string memory status
    ) public propertyExists(propertyID) onlyPropertyOwner(propertyID) {
        properties[propertyID].name = name;
        properties[propertyID].location = location;
        properties[propertyID].description = description;
        properties[propertyID].salePrice = salePrice;
        properties[propertyID].rentPrice = rentPrice;
        properties[propertyID].beds = beds;
        properties[propertyID].baths = baths;
        properties[propertyID].sqft = sqft;

        if (keccak256(abi.encodePacked(status)) == keccak256(abi.encodePacked("FORSALE"))) {
            properties[propertyID].status = PropertyStatus.FORSALE;
        } else if (keccak256(abi.encodePacked(status)) == keccak256(abi.encodePacked("FORRENT"))) {
            properties[propertyID].status = PropertyStatus.FORRENT;
        } else if (keccak256(abi.encodePacked(status)) == keccak256(abi.encodePacked("INACTIVE"))) {
            properties[propertyID].status = PropertyStatus.INACTIVE;
        }

        emit PropertyUpdated(
            propertyID, msg.sender, name, location, description, salePrice, rentPrice, beds, baths, sqft
        );
    }
}
