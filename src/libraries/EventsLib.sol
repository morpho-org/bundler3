// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title EventsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing events.
library EventsLib {
    /// @notice Emitted after a Paraswap module swap
    event MorphoBundlerParaswapModuleSwap(
        address indexed srcToken,
        address indexed destToken,
        address indexed receiver,
        uint256 srcAmount,
        uint256 destAmount
    );
}
