// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {EthereumPermitModule} from "./EthereumPermitModule.sol";
import {StEthModule} from "./StEthModule.sol";

import {BaseModule} from "../BaseModule.sol";

/// @title EthereumModule1
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Module contract specific to Ethereum n°1.
contract EthereumModule1 is EthereumPermitModule, StEthModule {
    /* CONSTRUCTOR */

    constructor(address bundler, address dai, address wStEth)
        BaseModule(bundler)
        EthereumPermitModule(dai)
        StEthModule(wStEth)
    {}
}
