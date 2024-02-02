// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./PAT_Roles.sol";
import "./PAT_Feedback.sol";
import "./PAT_Signature.sol";

contract PhysicalAssetTokenization is ReentrancyGuard, PAT_Roles, PAT_Feedback,  PAT_Signature {

    // Global variables
    uint256 internal maxSelectionTime  = 1 *1 days;
    uint256 internal maxActivationTime = 10*1 days;
    uint256 internal maxRedemptionTime = 10*1 days;

    // A struct to store the details of each token 
    struct Token { 
        string  name;           // The name of the token 
        string  description;    // A brief description of the token 
        uint256 initialValue;   // The value of the token in wei at creation time 
        uint256 WTquote;        // The binded amout for WT service
        uint256 timeValidity;   // This number define the custodial time service that start at the activation
        uint256 state;          // The status tracking of the token: 0-Unactive; 1-Activated; 2-OnRedemption; 3-Burned 
        address originator;     // The address of the Vendor who started the tokenization process
        address warehouse;      // The address of the WarehouseTokenizator who custodies the token 
        address owner;          // The current owner of the Token
    }

    // A mapping from token struct to current owner address
    mapping (uint256 => address) public tokenOwner;

    // A mapping to link tokenId to the token creation block
    mapping(uint256 => uint256) public requestTime;

    // A mapping from token ID to token struct
    mapping (uint256 => Token) public tokens;

    // A mapping from address to an array of ratings
    mapping (address => uint256[]) public ratings;

    // A mapping from token ID to fixed selling price
    mapping (uint256 => uint256) public tokenSellingPrice;

    // A counter for generating token IDs
    uint256 public tokenCounter=0;

    // An event to emit when an token is created by a vendor
    event TokenCreated(uint256 indexed tokenId, string name, string description, uint256 value, address owner);

    event WTselected(uint256 _tokenID, address _WTaddress, uint256 _WTquote);

    // An event to emit when a token is activated by a WarehouseTokenizator before activation time limit
    event TokenActivated(uint256 indexed tokenId, address WarehouseTokenizator, address owner);

    // An evento to emit when a token request is aborder prior of activation and after activation time limit
    event requestAborted(uint256 indexed tokenId, address originator, uint256 refundQuote);

    // An event to emit when a token is transferred by a trader
    event TokenTransferred(uint256 indexed tokenId, address from, address to);

    event RedemptionRequested(uint256 indexed _tokenId, address warehouse);

    // An event to emit when an token is released by a WarehouseTokenizator
    event TokenReleased(uint256 indexed tokenId, address warehouse);

    // An event to emit when a token is burned by a trader
    event TokenBurned(uint256 indexed tokenId);

    // An event to emit when the selling price is set for a token
    event TokenPriceSet(uint256 indexed tokenId, uint256 sellingPrice);

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
            tokens[_tokenId].state == 1
            &&
            tokens[_tokenId].timeValidity  > block.timestamp,
             "This token is NOT active");
        _;
    }

    // A modifier to check if an token is NOT active
    modifier onlyUnactiveToken(uint256 _tokenId) {
        require(tokens[_tokenId].state != 1, "This token is active");
        _;
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
                initialValue: _value,
                timeValidity: _timeValidity,
                WTquote: 0,
                originator: msg.sender,
                warehouse: address(0),
                owner: msg.sender,
                state: 0
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
            require(tokens[_tokenId].state == 0, "Token is not waiting for activation");
            require(tokens[_tokenId].originator == msg.sender, "You are not the originator");
            require(warehouseTokenizators[_WTaddress].active == true);
            //require(_messageHash == getEIP191SignedHash(_tokenId, msg.value), "Invalid message hash");
            require(_messageHash == getMessageHash(_tokenId, msg.value), "Invalid message hash");
            //require(verifySignature(_messageHash, _signature, _WTaddress), "Invalid signature");
            require(verify(_WTaddress, _tokenId, msg.value, _signature), "Invalid signature");
            require(block.timestamp < (requestTime[_tokenId] + maxSelectionTime));

            // Reset requestTime with the current  bloc.timestamp as start reference for activation time
            requestTime[_tokenId]=block.timestamp;

            // Set Warehouse and WTquote to this _tokenId
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
            require(block.timestamp < requestTime[_tokenId]+maxActivationTime, "You are out of time for activation");
        
            // Make the token active
            tokens[_tokenId].owner          = tokens[_tokenId].originator;
            tokens[_tokenId].timeValidity   = block.timestamp + (tokens[_tokenId].timeValidity * 1 days);  // Days of validity
            tokens[_tokenId].state          = 1;

            // set positive feedback to the originator
            _setPositiveFeedback(_tokenId, tokens[_tokenId].originator);

            // Emit the token activation event
            emit TokenActivated(_tokenId, tokens[_tokenId].warehouse, tokens[_tokenId].owner);
    }

    function abortRequest(
        uint256 _tokenId
        ) external
        onlyUnactiveToken(_tokenId)
    {
        require(msg.sender == tokens[_tokenId].originator);
        require(tokens[_tokenId].WTquote > 0);
        require(block.timestamp > requestTime[_tokenId]+maxActivationTime, "You are still in of time for activation");

        // Reset warehouse address
        tokens[_tokenId].warehouse  = address(0);

        // Store the quote amount in a variable
        uint256 quoteAmount = tokens[_tokenId].WTquote;

        // Reset the quote amount to zero to prevent re-entry attacks
        tokens[_tokenId].WTquote = 0;

        negativeFeedback[tokens[_tokenId].originator].push(_tokenId);

        // Transfer the quote amount to the originator (msg.sender)
        payable(msg.sender).transfer(quoteAmount);

        // Emit an event to alert that _tokenId request has been aborted
        emit requestAborted(_tokenId, msg.sender, quoteAmount);
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
        emit TokenPriceSet(_tokenId, _sellingPrice);
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
        ) external 
        onlyTokenOwner(_tokenId) 
        onlyActiveToken(_tokenId) 
    {
            //tokens[_tokenId].owner = address(0);
            tokens[_tokenId].state = 2;

            // reset redemption countdown
            requestTime[_tokenId]=block.timestamp;

            emit RedemptionRequested(_tokenId, tokens[_tokenId].warehouse);
    }

    // A function to burn a token by warehouse in case of proof of delivery
    function burnToken(
        uint256 _tokenId,
        bytes32 _messageHash, 
        bytes memory _signature
        ) public nonReentrant
    {
            // This action is only available when redemption has requested and warehouse provides proof of delivery
            //require(tokens[_tokenId].owner == address(0));
            require(tokens[_tokenId].state == 2);
            require(tokens[_tokenId].warehouse == msg.sender);
            
            // PROOF OF DELIVERY is a message "1" signed by token owner
            require(_messageHash == getMessageHash(_tokenId, 1), "Invalid message hash");
            require(verify(tokens[_tokenId].owner, _tokenId, 1, _signature), "Invalid signature");
            
            tokens[_tokenId].owner = address(0);
            // Set token state as burned
            tokens[_tokenId].state = 3;

            // Release feedbacks
            setPositiveFeedback(_tokenId);

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
        onlyUnactiveToken(_tokenId) 
    {
        // Ensure that the token has a WarehouseTokenizator and a quote amount
        require(tokens[_tokenId].warehouse != address(0), "No WarehouseTokenizator for this token");
        require(tokens[_tokenId].WTquote > 0, "No amount to withdrawal");
        require(msg.sender == tokens[_tokenId].warehouse || msg.sender == tokens[_tokenId].warehouse);

        // Store the quote amount in a variable
        uint256 quoteAmount = tokens[_tokenId].WTquote;

        // Reset the quote amount to zero to prevent re-entry attacks
        tokens[_tokenId].WTquote = 0;

        // Burn the token
        tokens[_tokenId].state = 3;

        // Transfer the quote amount to the token owner (msg.sender)
        payable(msg.sender).transfer(quoteAmount);
    }

    // External since negative feedback are manual only
    function setNegativeFeedbackByOriginator(
        uint256 _tokenId
        ) external
        returns (bool success)
    {
        require(msg.sender == tokens[_tokenId].originator);
        require(tokens[_tokenId].WTquote > 0);
        require(tokens[_tokenId].state == 0);
        require(block.timestamp > requestTime[_tokenId]+maxActivationTime, "Still in time for activation");
        
        // ATTENZIONE:Bisogna distinguere questo feedback da quello di un asset non consegnato
        _setNegativeFeedback(_tokenId, tokens[_tokenId].warehouse);

       // Disable the token
       tokens[_tokenId].state = 3;

       withdrawQuote(_tokenId);

       return true;
    }

    // External since negative feedback are manual only
    function setNegativeFeedbackByOwner(
        uint256 _tokenId
        ) external
        returns (bool success)
    {
        require(tokens[_tokenId].owner == msg.sender);
        require(tokens[_tokenId].state == 2);
        require(block.timestamp > requestTime[_tokenId]+maxRedemptionTime, "Redemption time has not expired");

       // Disable the token
       tokens[_tokenId].state = 3;

       _setNegativeFeedback(_tokenId, tokens[_tokenId].warehouse);

       withdrawQuote(_tokenId);
       
       return true;
    }

    // Internal since positive feedback are automated only
    function setPositiveFeedback(
        uint256 _tokenId
        ) internal
        returns (bool success)
    {
        require(tokens[_tokenId].state==3);
        require(tokens[_tokenId].warehouse == msg.sender);

        return _setPositiveFeedback(_tokenId, msg.sender);
    }

    // Fallback function to avoid directly receiving payment, so when payable function are not called
    fallback() 
    external 
    {
        revert("This contract does not accept Ether transactions.");
    }
}