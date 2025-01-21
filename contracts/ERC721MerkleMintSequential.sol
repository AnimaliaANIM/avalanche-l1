// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

abstract contract ERC721MerkleMintSequential is ERC721 {
    uint256 private _nextTokenId;

    bytes32 public mintMerkleRoot;

    mapping(bytes32 mintMerkleRoot => mapping(address minter => uint256 count))
        public tokensMinted;

    error InvalidMintMerkleProof();
    error MintAmountExceedLimit(uint256 limit);

    function _mintToken(address to) internal virtual {
        uint256 tokenId = ++_nextTokenId;
        _safeMint(to, tokenId);
    }

    // merkle mint
    function _merkleMint(
        bytes32[] calldata proof,
        uint256 quota,
        uint256 amount
    ) internal virtual {
        // bytes32 leaf = keccak256(abi.encodePacked(_msgSender(), quota));
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(_msgSender(), quota)))
        );
        if (!MerkleProof.verify(proof, mintMerkleRoot, leaf)) {
            revert InvalidMintMerkleProof();
        }

        tokensMinted[mintMerkleRoot][_msgSender()] += amount;

        if (tokensMinted[mintMerkleRoot][_msgSender()] > quota) {
            revert MintAmountExceedLimit(quota);
        }

        for (uint256 i = 0; i < amount; i++) {
            _mintToken(_msgSender());
        }
    }
}
