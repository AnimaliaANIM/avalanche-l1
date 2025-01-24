// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract AnimaliaCardSkins is
    ERC1155,
    EIP712,
    AccessControl,
    ERC1155Burnable,
    ERC1155Supply,
    ReentrancyGuard,
    ERC2981
{
    using SafeERC20 for IERC20;

    bytes32 private constant PERMIT_TYPEHASH =
        keccak256(
            "MintPermit(address signer,address minter,uint256[] ids,uint256[] amounts,uint256 nonce,uint256 deadline)"
        );
    mapping(address => mapping(address => uint256)) private _nonces;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    error ERC2612ExpiredSignature(uint256 deadline);

    error ERC2612InvalidSigner(address recoveredSigner, address signer);

    error ForbiddenSigner(address signer);

    constructor(
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        string memory uri_
    ) ERC1155(uri_) EIP712("AnimaliaCardSkins", "1") {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(OPERATOR_ROLE, _msgSender());
        _setDefaultRoyalty(royaltyReceiver, royaltyFeeNumerator);
    }

    function setURI(string memory uri_) external onlyRole(OPERATOR_ROLE) {
        _setURI(uri_);
    }

    function setDefaultRoyalty(
        address receiver,
        uint96 feeNumerator
    ) external onlyRole(OPERATOR_ROLE) {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) external onlyRole(OPERATOR_ROLE) {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    // single mint
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external onlyRole(OPERATOR_ROLE) {
        _mint(to, id, amount, data);
    }

    // batch mint
    function mint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyRole(OPERATOR_ROLE) {
        _mintBatch(to, ids, amounts, data);
    }

    function _verifyPermit(
        address signer,
        address minter,
        uint256[] memory ids,
        uint256[] memory amounts,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        if (block.timestamp > deadline) {
            revert ERC2612ExpiredSignature(deadline);
        }

        uint256 nonce = _useNonce(signer, minter);

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                signer,
                minter,
                ids,
                amounts,
                nonce,
                deadline
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);

        address recoveredSigner = ECDSA.recover(hash, v, r, s);
        if (recoveredSigner != signer) {
            revert ERC2612InvalidSigner(recoveredSigner, signer);
        }
    }

    function mint(
        address signer,
        address minter,
        uint256 id,
        uint256 amount,
        bytes memory data,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = id;
        amounts[0] = amount;
        _verifyPermit(signer, minter, ids, amounts, deadline, v, r, s);

        if (!hasRole(OPERATOR_ROLE, signer)) {
            revert ForbiddenSigner(signer);
        }

        _mint(minter, id, amount, data);
    }

    function mint(
        address signer,
        address minter,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        _verifyPermit(signer, minter, ids, amounts, deadline, v, r, s);

        if (!hasRole(OPERATOR_ROLE, signer)) {
            revert ForbiddenSigner(signer);
        }

        _mintBatch(minter, ids, amounts, data);
    }

    function nonces(
        address signer,
        address account
    ) external view returns (uint256) {
        return _nonces[signer][account];
    }

    function _useNonce(
        address signer,
        address account
    ) internal returns (uint256 current) {
        unchecked {
            return _nonces[signer][account]++;
        }
    }

    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return _domainSeparatorV4();
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
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155, ERC1155Supply) {
        super._update(from, to, ids, values);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155, AccessControl, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
