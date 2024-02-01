// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// A contract for tokenizing physical tokens with three roles and feedback management 
contract TokenTokenWithRolesAndFeedback is ReentrancyGuard { 

    // Global variables
    uint256 internal maxSelectionTime = 1*1 days;
    uint256 internal maxServiceTime = 999*1 days;

    // A struct to store the details of each token 
    struct Token { 
        string  name;           // The name of the token 
        string  description;    // A brief description of the token 
        uint256 value;          // The value of the token in wei 
        uint256 WTquote;        // The binded amout for WT service
        uint256 timeValidity;   // This number define the custodial time service that start at the activation
        address originator;     // The address of the Vendor who started the tokenization process
        address warehouse;      // The address of the WarehouseTokenizator who custodies the token 
        address owner;          // The current owner of the Token
        bool    active;         // Whether the token is active or not 
    }

    // A struct to store the details of each registered Vendor
    struct Vendor {
        string name;
        string email;
        uint256 reputation;
        bool active;
    }

    // A struct to store the details of each registered WarehouseTokenizator
    struct WarehouseTokenizator {
        string name;
        string email;
        string latlon;
        uint256 reputation;
        bool active;
    }

    // A mapping from token struct to current owner address
    mapping (uint256 => address) public tokenOwner;

    // A mapping to link tokenId to the token creation block
    mapping(uint256 => uint256) public requestTime;

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

    // Mapping from address to an array of tokenId to track feedbacks
    mapping (address => uint256[]) public negativeFeedback;
    mapping (address => uint256[]) public positiveFeedback;

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

    event negativeFeedbackReleased(uint256 indexed _tokenId, address from, address to);
    event positiveFeedbackReleased(uint256 indexed _tokenId, address from, address to);

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
        require(
            tokens[_tokenId].active == true
            &&
            tokens[_tokenId].timeValidity  > block.timestamp,
             "This token is NOT active");
        _;
    }

    // A modifier to check if an token is NOT active
    modifier onlyUnactiveToken(uint256 _tokenId) {
        require(tokens[_tokenId].active == false, "This token is active");
        _;
    }

// PHASE-0: Registration

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
    function warehouseTokenizatorRegistration(
        string memory _name, 
        string memory _email,
        string memory _latlon
        ) public 
        returns (uint256) 
    {
        // Increment the token counter
        warehouseTokenizatorCounter++;

        // Create a new warehouseTokenizator struct activated by dafault
        WarehouseTokenizator memory newWarehouseTokenizator = WarehouseTokenizator({
            name: _name,
            email: _email,
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

// PHASE-1: Tokenization

    // A function to create a new token by a vendor
    function createToken(
        string memory _name, 
        string memory _description, 
        uint256 _value,
        uint256 _timeValidity) 
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
                timeValidity: _timeValidity,
                WTquote: 0,
                originator: msg.sender,
                warehouse: address(0),
                owner: msg.sender,
                active: false
            });

            // Store the token in the mapping
            tokens[tokenCounter] = newToken;

            requestTime[tokenCounter]= block.timestamp;

            // Emit an event
            emit TokenCreated(tokenCounter, _name, _description, _value, msg.sender);

            // Return the token ID
            return tokenCounter;
    }

    function WTselection (
        uint256 _tokenId, 
        bytes32 _messageHash, 
        bytes memory _signature, 
        address _WTaddress
        ) external payable
        onlyUnactiveToken(_tokenId) 
    {
            require(msg.value > 0, "Zero Ether is not allowed");
            require(tokens[_tokenId].originator == msg.sender, "You are not the originator");
            require(_messageHash == getEIP191SignedHash(_tokenId, msg.value), "Invalid message hash");
            require(verifySignature(_messageHash, _signature, _WTaddress), "Invalid signature");
            require(block.timestamp < requestTime[_tokenId]+maxSelectionTime);

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
            require(tokens[_tokenId].warehouse == msg.sender, "You are not the selected WarehouseTokenizator for this tokenId");
        
            // Make the token active
            tokens[_tokenId].owner          = tokens[_tokenId].originator;
            tokens[_tokenId].timeValidity   = block.timestamp + (tokens[_tokenId].timeValidity * 1 days);  // Days of validity
            tokens[_tokenId].active         = true;

            // set positive feedback to the originator
            setPositiveFeedback(_tokenId, tokens[_tokenId].originator);

            // Emit the token activation event
            emit TokenActivated(_tokenId, tokens[_tokenId].warehouse, tokens[_tokenId].owner);
    }

// PHASE-2 Trading

    // A function for the token owner to set a fixed selling price for their token
    function setTokenSellingPrice(
        uint256 _tokenId, 
        uint256 _sellingPrice
        ) external 
        onlyTokenOwner(_tokenId) 
        onlyActiveToken(_tokenId) 
    {
        // Set the selling price for the token
        tokenSellingPrice[_tokenId] = _sellingPrice;

        // Emit an event
        emit TokenSellingPriceSet(_tokenId, _sellingPrice);
    }

    // A function for a buyer to purchase a token at the fixed selling price
    function purchaseToken(
        uint256 _tokenId
        ) external payable nonReentrant
        onlyActiveToken(_tokenId) 
    {
        // Check if the token has a fixed selling price
        require(tokenSellingPrice[_tokenId] > 0, "Token does not have a fixed selling price.");

        // Check if the sent value matches the selling price
        require(msg.value == tokenSellingPrice[_tokenId], "Incorrect payment amount.");

        address _previousOwner = tokens[_tokenId].owner;

        // Transfer ownership of the token to the buyer
        tokens[_tokenId].owner = msg.sender;

        // Emit an event
        emit TokenTransferred(_tokenId, _previousOwner, tokens[_tokenId].owner);

        // Release the payment to the token owner as last operation
        payable(_previousOwner).transfer(msg.value);
    }

