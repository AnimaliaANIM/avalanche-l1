// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "./ERC1155/IERC1155Mintable.sol";

contract AnimaliaCardPackSales is
    AccessControl,
    ReentrancyGuard,
    Nonces,
    EIP712
{
    using SafeERC20 for IERC20;

    address public cardPackAddress;
    address payable public saleFundReceiver;
    uint256 public cardPackSalesCount;
    bytes32 private constant PURCHASE_TYPEHASH =
        keccak256(
            "Purchase(address buyer,uint256[] cardPackIds,uint256[] amounts,uint256[] salePrices,uint256 nonce,uint256 deadline)"
        );
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");
    mapping(uint256 cardPackId => CardPackSale) public cardPackSales;
    mapping(uint256 index => uint256 cardPackId) private cardPackIdAt;
    mapping(uint256 cardPackId => uint256 index) private cardPackIdIndex;

    struct CardPackSale {
        uint256 cardPackId;
        address saleCurrency;
        uint256 salePriceInUSD;
    }

    error SaleNotActive(uint256 cardPackId);
    error InsufficientFund(uint256 have, uint256 want);
    error ERC2612ExpiredSignature(uint256 deadline);
    error InvalidSignature();

    event Sale(
        address indexed buyer,
        uint256 id,
        uint256 value,
        address saleCurrency,
        uint256 salePrice,
        uint256 total
    );

    event RetryableTicketCreated(uint256 indexed ticketId);

    constructor(
        address payable _saleFundReceiver,
        address _cardPackAddress
    ) EIP712("Animalia Card Pack Sales", "1") {
        saleFundReceiver = _saleFundReceiver;
        cardPackAddress = _cardPackAddress;
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(OPERATOR_ROLE, _msgSender());
    }

    function setSaleFundReceiver(
        address payable _saleFundReceiver
    ) external onlyRole(OPERATOR_ROLE) {
        saleFundReceiver = _saleFundReceiver;
    }

    function setCardPackAddress(
        address _cardPackAddress
    ) external onlyRole(OPERATOR_ROLE) {
        cardPackAddress = _cardPackAddress;
    }

    function setCardPackSales(
        uint256[] calldata cardPackIds,
        address[] calldata saleCurrencies,
        uint256[] calldata salePriceInUSDs,
        bool[] calldata unsets
    ) external onlyRole(OPERATOR_ROLE) {
        for (uint256 i; i < cardPackIds.length; i++) {
            uint256 cardPackId = cardPackIds[i];

            if (unsets[i]) {
                uint256 index = cardPackIdIndex[cardPackId];
                // replace current cardPackId with last cardPackId
                cardPackIdAt[index] = cardPackIdAt[cardPackSalesCount - 1];

                // delete last cardPackId
                // delete cardPackIdAt[cardPackSalesCount - 1];
                // delete index cache
                // delete cardPackIdIndex[cardPackId];
                // delete cardPackSales by cardPackId
                delete cardPackSales[cardPackId];
                // reduce count
                cardPackSalesCount--;
            } else {
                if (cardPackSales[cardPackId].cardPackId == 0) {
                    // cache index
                    cardPackIdIndex[cardPackId] = cardPackSalesCount;
                    // push cardPackId
                    cardPackIdAt[cardPackSalesCount] = cardPackId;

                    // increment count
                    cardPackSalesCount++;
                }

                cardPackSales[cardPackId].cardPackId = cardPackId;
                cardPackSales[cardPackId].saleCurrency = saleCurrencies[i];
                cardPackSales[cardPackId].salePriceInUSD = salePriceInUSDs[i];
            }
        }
    }

    function getCardPackSales()
        external
        view
        returns (CardPackSale[] memory _cardPackSales)
    {
        _cardPackSales = new CardPackSale[](cardPackSalesCount);
        for (uint256 i; i < cardPackSalesCount; i++) {
            uint256 cardPackId = cardPackIdAt[i];
            _cardPackSales[i].cardPackId = cardPackSales[cardPackId].cardPackId;
            _cardPackSales[i].saleCurrency = cardPackSales[cardPackId]
                .saleCurrency;
            _cardPackSales[i].salePriceInUSD = cardPackSales[cardPackId]
                .salePriceInUSD;
        }
    }

    function purchase(
        address signer,
        uint256[] calldata cardPackIds,
        uint256[] calldata amounts,
        uint256[] calldata salePrices,
        uint256 deadline,
        bytes calldata signature
    ) external payable nonReentrant {
        _checkRole(MARKETPLACE_ROLE, signer);

        if (block.timestamp > deadline) {
            revert ERC2612ExpiredSignature(deadline);
        }

        bytes32 structHash = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    PURCHASE_TYPEHASH,
                    _msgSender(),
                    keccak256(abi.encodePacked(cardPackIds)),
                    keccak256(abi.encodePacked(amounts)),
                    keccak256(abi.encodePacked(salePrices)),
                    _useNonce(_msgSender()),
                    deadline
                )
            )
        );

        if (
            !SignatureChecker.isValidSignatureNow(signer, structHash, signature)
        ) {
            revert InvalidSignature();
        }

        for (uint256 i; i < cardPackIds.length; i++) {
            uint256 cardPackId = cardPackIds[i];
            CardPackSale memory cardPackSale = cardPackSales[cardPackId];

            if (cardPackSale.cardPackId != cardPackId) {
                revert SaleNotActive(cardPackId);
            }

            uint256 total = salePrices[i] * amounts[i];
            handlePayment(
                _msgSender(),
                saleFundReceiver,
                cardPackSale.saleCurrency,
                total
            );

            emit Sale(
                _msgSender(),
                cardPackId,
                amounts[i],
                cardPackSale.saleCurrency,
                salePrices[i],
                total
            );
        }

        IERC1155Mintable(cardPackAddress).mint(
            _msgSender(),
            cardPackIds,
            amounts,
            ""
        );
    }

    function handlePayment(
        address from,
        address payable to,
        address currency,
        uint256 amount
    ) internal {
        if (currency == address(0)) {
            if (from == address(this) && from.balance < amount) {
                revert InsufficientFund(from.balance, amount);
            } else if (from == _msgSender() && msg.value < amount) {
                revert InsufficientFund(msg.value, amount);
            }
            if (to == address(this)) {
                return;
            } else {
                if (address(this).balance < amount) {
                    revert InsufficientFund(from.balance, amount);
                }
                to.transfer(amount);
            }
        } else {
            uint256 beforeBalance = IERC20(currency).balanceOf(to);
            IERC20(currency).safeTransferFrom(_msgSender(), to, amount);
            uint256 afterBalance = IERC20(currency).balanceOf(to);
            if (beforeBalance + amount < afterBalance) {
                revert InsufficientFund(afterBalance - beforeBalance, amount);
            }
        }
    }

    receive() external payable {}

    fallback() external payable {}

    function recoverERC20(
        address tokenAddress,
        uint256 amount,
        address recipient
    ) external onlyRole(OPERATOR_ROLE) {
        IERC20(tokenAddress).safeTransfer(recipient, amount);
    }
}
