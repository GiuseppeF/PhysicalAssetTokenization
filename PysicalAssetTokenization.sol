// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// A contract for tokenizing physical tokens with three roles and feedback management 
contract TokenTokenWithRolesAndFeedback { 

    // A struct to store the details of each token 
    struct Token { 
        string  name;           // The name of the token 
        string  description;    // A brief description of the token 
        uint256 value;          // The value of the token in wei 
        address originator;     // The address of the Vendor who started the tokenization
        address warehouse;      // The address of the WarehouseTokenizator who custodies the token 
        address owner;          // The current owner of the Token
        bool    active;         // Whether the token is active or not 
    }

    struct Vendor {
        string name;
        uint256 reputation;
        bool active;
    }

    struct WarehouseTokenizator {
        string name;
        string latlon;
        uint256 reputation;
        bool active;
    }

    // A mapping from token struct to current owner address
    mapping (uint256 => address) public tokenOwner;

    // A mapping from address to vendors struct
    mapping (address => Vendor) public vendors;

    // A mapping from address to WarehouseTokenizator struct
    mapping (address => WarehouseTokenizator) public warehouseTokenizators;

    // A mapping from token ID to token struct
    mapping (uint256 => Token) public tokens;

    // A mapping from address to an array of ratings
    mapping (address => uint256[]) public ratings;

    // A counter for generating vendor IDs
    uint256 public vendorCounter;

    // A counter for generating warehouseTokenizator IDs
    uint256 public warehouseTokenizatorCounter;

    // A counter for generating token IDs
    uint256 public tokenCounter;

    // An event to emit when a new vendor is registered
    event VendorRegistered(uint256 indexed vendorId, string name);

    // An event to emit when a new warehouseTokenizator is registered
    event warehouseTokenizatorRegistered(uint256 indexed warehouseTokenizatorId, string name, string latlon);

    // An event to emit when an token is created by a vendor
    event TokenCreated(uint256 indexed tokenId, string name, string description, uint256 value, address owner);

    // An event to emit when a token is activated by a WarehouseTokenizator
    event TokenActivated(uint256 indexed tokenId, address WarehouseTokenizator, address owner);

    // An event to emit when a token is transferred by a trader
    event TokenTransferred(uint256 indexed tokenId, address from, address to);

    event RedemptionRequested(uint256 indexed _tokenId, address warehouse);

    // An event to emit when an token is released by a WarehouseTokenizator
    event TokenReleased(uint256 indexed tokenId, address warehouse);

    // An event to emit when a token is burned by a trader
    event TokenBurned(uint256 indexed tokenId);

    // An event to emit when a rating is given by a participant
    event RatingGiven(address from, address to, uint256 rating);

    // A modifier to check if caller is a vendor
    modifier onlyVendor() {
        require(vendors[msg.sender].active == true, "Caller is NOT a vendor");
        _;
    }

    // A modifier to check if caller is a warehouseTokenizator
    modifier onlyWarehouseTokenizator() {
        require(warehouseTokenizators[msg.sender].active == true, "Caller is NOT a warehouseTokenizator");
        _;
    }

    // A modifier to check if the caller is the owner of a tokenId
    modifier onlyTokenOwner(uint256 _tokenId) {
        require(tokens[_tokenId].owner == msg.sender, "Caller is NOT the owner of this tokenId");
        _;
    }

    // A modifier to check if the caller is the warehouse of a token
    modifier onlyTokenWarehouse(uint256 _tokenId) {
        require(tokens[_tokenId].warehouse == msg.sender, "Only the token warehouse can call this function");
        _;
    }

    // A modifier to check if an token is active
    modifier onlyActiveToken(uint256 _tokenId) {
        require(tokens[_tokenId].active == true, "The token is not active");
        _;
    }

    // A function to register and activate a new vendor
    function vendorRegistration(string memory _name) public returns (uint256) {
        // Increment the vendor counter
        vendorCounter++;

        // Create a new vendor struct activated by dafault
        Vendor memory newVendor = Vendor({
            name: _name,
            reputation: 0,
            active: true
        }); 

        // Sender is the address of the new vendor
        vendors[msg.sender] = newVendor;

        // Emit the event for a new vendor registered
        emit VendorRegistered(vendorCounter, _name);

        // return the vendor ID
        return vendorCounter;
    }

    // A function to register and activate a new warehouseTokenizator
    function warehouseTokenizatorRegistration(string memory _name, string memory _latlon) public returns (uint256) {
        // Increment the token counter
        warehouseTokenizatorCounter++;

        // Create a new warehouseTokenizator struct activated by dafault
        WarehouseTokenizator memory newWarehouseTokenizator = WarehouseTokenizator({
            name: _name,
            latlon: _latlon,
            reputation: 0,
            active: true
        }); 

        // Sender is the address of the new warehouseTokenizator
        warehouseTokenizators[msg.sender] = newWarehouseTokenizator;

        // Emit the event for a new warehouseTokenizator registered
        emit warehouseTokenizatorRegistered(warehouseTokenizatorCounter, _name, _latlon);

        // return the warehouseTokenizator ID
        return warehouseTokenizatorCounter;
    }

    // A function to create a new token by a vendor
    function createToken(string memory _name, string memory _description, uint256 _value) public onlyVendor() returns (uint256) {
        // Increment the token counter
        tokenCounter++;

        // Create a new token struct with the vendor as the owner and no warehouse assigned yet
        Token memory newToken = Token({
            name: _name,
            description: _description,
            value: _value,
            originator: msg.sender,
            warehouse: address(0),
            owner: msg.sender,
            active: false
        });

        // Store the token in the mapping
        tokens[tokenCounter] = newToken;

        // Emit an event
        emit TokenCreated(tokenCounter, _name, _description, _value, msg.sender);

        // Return the token ID
        return tokenCounter;
    }

    // A function to receive an existing token by a WarehouseTokenizator and create a new token for it
    function receiveToken(uint256 _tokenId) public onlyWarehouseTokenizator() onlyActiveToken(_tokenId) {
        
        // first check that this request is valid through integrity has of signed WT proposal!

        // this function must be payable, vendor must send the entire quotation requested by WT

 // EXAMPLE OF HOW TO SEND AMOUNT TO ANOTHER ADDRESS
 /*       
    function sendViaCall(address payable _to) public payable {
        // Call returns a boolean value indicating success or failure.
        // This is the current recommended method to use.
        (bool sent, bytes memory data) = _to.call{value: msg.value}("");
        require(sent, "Failed to send Ether");
    }
*/
        // once made all of these checks, THEN DO THE FOLLOWING!
        
        // Make the token active
        tokens[_tokenId].warehouse = msg.sender;
        tokens[_tokenId].owner = tokens[_tokenId].originator;
        tokens[_tokenId].active = true;

        // Emit an event
        emit TokenActivated(_tokenId, tokens[_tokenId].warehouse, tokens[_tokenId].owner);

    }

    // A function to transfer an existing token to another address by a trader
    function transferToken(uint256 _tokenId, address _to) public onlyTokenOwner(_tokenId) onlyActiveToken(_tokenId) {
        // Update the owner of the token to be the recipient of this function
        tokens[_tokenId].owner = _to;

        // Emit an event
        emit TokenTransferred(_tokenId, msg.sender, _to);
    }

    // Redemption request
    function redemptionRequest(uint256 _tokenId) public onlyTokenOwner(_tokenId) {

        // To request the asset redemption, owner transfer the token ownership to the warehouse who holds the asset
        tokens[_tokenId].owner = tokens[_tokenId].warehouse;

        // aggiungere il tempo
        emit RedemptionRequested(_tokenId, tokens[_tokenId].warehouse);
    }

    // A function to burn an existing token
    function burnToken(uint256 _tokenId) public onlyTokenWarehouse(_tokenId) onlyActiveToken(_tokenId) onlyTokenOwner(_tokenId) {
        
        // This action is only available when redemption has requested and warehouse provides proof of delivery
        require(tokens[_tokenId].owner == tokens[_tokenId].warehouse);

        // Performs proof of delivery here

        // Release the payment

        // Release feedbacks

        // Unactivate the tokenId
        tokens[_tokenId].active = false;

        // Emit an event
        emit TokenReleased(_tokenId, tokens[_tokenId].warehouse);
    }
/*
    // A function to give a rating to another participant after a transaction
    function giveRating(address _to, uint256 _rating) public {
        // Check if the rating is between 1 and 5 (inclusive)
        require(_rating >= 1 && _rating <= 5, "The rating must be between 1 and 5");

        // Check if the caller and the recipient are involved in a transaction
        bool valid = false;
        for (uint256 i = 1; i <= tokenCounter; i++) {
    //        if (tokens[i].active == false && ((tokens[i].vendor == msg.sender && tokens[i].warehouse == _to) || (tokens[i].warehouse == msg.sender && tokens[i].vendor == _to))) {
                valid = true;
                break;
            }
 //       }
 //       for (uint256 j = 1; j <= tokenCounter; j++) {
 //           if (tokens[j].active == false && ((tokens[j].owner == msg.sender && tokens[tokens[j].tokenId].warehouse == _to) || (tokens[j].owner == _to && tokens[tokens[j].tokenId].warehouse == msg.sender))) {
 //               valid = true;
 //               break;
            }
 //       }
 //       require(valid == true, "The caller and the recipient are not involved in a transaction");

        // Append the rating to the array of ratings for the recipient
 //       ratings[_to].push(_rating);

        // Emit an event
 //       emit RatingGiven(msg.sender, _to, _rating);
 //   }

    // A function to get the average rating for an address
    function getAverageRating(address _address) public view returns (uint256) {
        // Check if the address has any ratings
        require(ratings[_address].length > 0, "The address has no ratings");

        // Calculate the sum of ratings for the address
        uint256 sum = 0;
        for (uint256 i = 0; i < ratings[_address].length; i++) {
            sum += ratings[_address][i];
        }

        // Calculate and return the average rating for the address
        uint256 average = sum / ratings[_address].length;
        return average;
    }
    */
}