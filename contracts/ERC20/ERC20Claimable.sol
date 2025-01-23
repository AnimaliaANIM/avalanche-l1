// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "./IERC20Claimable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

abstract contract ERC20Claimable is ERC20, IERC20Claimable, EIP712 {
    mapping(address owner => mapping(address receiver => uint256))
        private _nonces;

    bytes32 private constant CLAIM_TYPEHASH =
        keccak256(
            "Claim(address owner,address receiver,uint256 value,uint256 nonce,uint256 deadline)"
        );

    /**
     * @dev Permit deadline has expired.
     */
    error ERC2612ExpiredSignature(uint256 deadline);

    /**
     * @dev Mismatched signature.
     */
    error ERC2612InvalidSigner(address signer, address owner);

    /**
     * @dev Initializes the {EIP712} domain separator using the `name` parameter, and setting `version` to `"1"`.
     *
     * It's a good idea to use the same `name` that is defined as the ERC20 token name.
     */
    constructor(string memory name) EIP712(name, "1") {}

    /**
     * @dev See {IERC20Claimable-claim}.
     */
    function claim(
        address owner,
        address receiver,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override {
        if (block.timestamp > deadline) {
            revert ERC2612ExpiredSignature(deadline);
        }

        bytes32 structHash = keccak256(
            abi.encode(
                CLAIM_TYPEHASH,
                owner,
                receiver,
                value,
                _useNonce(owner, receiver),
                deadline
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, v, r, s);
        if (signer != owner) {
            revert ERC2612InvalidSigner(signer, owner);
        }

        _transfer(owner, receiver, value);
    }

    /**
     * @dev See {IERC20Claimable-nonces}.
     */
    function nonces(
        address owner,
        address receiver
    ) public view virtual returns (uint256) {
        return _nonces[owner][receiver];
    }

    /**
     * @dev See {IERC20Claimable-DOMAIN_SEPARATOR}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @dev "Consume a nonce": return the current value and increment.
     */
    function _useNonce(
        address owner,
        address receiver
    ) internal virtual returns (uint256) {
        unchecked {
            // It is important to do x++ and not ++x here.
            return _nonces[owner][receiver]++;
        }
    }
}
