// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AnimaliaGenesisArcanaV1 is
    ERC721,
    ERC721Enumerable,
    ERC721Royalty,
    Ownable,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    uint256 private _nextTokenId;

    string private _name;
    string private _symbol;
    string private baseURI;

    bytes32 public claimMerkleRoot;
    bytes32 public mintMerkleRoot;

    mapping(bytes32 mintMerkleRoot => mapping(address minter => uint256 count)) merkleMintCount;

    uint8 public constant MAX_MINT_PER_BLOCK = 150;

    modifier canMint(uint256 mintAmount) {
        if (mintAmount <= 0) {
            revert InvalidMintAmount(mintAmount);
        }
        if (mintAmount > MAX_MINT_PER_BLOCK) {
            revert MintAmountExceedLimit(MAX_MINT_PER_BLOCK);
        }
        _;
    }

    event Received(address, uint256);

    error InvalidMintAmount(uint256 mintAmount);
    error MintAmountExceedLimit(uint256 limit);
    error TokenAlreadyMinted(uint256 tokenId);
    error InvalidMerkleProof();

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        address defaultRoyaltyReceiver,
        uint96 defaultRoyaltyFeeNumerator
    ) ERC721("", "") Ownable(_msgSender()) {
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

    // owner batch mint
    function mint(
        address to,
        uint8 amount
    ) external nonReentrant onlyOwner canMint(amount) {
        for (uint8 i = 0; i < amount; i++) {
            _mintToken(to);
        }
    }

    // claim tokenId
    function mint(
        bytes32[] calldata claimMerkleProof,
        uint256[] calldata tokenIds
    ) external nonReentrant canMint(tokenIds.length) {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (
                !MerkleProof.verify(
                    claimMerkleProof,
                    claimMerkleRoot,
                    keccak256(abi.encodePacked(_msgSender(), tokenIds[i]))
                )
            ) {
                revert InvalidMerkleProof();
            }

            if (_ownerOf(tokenIds[i]) != address(0)) {
                revert TokenAlreadyMinted(tokenIds[i]);
            }

            _safeMint(_msgSender(), tokenIds[i]);
        }
    }

    // merkle mint
    function mint(
        bytes32[] calldata mintMerkleProof,
        uint256 quota,
        uint256 amount
    ) external nonReentrant canMint(amount) {
        if (
            !MerkleProof.verify(
                mintMerkleProof,
                mintMerkleRoot,
                keccak256(abi.encodePacked(_msgSender(), quota))
            )
        ) {
            revert InvalidMerkleProof();
        }

        if (merkleMintCount[mintMerkleRoot][_msgSender()] + amount > quota) {
            revert MintAmountExceedLimit(quota);
        }

        for (uint256 i = 0; i < amount; i++) {
            _mintToken(_msgSender());
        }
    }

    function recover(
        uint256 amount,
        address recipient
    ) external payable onlyOwner {
        Address.sendValue(payable(recipient), amount);
    }

    function recoverERC20(
        address tokenAddress_,
        uint256 amount,
        address recipient
    ) external onlyOwner {
        IERC20(tokenAddress_).safeTransfer(recipient, amount);
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
