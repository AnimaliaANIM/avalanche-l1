// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRandomProvider {
    function requestRandom(
        uint8 minConfirmation
    ) external returns (uint256 requestId);
}
