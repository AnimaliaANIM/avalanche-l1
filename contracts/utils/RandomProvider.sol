// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./IRandomProvider.sol";
import "./RandomConsumer.sol";

contract RandomProvider is
    IRandomProvider,
    Nonces,
    ReentrancyGuard,
    AccessControl
{
    using EnumerableMap for EnumerableMap.UintToUintMap;
    using EnumerableSet for EnumerableSet.UintSet;

    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    struct Request {
        uint256 requestId;
        address subscriber;
        uint256 requestedAtBlock;
        uint8 minConfirmation;
        uint256 random;
        uint256 fulfilledAtBlock;
    }

    mapping(uint256 requestId => Request) public requests;
    mapping(address subscriber => uint256[]) public subscriberRequestIds;

    EnumerableSet.UintSet private pendingRequestIds;

    event RandomRequested(address indexed subscriber, uint256 requestId);
    event RandomFulfilled(
        uint256 indexed requestId,
        uint256 random,
        bool success
    );

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function getRequestId(
        address sender,
        uint256 nonce,
        uint256 requestedAtBlock
    ) private pure returns (uint256 requestId) {
        requestId = uint256(
            keccak256(abi.encode(sender, nonce, requestedAtBlock))
        );
    }

    function requestRandom(
        uint8 minConfirmation
    ) public nonReentrant returns (uint256 requestId) {
        uint256 requestedAtBlock = block.number;
        requestId = getRequestId(
            _msgSender(),
            _useNonce(_msgSender()),
            requestedAtBlock
        );

        requests[requestId] = Request({
            requestId: requestId,
            subscriber: _msgSender(),
            requestedAtBlock: requestedAtBlock,
            minConfirmation: minConfirmation,
            random: 0,
            fulfilledAtBlock: 0
        });

        pendingRequestIds.add(requestId);

        emit RandomRequested(_msgSender(), requestId);
    }

    function fulfillRandom(
        uint256 randomSeed,
        uint256 maxRequestCount
    ) external nonReentrant onlyRole(ORACLE_ROLE) {
        uint256[] memory allPendingRequestIds = pendingRequestIds.values();

        if (allPendingRequestIds.length == 0) {
            revert("No pending requests");
        }

        for (
            uint256 i;
            i < allPendingRequestIds.length && i < maxRequestCount;
            i++
        ) {
            uint256 requestId = allPendingRequestIds[i];
            Request storage request = requests[requestId];
            if (
                request.requestedAtBlock + request.minConfirmation <=
                block.number
            ) {
                uint256 random = uint256(
                    keccak256(abi.encode(randomSeed, requestId))
                );
                request.random = random;
                request.fulfilledAtBlock = block.number;

                RandomConsumer consumer = RandomConsumer(request.subscriber);

                bool success = consumer.rawFulfillRandom(requestId, random);

                if (!success) {
                    revert("rawFulfillRandom failed");
                }

                pendingRequestIds.remove(requestId);

                emit RandomFulfilled(requestId, random, success);
            }
        }
    }

    function getRequestBySubscriber(
        address subscriber
    ) external view returns (Request[] memory _requests) {
        _requests = new Request[](subscriberRequestIds[subscriber].length);

        for (uint256 i; i < subscriberRequestIds[subscriber].length; i++) {
            _requests[i] = requests[subscriberRequestIds[subscriber][i]];
        }
    }

    function getPendingRequestCount() external view returns (uint256 count) {
        count = pendingRequestIds.length();
    }
}
