// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PAT_Roles.sol";

contract PAT_Feedback is PAT_Roles {

    // Mapping from address to an array of tokenId to track feedbacks
    mapping(address => uint256[]) public negativeFeedback;
    mapping(address => uint256[]) public positiveFeedback;

    // An event to emit when a rating is given by a participant
    event RatingGiven(address from, address to, uint256 rating);

    event negativeFeedbackReleased(uint256 indexed _tokenId, address from, address to);
    event positiveFeedbackReleased(uint256 indexed _tokenId, address from, address to);

    // Internal function to release negative feedback.
    function _setNegativeFeedback(uint256 _tokenId, address _warehouseAddress)
        internal
        returns (bool success)
    {
        negativeFeedback[_warehouseAddress].push(_tokenId);

        emit negativeFeedbackReleased(_tokenId, msg.sender, _warehouseAddress);
        return true;
    }

    // Function to release positive feedback.
    // This function can not be called from external because positive feedback release is an automated action
    function _setPositiveFeedback(uint256 _tokenId, address _to)
        internal
        returns (bool success)
    {
        positiveFeedback[_to].push(_tokenId);

        emit positiveFeedbackReleased(_tokenId, msg.sender, _to);
        return true;
    }
}
