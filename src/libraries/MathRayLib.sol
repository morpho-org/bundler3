// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

uint256 constant RAY = 1e27;

/// @custom:security-contact security@morpho.org
/// @notice Library to manage high-precision fixed-point arithmetic.
library MathRayLib {
    /// @dev Returns (`x` * `RAY`) / `y` rounded down.
    function rDivDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x * RAY) / y;
    }

    /// @dev Returns (`x` * `RAY`) / `y` rounded up.
    function rDivUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x * RAY + (y - 1)) / y;
    }
}
