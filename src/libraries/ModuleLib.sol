// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "./ErrorsLib.sol";
import {SafeTransferLib, ERC20} from "../../lib/solmate/src/utils/SafeTransferLib.sol";

/// @custom:contact security@morpho.org
/// @notice Library exposing common module functionality
library ModuleLib {
    /// @dev Gives the max approval to `spender` to spend the given token if not already approved.
    /// @dev Assumes that `type(uint256).max` is large enough to never have to increase the allowance again.
    function approveMaxToIfAllowanceZero(address token, address spender) internal {
        if (ERC20(token).allowance(address(this), spender) == 0) {
            SafeTransferLib.safeApprove(ERC20(token), spender, type(uint256).max);
        }
    }

    /// @dev Bubbles up the revert reason / custom error encoded in `returnData`.
    /// @dev Assumes `returnData` is the return data of any kind of failing CALL to a contract.
    function lowLevelRevert(bytes memory returnData) internal pure {
        assembly ("memory-safe") {
            revert(add(32, returnData), mload(returnData))
        }
    }
}
