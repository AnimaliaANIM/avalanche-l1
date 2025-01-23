// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TransferHelper {
    using SafeERC20 for IERC20;

    error InsufficientAmountReceived(address currency, uint256 amount);
    error InsufficientBalanceForTransfer(uint256 balance, uint256 amount);

    function _transferIn(address currency, uint256 amount) internal {
        if (currency == address(0) && msg.value < amount) {
            revert InsufficientAmountReceived(currency, amount);
        } else {
            IERC20 token = IERC20(currency);
            uint256 beforeBalance = token.balanceOf(address(this));
            IERC20(currency).safeTransferFrom(
                msg.sender,
                address(this),
                amount
            );
            uint256 afterBalance = token.balanceOf(address(this));
            if (afterBalance < beforeBalance + amount) {
                revert InsufficientAmountReceived(currency, amount);
            }
        }
    }

    function _transferOut(
        address recipient,
        address currency,
        uint256 amount
    ) internal {
        if (amount == 0 || recipient == address(0)) {
            return;
        }

        if (currency == address(0)) {
            if (address(this).balance < amount) {
                revert InsufficientBalanceForTransfer(
                    address(this).balance,
                    amount
                );
            }

            Address.sendValue(payable(recipient), amount);
        } else {
            IERC20(currency).safeTransfer(recipient, amount);
        }
    }
}
