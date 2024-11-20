// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {EthereumDaiPermitModule} from "./EthereumDaiPermitModule.sol";
import {StEthModule} from "./StEthModule.sol";

import {GenericModule1} from "../GenericModule1.sol";

/// @title EthereumModule1
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Module contract specific to Ethereum n°1.
contract EthereumModule1 is GenericModule1, EthereumDaiPermitModule, StEthModule {
    /* CONSTRUCTOR */

    /// @param bundler The address of the bundler.
    /// @param morpho The address of the morpho protocol.
    /// @param weth The address of the wrapped ether token.
    /// @param dai The address of the dai.
    /// @param wStEth The address of the wstEth.
    constructor(address bundler, address morpho, address weth, address dai, address wStEth)
        GenericModule1(bundler, morpho, weth)
        EthereumDaiPermitModule(dai)
        StEthModule(wStEth)
    {}
}
