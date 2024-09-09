// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.26;

import {MainnetLib} from "./libraries/MainnetLib.sol";

import {StEthBundler} from "../StEthBundler.sol";

/// @title EthereumStEthBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice StEthBundler contract specific to Ethereum.
abstract contract EthereumStEthBundler is StEthBundler {
    /* CONSTRUCTOR */

    constructor() StEthBundler(MainnetLib.WST_ETH) {}
}
