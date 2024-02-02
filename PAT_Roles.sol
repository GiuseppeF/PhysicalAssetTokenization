// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PAT_Roles {
    // A struct to store the details of each registered Vendor
    struct Vendor {
        string name;
        string email;
        bool active;
    }

    // A struct to store the details of each registered WarehouseTokenizator
    struct WarehouseTokenizator {
        string name;
        string email;
        string latlon;
        bool active;
    }

    // A mapping from address to vendors struct
    mapping(address => Vendor) public vendors;

    // A mapping from address to WarehouseTokenizator struct
    mapping(address => WarehouseTokenizator) public warehouseTokenizators;

    // A counter for generating vendor IDs
    uint256 public vendorCounter;

    // A counter for generating warehouseTokenizator IDs
    uint256 public warehouseTokenizatorCounter;

    // An event to emit when a new vendor is registered
    event VendorRegistered(uint256 indexed vendorId, string name);

    // An event to emit when a new warehouseTokenizator is registered
    event WarehouseTokenizatorRegistered(uint256 indexed warehouseTokenizatorId, string name, string latlon);

    // Modifier to check if caller is a vendor
    modifier onlyVendor() {
        require(vendors[msg.sender].active == true, "Caller is NOT a vendor");
        _;
    }

    // Modifier to check if caller is a warehouseTokenizator
    modifier onlyWarehouseTokenizator() {
        require(warehouseTokenizators[msg.sender].active == true, "Caller is NOT a warehouseTokenizator");
        _;
    }

    // Function to register and activate a new vendor
    function vendorRegistration(string memory _name, string memory _email) public returns (uint256) {
        require(warehouseTokenizators[msg.sender].active != true, "Caller is a warehouseTokenizator");

        // Increment the vendor counter
        vendorCounter++;

        // Create a new vendor struct activated by default
        Vendor memory newVendor = Vendor({name: _name, email: _email, active: true});

        // Sender is the address of the new vendor
        vendors[msg.sender] = newVendor;

        // Emit the event for a new vendor registered
        emit VendorRegistered(vendorCounter, _name);

        // return the vendor ID
        return vendorCounter;
    }

    // Function to register and activate a new warehouseTokenizator
    function warehouseTokenizatorRegistration(
        string memory _name,
        string memory _email,
        string memory _latlon
    ) public returns (uint256) {
        require(vendors[msg.sender].active != true, "Caller is a vendor");
        // Increment the token counter
        warehouseTokenizatorCounter++;

        // Create a new warehouseTokenizator struct activated by default
        WarehouseTokenizator memory newWarehouseTokenizator = WarehouseTokenizator({
            name: _name,
            email: _email,
            latlon: _latlon,
            active: true
        });

        // Sender is the address of the new warehouseTokenizator
        warehouseTokenizators[msg.sender] = newWarehouseTokenizator;

        // Emit the event for a new warehouseTokenizator registered
        emit WarehouseTokenizatorRegistered(warehouseTokenizatorCounter, _name, _latlon);

        // return the warehouseTokenizator ID
        return warehouseTokenizatorCounter;
    }
}