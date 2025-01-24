// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IRandomProvider.sol";

abstract contract RandomConsumer {
    IRandomProvider public randomProvider;

    error ZeroAddress();
    error OnlyProviderCanFulfill(address have, address want);

    constructor(address providerAddress) {
        randomProvider = IRandomProvider(providerAddress);
    }

    function _setRandomProvider(address providerAddress) internal {
        if (providerAddress == address(0)) {
            revert ZeroAddress();
        }
        randomProvider = IRandomProvider(providerAddress);
    }

    function fulfillRandom(uint256 requestId, uint256 random) internal virtual;

    function rawFulfillRandom(
        uint256 requestId,
        uint256 random
    ) external returns (bool success) {
        if (msg.sender != address(randomProvider)) {
            revert OnlyProviderCanFulfill(msg.sender, address(randomProvider));
        }
        fulfillRandom(requestId, random);

        success = true;
    }
}
