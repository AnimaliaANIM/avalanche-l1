// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20Claimable {
    /**
     * @dev Sends `value` as token claimable from `owner` to `receiver`,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-transfer} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Transfer} event.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP section].
     */
    function claim(
        address owner,
        address receiver,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`+`receiver`. This value must be
     * included whenever a signature is generated for {claim}.
     *
     * Every successful call to {claim} increases ``owner`` + ``receiver``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner, address receiver) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {claim}, as defined by {EIP712}.
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
