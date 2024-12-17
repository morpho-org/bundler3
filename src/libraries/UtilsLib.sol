// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {SafeERC20, IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @custom:contact security@morpho.org
/// @notice Utils library.
library UtilsLib {
    /// @dev Gives the max approval to `spender` to spend the given token.
    function forceApproveMaxTo(address token, address spender) internal {
        SafeERC20.forceApprove(IERC20(token), spender, type(uint256).max);
    }

    /// @dev Removes approval to `spender` to spend the given token.
    function forceApproveZeroTo(address token, address spender) internal {
        SafeERC20.forceApprove(IERC20(token), spender, 0);
    }

    /// @dev Bubbles up the revert reason / custom error encoded in `returnData`.
    /// @dev Assumes `returnData` is the return data of any kind of failing CALL to a contract.
    function lowLevelRevert(bytes memory returnData) internal pure {
        assembly ("memory-safe") {
            revert(add(32, returnData), mload(returnData))
        }
    }
}
