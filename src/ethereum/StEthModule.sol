// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {IWstEth} from "../interfaces/IWstEth.sol";
import {IStEth} from "../interfaces/IStEth.sol";

import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {ERC20} from "../../lib/solmate/src/utils/SafeTransferLib.sol";

import {BaseModule, SafeTransferLib} from "../BaseModule.sol";
import {ModuleLib} from "../libraries/ModuleLib.sol";

/// @title StEthModule
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Contract allowing to bundle multiple interactions with stETH together.
abstract contract StEthModule is BaseModule {
    /* CONSTRUCTOR */

    /// @param wstEth The address of the wstEth contract.
    constructor(address wstEth) {}
}
