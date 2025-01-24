// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "./ERC1155/IERC1155Mintable.sol";

contract AnimaliaCardPacksV1 is
    ERC1155,
    AccessControl,
    ERC1155Burnable,
    ERC1155Pausable,
    ERC1155Supply,
    IERC1155Receiver,
    ERC721Holder,
    ReentrancyGuard,
    ERC2981,
    Nonces,
    VRFConsumerBaseV2Plus,
    EIP712
{
    using SafeERC20 for IERC20;

    uint256 public subscriptionId;
    uint256 public requestsCount;
    uint256 public lastRequestId;
    mapping(uint256 requestId => Request) public requests;
    mapping(uint256 index => uint256 requestId) public requestIds;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant OPENER_ROLE = keccak256("OPENER_ROLE");
    bytes32 public constant REVEALER_ROLE = keccak256("REVEALER_ROLE");
    bytes32 private constant OPEN_TYPEHASH =
        keccak256(
            "Open(address signer,address account,bool enableNativePayment,uint32 numWords,uint16 requestConfirmations,uint32 callbackGasLimit,bytes32 keyHash,uint256[] openIds,uint256[] openValues,uint256 nonce)"
        );
    bytes32 private constant REVEAL_TYPEHASH =
        keccak256(
            "Reveal(address signer,uint256 requestId,address mintTokenAddress,address transferTokenAddress,uint256[] mintIds,uint256[] mintValues,uint256 transferCount)"
        );

    struct Request {
        uint256 requestId;
        address account;
        bool revealed;
        uint256[] openIds;
        uint256[] openValues;
        uint256[] randomWords;
    }

    error TokenCountExceedCap(uint256 tokenCount, uint256 cap);
    error AlreadyRevealed(uint256 requestId);
    error InvalidSignature();
    error RequestNotFound();
    error RequestPending(uint256 requestId);
    error InvalidNumWords(uint32 numWords);
    error InsufficientBalance(uint256 balance);

    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);
    event Open(
        address indexed account,
        uint256[] openIds,
        uint256[] openValues
    );
    event Reveal(
        address indexed account,
        address mintTokenAddress,
        address transferTokenAddress,
        uint256 indexed requestId,
        uint256[] mintIds,
        uint256[] mintValues,
        uint256 transferCount
    );

    constructor(
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        address vrfCoordinator
    )
        ERC1155("")
        EIP712("Animalia Card Packs", "1")
        VRFConsumerBaseV2Plus(vrfCoordinator)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(OPERATOR_ROLE, _msgSender());
        _setDefaultRoyalty(royaltyReceiver, royaltyFeeNumerator);
    }

    function setURI(string calldata newuri) external onlyRole(OPERATOR_ROLE) {
        _setURI(newuri);
    }

    function pause() external onlyRole(OPERATOR_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(OPERATOR_ROLE) {
        _unpause();
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

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    // single mint
    function mint(
        address to,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external onlyRole(MINTER_ROLE) {
        _mint(to, id, value, data);
    }

    // batch mint
    function mint(
        address to,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external onlyRole(MINTER_ROLE) {
        _mintBatch(to, ids, values, data);
    }

    function recover(
        address tokenAddress,
        uint256 amount,
        address recipient
    ) external onlyRole(OPERATOR_ROLE) {
        IERC20(tokenAddress).safeTransfer(recipient, amount);
    }

    function recoverERC1155(
        address tokenAddress,
        address recipient,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external onlyRole(OPERATOR_ROLE) {
        ERC1155(tokenAddress).safeBatchTransferFrom(
            address(this),
            recipient,
            ids,
            values,
            data
        );
    }

    function setSubscriptionId(
        uint256 _subscriptionId
    ) external onlyRole(OPERATOR_ROLE) {
        subscriptionId = _subscriptionId;
    }

    function requestRandomWords(
        bool enableNativePayment,
        uint32 numWords,
        uint16 requestConfirmations,
        uint32 callbackGasLimit,
        bytes32 keyHash
    ) internal returns (uint256 requestId) {
        // Will revert if subscription is not set and funded.
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({
                        nativePayment: enableNativePayment
                    })
                )
            })
        );
        requestIds[requestsCount++] = requestId;
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        requests[requestId].randomWords = randomWords;
        emit RequestFulfilled(requestId, randomWords);
    }

    function getRequestsByAccount(
        address account,
        bool skipRevealed
    ) external view returns (Request[] memory accountRequests) {
        uint256 j;
        Request[] memory picks = new Request[](requestsCount);
        for (uint256 i; i < requestsCount; i++) {
            if (account != requests[requestIds[i]].account) {
                continue;
            }
            if (skipRevealed && requests[requestIds[i]].revealed) {
                continue;
            }
            picks[j++] = requests[requestIds[i]];
        }
        accountRequests = new Request[](j);

        for (uint256 i; i < j; i++) {
            accountRequests[i] = picks[i];
        }
    }

    function open(
        address signer,
        bool enableNativePayment,
        uint32 numWords,
        uint16 requestConfirmations,
        uint32 callbackGasLimit,
        bytes32 keyHash,
        uint256[] calldata openIds,
        uint256[] calldata openValues,
        bytes calldata signature
    ) external nonReentrant {
        if (!hasRole(OPENER_ROLE, signer)) {
            revert AccessControlUnauthorizedAccount(signer, OPENER_ROLE);
        }

        if (numWords == 0) {
            revert InvalidNumWords(numWords);
        }

        bytes32 structHash = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    OPEN_TYPEHASH,
                    signer,
                    _msgSender(),
                    enableNativePayment,
                    numWords,
                    requestConfirmations,
                    callbackGasLimit,
                    keyHash,
                    keccak256(abi.encodePacked(openIds)),
                    keccak256(abi.encodePacked(openValues)),
                    nonces(_msgSender())
                )
            )
        );

        if (
            !SignatureChecker.isValidSignatureNow(signer, structHash, signature)
        ) {
            revert InvalidSignature();
        }

        _useNonce(_msgSender());

        uint256 requestId = requestRandomWords(
            enableNativePayment,
            numWords,
            requestConfirmations,
            callbackGasLimit,
            keyHash
        );

        requests[requestId] = Request({
            requestId: requestId,
            account: _msgSender(),
            revealed: false,
            openIds: openIds,
            openValues: openValues,
            randomWords: new uint256[](0)
        });

        _safeBatchTransferFrom(
            requests[requestId].account,
            address(this),
            requests[requestId].openIds,
            requests[requestId].openValues,
            ""
        );

        emit Open(_msgSender(), openIds, openValues);
    }

    // function testVerifyReveal(
    //     address signer,
    //     uint256 requestId,
    //     address mintTokenAddress,
    //     uint256[] calldata mintIds,
    //     uint256[] calldata mintValues,
    //     bytes calldata signature
    // ) public view returns (bool) {
    //     if (!hasRole(REVEALER_ROLE, signer)) {
    //         revert AccessControlUnauthorizedAccount(signer, REVEALER_ROLE);
    //     }

    //     if (requests[requestId].requestId != requestId) {
    //         revert RequestNotFound();
    //     }

    //     if (requests[requestId].randomWords.length == 0) {
    //         revert RequestPending(requestId);
    //     }

    //     if (requests[requestId].revealed) {
    //         revert AlreadyRevealed(requestId);
    //     }

    //     bytes32 structHash = _hashTypedDataV4(
    //         keccak256(
    //             abi.encode(
    //                 REVEAL_TYPEHASH,
    //                 signer,
    //                 requestId,
    //                 mintTokenAddress,
    //                 keccak256(abi.encodePacked(mintIds)),
    //                 keccak256(abi.encodePacked(mintValues))
    //             )
    //         )
    //     );

    //     return
    //         SignatureChecker.isValidSignatureNow(signer, structHash, signature);
    // }

    // function testMintToken(
    //     address signer,
    //     uint256 requestId,
    //     address mintTokenAddress,
    //     uint256[] calldata mintIds,
    //     uint256[] calldata mintValues
    // ) public {
    //     if (!hasRole(REVEALER_ROLE, signer)) {
    //         revert AccessControlUnauthorizedAccount(signer, REVEALER_ROLE);
    //     }

    //     IERC1155Mintable(mintTokenAddress).mint(
    //         requests[requestId].account,
    //         mintIds,
    //         mintValues,
    //         ""
    //     );
    // }

    // function testBurn(address signer, uint256 requestId) public {
    //     if (!hasRole(REVEALER_ROLE, signer)) {
    //         revert AccessControlUnauthorizedAccount(signer, REVEALER_ROLE);
    //     }

    //     _burnBatch(
    //         address(this),
    //         requests[requestId].openIds,
    //         requests[requestId].openValues
    //     );
    // }

    function reveal(
        address signer,
        uint256 requestId,
        address mintTokenAddress,
        address transferTokenAddress,
        uint256[] calldata mintIds,
        uint256[] calldata mintValues,
        uint256 transferCount,
        bytes calldata signature
    ) external nonReentrant {
        if (!hasRole(REVEALER_ROLE, signer)) {
            revert AccessControlUnauthorizedAccount(signer, REVEALER_ROLE);
        }

        if (requests[requestId].requestId != requestId) {
            revert RequestNotFound();
        }

        if (requests[requestId].randomWords.length == 0) {
            revert RequestPending(requestId);
        }

        if (requests[requestId].revealed) {
            revert AlreadyRevealed(requestId);
        }

        bytes32 structHash = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    REVEAL_TYPEHASH,
                    signer,
                    requestId,
                    mintTokenAddress,
                    transferTokenAddress,
                    keccak256(abi.encodePacked(mintIds)),
                    keccak256(abi.encodePacked(mintValues)),
                    transferCount
                )
            )
        );

        if (
            !SignatureChecker.isValidSignatureNow(signer, structHash, signature)
        ) {
            revert InvalidSignature();
        }

        // if (
        //     !testVerifyReveal(
        //         signer,
        //         requestId,
        //         mintTokenAddress,
        //         mintIds,
        //         mintValues,
        //         signature
        //     )
        // ) {
        //     revert InvalidSignature();
        // }

        requests[requestId].revealed = true;

        IERC1155Mintable(mintTokenAddress).mint(
            requests[requestId].account,
            mintIds,
            mintValues,
            ""
        );

        if (
            IERC721Enumerable(transferTokenAddress).balanceOf(address(this)) <
            transferCount
        ) {
            revert InsufficientBalance(transferCount);
        }

        for (uint256 i = 0; i < transferCount; i++) {
            IERC721Enumerable(transferTokenAddress).transferFrom(
                address(this),
                requests[requestId].account,
                IERC721Enumerable(transferTokenAddress).tokenOfOwnerByIndex(
                    address(this),
                    0
                )
            );
        }

        // testMintToken(signer, requestId, mintTokenAddress, mintIds, mintValues);

        _burnBatch(
            address(this),
            requests[requestId].openIds,
            requests[requestId].openValues
        );

        // testBurn(signer, requestId);

        emit Reveal(
            requests[requestId].account,
            mintTokenAddress,
            transferTokenAddress,
            requestId,
            mintIds,
            mintValues,
            transferCount
        );
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155, ERC1155Supply, ERC1155Pausable) {
        super._update(from, to, ids, values);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC1155, IERC165, ERC2981, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
