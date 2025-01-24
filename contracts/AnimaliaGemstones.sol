// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./ERC721/ERC721MerkleMintSequential.sol";

contract AnimaliaGemstones is
    ERC721,
    ERC721Enumerable,
    ERC721Royalty,
    ERC721MerkleMintSequential,
    ReentrancyGuard,
    AccessControl
{
    using SafeERC20 for IERC20;

    uint256 private _nextTokenId;

    string private _name;
    string private _symbol;
    string private baseURI;
    uint256 public maxSupply;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    error MaxSupplyReached();

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        uint256 _maxSupply,
        uint256 startSequentialTokenId,
        address defaultRoyaltyReceiver,
        uint96 defaultRoyaltyFeeNumerator
    ) ERC721(name_, symbol_) {
        _name = name_;
        _symbol = symbol_;
        baseURI = baseURI_;
        maxSupply = _maxSupply;
        _nextTokenId = startSequentialTokenId;
        _setDefaultRoyalty(defaultRoyaltyReceiver, defaultRoyaltyFeeNumerator);

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MINTER_ROLE, _msgSender());
        _grantRole(OPERATOR_ROLE, _msgSender());
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

    function setName(string memory name_) external onlyRole(OPERATOR_ROLE) {
        _name = name_;
    }

    function setSymbol(string memory symbol_) external onlyRole(OPERATOR_ROLE) {
        _symbol = symbol_;
    }

    function setBaseURI(
        string memory baseURI_
    ) external onlyRole(OPERATOR_ROLE) {
        baseURI = baseURI_;
    }

    function setMaxSupply(uint256 maxSupply_) external onlyRole(OPERATOR_ROLE) {
        maxSupply = maxSupply_;
    }

    function setRoyaltyInfo(
        address receiver,
        uint96 feeNumerator
    ) external onlyRole(OPERATOR_ROLE) {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function deleteDefaultRoyalty() external onlyRole(OPERATOR_ROLE) {
        _deleteDefaultRoyalty();
    }

    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) external onlyRole(OPERATOR_ROLE) {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    function resetTokenRoyalty(
        uint256 tokenId
    ) external onlyRole(OPERATOR_ROLE) {
        _resetTokenRoyalty(tokenId);
    }

    function setMintMerkleRoot(
        bytes32 merkleRoot
    ) external onlyRole(OPERATOR_ROLE) {
        mintMerkleRoot = merkleRoot;
    }

    function _mintToken(address to) internal override {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
    }

    // mint tokenId
    function mint(
        address to,
        uint256 tokenId
    ) external onlyRole(OPERATOR_ROLE) {
        _safeMint(to, tokenId);
    }

    // mint sequential
    function mint(address to) external onlyRole(MINTER_ROLE) {
        _mintToken(to);
    }

    // batch mint sequential
    function mint(address to, uint8 amount) external onlyRole(MINTER_ROLE) {
        for (uint8 i = 0; i < amount; i++) {
            _mintToken(to);
        }
    }

    function mint(
        bytes32[] calldata proof,
        uint256 quota,
        uint256 amount
    ) external nonReentrant {
        _merkleMint(proof, quota, amount);
    }

    function recover(
        address tokenAddress,
        uint256 amount,
        address recipient
    ) external onlyRole(OPERATOR_ROLE) {
        IERC20(tokenAddress).safeTransfer(recipient, amount);
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        override(ERC721, ERC721Enumerable)
        returns (address previousOwner)
    {
        previousOwner = super._update(to, tokenId, auth);
        if (totalSupply() > maxSupply) {
            revert MaxSupplyReached();
        }
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
        override(ERC721, ERC721Enumerable, ERC721Royalty, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
