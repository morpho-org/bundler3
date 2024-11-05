// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {EthereumPermitBundler} from "./EthereumPermitBundler.sol";
import {StEthBundler} from "./StEthBundler.sol";

import {BaseBundler} from "../BaseBundler.sol";

/// @title EthereumBundler1
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Bundler contract specific to Ethereum n°1.
contract EthereumBundler1 is EthereumPermitBundler, StEthBundler {
    /* CONSTRUCTOR */

    constructor(address hub, address dai, address wStEth)
        BaseBundler(hub)
        EthereumPermitBundler(dai)
        StEthBundler(wStEth)
    {}
}
