// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {MainnetLib} from "./libraries/MainnetLib.sol";

import {EthereumPermitBundler} from "./EthereumPermitBundler.sol";
import {StEthBundler} from "../StEthBundler.sol";

import {BaseBundler} from "../BaseBundler.sol";

/// @title EthereumBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Bundler contract specific to Ethereum n°1.
/// @notice Future Ethereum-specific bundlers may be added in the future.
contract EthereumBundler1 is EthereumPermitBundler, StEthBundler {
    /* CONSTRUCTOR */

    constructor(address hub, address wstEth) BaseBundler(hub) StEthBundler(wstEth) {}
}