// PHASE-3 Redemption

    // Redemption request
    function redemptionRequest(
        uint256 _tokenId
        ) public 
        onlyTokenOwner(_tokenId) 
        onlyActiveToken(_tokenId) 
    {
            // To request the asset redemption, owner transfer the token ownership to the warehouse who holds the asset
            tokens[_tokenId].owner = tokens[_tokenId].warehouse;

            // aggiungere il tempo
            emit RedemptionRequested(_tokenId, tokens[_tokenId].warehouse);
    }

    // A function to disable an existing token
    function burnToken(
        uint256 _tokenId
        ) public nonReentrant
        onlyTokenWarehouse(_tokenId) 
        onlyActiveToken(_tokenId) 
        onlyTokenOwner(_tokenId)
    {
        
            // This action is only available when redemption has requested and warehouse provides proof of delivery
            require(tokens[_tokenId].owner == tokens[_tokenId].warehouse);
            require(tokens[_tokenId].warehouse == msg.sender);
            // Performs proof of delivery here

            // Release feedbacks
            setPositiveFeedback(_tokenId, msg.sender);

            // Unactivate the tokenId
            tokens[_tokenId].active = false;

            // Release the payment
            withdrawQuote(_tokenId);

            // Emit the release event
            emit TokenReleased(_tokenId, tokens[_tokenId].warehouse);
    }

// UTILITY FUNCTIONS

    // Function to withdraw the quote amount associated with a token
    function withdrawQuote(
        uint256 _tokenId
        ) internal
        onlyTokenWarehouse(_tokenId) 
        onlyUnactiveToken(_tokenId) 
        onlyTokenOwner(_tokenId) 
    {
        // Ensure that the token has a WarehouseTokenizator and a quote amount
        require(tokens[_tokenId].warehouse != address(0), "No WarehouseTokenizator selected for this token");
        require(tokens[_tokenId].WTquote > 0, "No quote amount available for withdrawal");

        // Store the quote amount in a variable
        uint256 quoteAmount = tokens[_tokenId].WTquote;

        // Reset the quote amount to zero to prevent re-entry attacks
        tokens[_tokenId].WTquote = 0;

        // Transfer the quote amount to the token owner (msg.sender)
        payable(msg.sender).transfer(quoteAmount);
    }


    // Function to release negative feedback.
    // This function can only be called from external because positive feedback release is a manual action
    function setNegativeFeedback(
        uint256 _tokenId
        ) external onlyActiveToken(_tokenId)
        returns (bool success)
    {
        // inserire un controllo che il richiedente è nella posizione di poter chiedere un feedback negativo
        // inserire le altre azioni (es. se trasferire quote al richiedente del feedback negativo e disabilitare il token)
       negativeFeedback[tokens[_tokenId].warehouse].push(_tokenId);
       // Disable the token
       tokens[_tokenId].active = false;
       
       emit negativeFeedbackReleased(_tokenId, msg.sender, tokens[_tokenId].warehouse);
       return true;
    }

    // Function to release positive feedback.
    // This function can not be called from external because positive feedback release is an automated action
    function setPositiveFeedback(
        uint256 _tokenId,
        address _to
        ) internal onlyActiveToken(_tokenId)
        returns (bool success)
    {
        require(tokens[_tokenId].warehouse == msg.sender || tokens[_tokenId].originator == msg.sender);
        
        positiveFeedback[_to].push(_tokenId);
       
        emit positiveFeedbackReleased(_tokenId, msg.sender, _to);
        return true;
    }

    function getNegativeFeedbacks(
        address _address
        ) external view 
        returns (uint[] memory) 
    {
        return negativeFeedback[_address];
    }

    function getPositiveFeedbacks(
        address _address
        ) external view 
        returns (uint[] memory) 
    {
        return positiveFeedback[_address];
    }

    // Function to get the EIP-191 signed hash of the concatenation of the two parameters _tokenId+quote
    function getEIP191SignedHash(
        uint256 _tokenId, 
        uint256 quote
        ) public pure 
        returns (bytes32) 
    {
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
    function verifySignature(
        bytes32 _messageHash, 
        bytes memory _signature, 
        address _signer
        ) public pure 
        returns (bool) 
    {
        // Recovering the public key from the signature
        address recoveredAddress = recoverSigner(_messageHash, _signature);

        // Verifying if the recovered address matches the expected signer
        return recoveredAddress == _signer;
    }

    // Internal function to recover the signer's address from a message hash and signature
    function recoverSigner(
        bytes32 _messageHash, 
        bytes memory _signature
        ) internal pure 
        returns (address) 
    {
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

    // Fallback function to avoid directly receiving payment, so when payable function are not called
    fallback() 
    external 
    {
        revert("This contract does not accept Ether transactions.");
    }
}