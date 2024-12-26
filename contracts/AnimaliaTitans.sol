// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

contract AnimaliaTitans is
    ERC721,
    ERC721Enumerable,
    ERC721Royalty,
    ReentrancyGuard,
    Ownable
{
    using SafeERC20 for IERC20;
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    uint256 private _nextTokenId;

    string private _name;
    string private _symbol;
    string private baseURI;

    bytes32 public claimMerkleRoot;

    EnumerableMap.UintToAddressMap private claimed;

    event Received(address, uint256);

    error InvalidMerkleProof();
    error TokenAlreadyMinted(uint256 tokenId);

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        address defaultRoyaltyReceiver,
        uint96 defaultRoyaltyFeeNumerator
    ) ERC721(name_, symbol_) Ownable(_msgSender()) {
        _name = name_;
        _symbol = symbol_;
        baseURI = baseURI_;
        _setDefaultRoyalty(defaultRoyaltyReceiver, defaultRoyaltyFeeNumerator);
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setName(string memory name_) external onlyOwner {
        _name = name_;
    }

    function setSymbol(string memory symbol_) external onlyOwner {
        _symbol = symbol_;
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        baseURI = baseURI_;
    }

    function setRoyaltyInfo(
        address receiver,
        uint96 feeNumerator
    ) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function deleteDefaultRoyalty() external onlyOwner {
        _deleteDefaultRoyalty();
    }

    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) external onlyOwner {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    function resetTokenRoyalty(uint256 tokenId) external onlyOwner {
        _resetTokenRoyalty(tokenId);
    }

    function setClaimMerkleRoot(bytes32 merkleRoot) external onlyOwner {
        claimMerkleRoot = merkleRoot;
    }

    function _mintToken(address to) internal {
        uint256 tokenId = ++_nextTokenId;
        _safeMint(to, tokenId);
    }

    // mint tokenId
    function mint(address to, uint256 tokenId) external onlyOwner {
        _safeMint(to, tokenId);
    }

    // only single mint
    function mint(address to) external onlyOwner {
        _mintToken(to);
    }

    // only batch mint
    function mint(address to, uint8 amount) external onlyOwner {
        for (uint8 i = 0; i < amount; i++) {
            _mintToken(to);
        }
    }

    // merkle single claim
    function mint(
        bytes32[] calldata claimMerkleProof,
        uint256 tokenId
    ) external nonReentrant {
        // bytes32 leaf = keccak256(abi.encodePacked(_msgSender(), tokenId));
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(tokenId, _msgSender())))
        );
        if (!MerkleProof.verify(claimMerkleProof, claimMerkleRoot, leaf)) {
            revert InvalidMerkleProof();
        }

        if (_ownerOf(tokenId) != address(0)) {
            revert TokenAlreadyMinted(tokenId);
        }

        _safeMint(_msgSender(), tokenId);
        claimed.set(tokenId, _msgSender());
    }

    // merkle batch claim
    function mint(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        uint256[] calldata tokenIds
    ) external nonReentrant {
        bytes32[] memory _leaves = new bytes32[](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            _leaves[i] = keccak256(
                bytes.concat(keccak256(abi.encode(tokenIds[i], _msgSender())))
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
            revert InvalidMerkleProof();
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
    ) public view returns (uint256[] memory tokenIds) {
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

    function recover(
        uint256 amount,
        address recipient
    ) external payable onlyOwner {
        Address.sendValue(payable(recipient), amount);
    }

    function recover(
        address tokenAddress,
        uint256 amount,
        address recipient
    ) external onlyOwner {
        IERC20(tokenAddress).safeTransfer(recipient, amount);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(
        address account,
        uint128 value
    ) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721, ERC721Enumerable, ERC721Royalty)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
