// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

abstract contract ERC721MerkleClaim is ERC721 {
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    bytes32 public claimMerkleRoot;

    EnumerableMap.UintToAddressMap private claimed;

    error InvalidClaimMerkleProof();
    error TokenAlreadyMinted(uint256 tokenId);

    // merkle claim tokenId
    function _merkleClaim(
        bytes32[] calldata proof,
        uint256 tokenId
    ) internal virtual {
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(_msgSender(), tokenId)))
        );
        if (!MerkleProof.verify(proof, claimMerkleRoot, leaf)) {
            revert InvalidClaimMerkleProof();
        }

        if (_ownerOf(tokenId) != address(0)) {
            revert TokenAlreadyMinted(tokenId);
        }

        _safeMint(_msgSender(), tokenId);
        claimed.set(tokenId, _msgSender());
    }

    // merkle batch claim tokenId
    function _merkleClaimBatch(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        uint256[] calldata tokenIds
    ) internal virtual {
        bytes32[] memory _leaves = new bytes32[](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            _leaves[i] = keccak256(
                bytes.concat(keccak256(abi.encode(_msgSender(), tokenIds[i])))
            );
        }

        if (
            !MerkleProof.multiProofVerify(
                proof,
                proofFlags,
                claimMerkleRoot,
                _leaves
            )
        ) {
            revert InvalidClaimMerkleProof();
        }

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (_ownerOf(tokenIds[i]) != address(0)) {
                revert TokenAlreadyMinted(tokenIds[i]);
            }

            _safeMint(_msgSender(), tokenIds[i]);
            claimed.set(tokenIds[i], _msgSender());
        }
    }

    function tokensClaimedByOwner(
        address queryOwner
    ) public view virtual returns (uint256[] memory tokenIds) {
        uint256[] memory tokenIdsClaimed = claimed.keys();
        uint256 size = 0;
        for (uint256 i = 0; i < tokenIdsClaimed.length; i++) {
            if (claimed.get(tokenIdsClaimed[i]) == queryOwner) {
                size++;
            }
        }

        tokenIds = new uint256[](size);
        uint256 j = 0;
        for (uint256 i = 0; i < tokenIdsClaimed.length; i++) {
            if (claimed.get(tokenIdsClaimed[i]) == queryOwner) {
                tokenIds[j] = tokenIdsClaimed[i];
                j++;
            }
        }
    }
}
