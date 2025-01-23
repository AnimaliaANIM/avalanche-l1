// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./ERC721/ERC721MerkleMintSequential.sol";

contract AnimaliaTreasures is
    ERC721,
    ERC721Enumerable,
    ERC721Royalty,
    ERC721MerkleMintSequential,
    ReentrancyGuard,
    Ownable
{
    using SafeERC20 for IERC20;

    uint256 private _nextTokenId;

    string private _name;
    string private _symbol;
    string private baseURI;
    uint256 public maxSupply;

    event Received(address, uint256);

    error MaxSupplyReached();

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        uint256 _maxSupply,
        uint256 startSequentialTokenId,
        address defaultRoyaltyReceiver,
        uint96 defaultRoyaltyFeeNumerator
    ) ERC721(name_, symbol_) Ownable(_msgSender()) {
        _name = name_;
        _symbol = symbol_;
        baseURI = baseURI_;
        maxSupply = _maxSupply;
        _nextTokenId = startSequentialTokenId;
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

    function setMaxSupply(uint256 maxSupply_) external onlyOwner {
        maxSupply = maxSupply_;
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

    function setMintMerkleRoot(bytes32 merkleRoot) external onlyOwner {
        mintMerkleRoot = merkleRoot;
    }

    function _mintToken(address to) internal override {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
    }

    // owner mint tokenId
    function mintTokenId(address to, uint256 tokenId) external onlyOwner {
        _safeMint(to, tokenId);
    }

    // owner mint sequential
    function mint(address to) external onlyOwner {
        _mintToken(to);
    }

    // owner batch mint sequential
    function mintBatch(address to, uint8 amount) external onlyOwner {
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
        override(ERC721, ERC721Enumerable, ERC721Royalty)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
