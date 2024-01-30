// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// A contract for tokenizing physical tokens with three roles and feedback management 
contract TokenTokenWithRolesAndFeedback { 

    // A struct to store the details of each token 
    struct Token { 
        string  name;           // The name of the token 
        string  description;    // A brief description of the token 
        uint256 value;          // The value of the token in wei 
        uint256 WTquote;        // The binded amout for WT service
        address originator;     // The address of the Vendor who started the tokenization
        address warehouse;      // The address of the WarehouseTokenizator who custodies the token 
        address owner;          // The current owner of the Token
        bool    active;         // Whether the token is active or not 
    }

    struct Vendor {
        string name;
        string email;
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

    // A mapping from token ID to fixed selling price
    mapping (uint256 => uint256) public tokenSellingPrice;

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

    event WTselected(uint256 _tokenID, address _WTaddress, uint256 _WTquote);

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

    // An event to emit when the selling price is set for a token
    event TokenSellingPriceSet(uint256 indexed tokenId, uint256 sellingPrice);

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
        require(tokens[_tokenId].active == true, "This token is NOT active");
        _;
    }

    // A modifier to check if an token is NOT active
    modifier onlyUnactiveToken(uint256 _tokenId) {
        require(tokens[_tokenId].active == false, "This token is active");
        _;
    }

    // A function to register and activate a new vendor
    function vendorRegistration(string memory _name, string memory _email) public returns (uint256) {
        // Increment the vendor counter
        vendorCounter++;

        // Create a new vendor struct activated by dafault
        Vendor memory newVendor = Vendor({
            name: _name,
            email: _email,
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
    function createToken(
        string memory _name, 
        string memory _description, 
        uint256 _value) 
        public 
        onlyVendor() 
        returns (uint256) 
        {
            // Increment the token counter
            tokenCounter++;

            // Create a new token struct with the vendor as the owner and no warehouse assigned yet
            Token memory newToken = Token({
                name: _name,
                description: _description,
                value: _value,
                WTquote: 0,
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

    // Function to get the EIP-191 signed hash of the concatenation of the two parameters
    function getEIP191SignedHash(uint256 _tokenId, uint256 quote) public pure returns (bytes32) {
        // Creating the message string with the EIP-191 prefix
        string memory message = string(abi.encodePacked("\x19Ethereum Signed Message:\n32", _tokenId, quote));

        // Hashing the message string
        bytes32 messageHash = keccak256(abi.encodePacked(message));

        // Returning the hashed message and the address of the caller
        return messageHash;
    }

    // Function to verify the signature
    // _signature parameter have to be calculated off-line,
    // like on front-end through web3.eth.sign(messageHash, signerAddress) 
    function verifySignature(bytes32 _messageHash, bytes memory _signature, address _signer) public pure returns (bool) {
        // Recovering the public key from the signature
        address recoveredAddress = recoverSigner(_messageHash, _signature);

        // Verifying if the recovered address matches the expected signer
        return recoveredAddress == _signer;
    }

    // Internal function to recover the signer's address from a message hash and signature
    function recoverSigner(bytes32 _messageHash, bytes memory _signature) internal pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;

        // Extracting the components of the signature
        assembly {
            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := byte(0, mload(add(_signature, 96)))
        }

        // Adjusting the value of v (EIP-155)
        if (v < 27) {
            v += 27;
        }

        // Recovering the public key from the signature
        return ecrecover(_messageHash, v, r, s);
    }

    function WTselection (
        uint256 _tokenId, 
        bytes32 _messageHash, 
        bytes memory _signature, 
        address _WTaddress
        ) external payable
        onlyWarehouseTokenizator()
        onlyUnactiveToken(_tokenId) 
        {
            require(_messageHash == getEIP191SignedHash(_tokenId, msg.value));
            require(verifySignature(_messageHash, _signature, _WTaddress));

            tokens[_tokenId].warehouse  = _WTaddress;
            tokens[_tokenId].WTquote    = msg.value;

            // Emit WT seleted event to notify wich WT is binded and unbind the other WT
            emit WTselected(_tokenId, _WTaddress, msg.value);
    }

    // A function to activate an existing token by a WarehouseTokenizator
    // this function must be called by WT when pysical asset is received and checked
    function activateToken(
        uint256 _tokenId
        ) external 
        onlyWarehouseTokenizator()
        onlyUnactiveToken(_tokenId)
        {
            require(tokens[_tokenId].warehouse == msg.sender);
        
            // Make the token active
            tokens[_tokenId].owner = tokens[_tokenId].originator;
            tokens[_tokenId].active = true;

            // Emit the token activation event
            emit TokenActivated(_tokenId, tokens[_tokenId].warehouse, tokens[_tokenId].owner);
    }
    
    // A function for the token owner to set a fixed selling price for their token
    function setTokenSellingPrice(uint256 _tokenId, uint256 _sellingPrice) external onlyTokenOwner(_tokenId) onlyActiveToken(_tokenId) {
        // Set the selling price for the token
        tokenSellingPrice[_tokenId] = _sellingPrice;

        // Emit an event
        emit TokenSellingPriceSet(_tokenId, _sellingPrice);
    }

    // A function for a buyer to purchase a token at the fixed selling price
    function purchaseToken(uint256 _tokenId) external payable onlyActiveToken(_tokenId) {
        // Check if the token has a fixed selling price
        require(tokenSellingPrice[_tokenId] > 0, "Token does not have a fixed selling price.");

        // Check if the sent value matches the selling price
        require(msg.value == tokenSellingPrice[_tokenId], "Incorrect payment amount.");

        address _previousOwner = tokens[_tokenId].owner;

        // Release the payment to the token owner
        payable(_previousOwner).transfer(msg.value);

        // Transfer ownership of the token to the buyer
        tokens[_tokenId].owner = msg.sender;

        // Emit an event
        emit TokenTransferred(_tokenId, _previousOwner, tokens[_tokenId].owner);
    }

    // Redemption request
    function redemptionRequest(
        uint256 _tokenId
        ) public 
        onlyTokenOwner(_tokenId) 
        {
            // To request the asset redemption, owner transfer the token ownership to the warehouse who holds the asset
            tokens[_tokenId].owner = tokens[_tokenId].warehouse;

            // aggiungere il tempo
            emit RedemptionRequested(_tokenId, tokens[_tokenId].warehouse);
    }

    // A function to disable an existing token
    function burnToken(
        uint256 _tokenId
        ) public 
        onlyTokenWarehouse(_tokenId) 
        onlyActiveToken(_tokenId) 
        onlyTokenOwner(_tokenId)
        {
        
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
}