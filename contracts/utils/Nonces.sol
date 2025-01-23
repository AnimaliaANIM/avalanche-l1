// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Provides tracking nonces for addresses. Nonces will only increment.
 */
abstract contract Nonces {
    /**
     * @dev The nonce used for an `account` combination is not the expected current nonce.
     */
    error InvalidAccountNonce(
        address owner,
        address account,
        uint256 currentNonce
    );

    mapping(address owner => mapping(address account => uint256))
        private _nonces;

    /**
     * @dev Returns the next unused nonce for an address combination.
     */
    function nonces(
        address owner,
        address account
    ) public view virtual returns (uint256) {
        return _nonces[owner][account];
    }

    /**
     * @dev Consumes a nonce.
     *
     * Returns the current value and increments nonce.
     */
    function _useNonce(
        address owner,
        address account
    ) internal virtual returns (uint256) {
        // For each account, the nonce has an initial value of 0, can only be incremented by one, and cannot be
        // decremented or reset. This guarantees that the nonce never overflows.
        unchecked {
            // It is important to do x++ and not ++x here.
            return _nonces[owner][account]++;
        }
    }

    /**
     * @dev Same as {_useNonce} but checking that `nonce` is the next valid for `owner`.
     */
    function _useCheckedNonce(
        address owner,
        address account,
        uint256 nonce
    ) internal virtual {
        uint256 current = _useNonce(owner, account);
        if (nonce != current) {
            revert InvalidAccountNonce(owner, account, current);
        }
    }
}
