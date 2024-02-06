// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PAT_Signature {

    function getMessageHash(
        uint _tokenId,
        uint _quote
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_tokenId, _quote));
    }
    
    function getMessageHash(
        uint _tokenId,
        bytes32 _nonce
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_tokenId, _nonce));
    }

    function getEthSignedMessageHash(
        bytes32 _messageHash
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash)
            );
    }

    function verify(
        address _signer,
        uint _tokenId,
        uint _quote,
        bytes memory signature
    ) public pure returns (bool) {
        bytes32 messageHash = getMessageHash(_tokenId, _quote);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        return recoverSigner(ethSignedMessageHash, signature) == _signer;
    }

    function verify(
        address _signer,
        bytes32 _messageHash,
        bytes memory signature
    ) public pure returns (bool) {
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(_messageHash);

        return recoverSigner(ethSignedMessageHash, signature) == _signer;
    }

    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes memory _signature
    ) public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(
        bytes memory sig
    ) public pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }
        // implicitly return (r, s, v)
    }

    function generateRandomNonce(uint256 _tokenId) internal view returns (bytes32) {
        uint256 blockNumber = block.number;
        uint256 timestamp = block.timestamp;
        address sender = msg.sender;
        
        bytes32 nonce = keccak256(abi.encodePacked(_tokenId, blockNumber, timestamp, sender));
        
        return nonce;
    }
}
