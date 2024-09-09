// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.24;

import {GoerliLib} from "./libraries/GoerliLib.sol";

import {BaseBundler} from "../BaseBundler.sol";
import {TransferBundler} from "../TransferBundler.sol";
import {PermitBundler} from "../PermitBundler.sol";
import {Permit2Bundler} from "../Permit2Bundler.sol";
import {ERC4626Bundler} from "../ERC4626Bundler.sol";
import {WNativeBundler} from "../WNativeBundler.sol";
import {StEthBundler} from "../StEthBundler.sol";
import {UrdBundler} from "../UrdBundler.sol";
import {MorphoBundler} from "../MorphoBundler.sol";
import {ERC20WrapperBundler} from "../ERC20WrapperBundler.sol";
import {ModuleCallerBundler} from "../ModuleCallerBundler.sol";

/// @title GoerliBundlerV2
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Bundler contract specific to the Goerli testnet.
contract GoerliBundlerV2 is
    TransferBundler,
    PermitBundler,
    Permit2Bundler,
    ERC4626Bundler,
    WNativeBundler,
    StEthBundler,
    UrdBundler,
    MorphoBundler,
    ERC20WrapperBundler,
    ModuleCallerBundler
{
    /* CONSTRUCTOR */

    constructor(address morpho) WNativeBundler(GoerliLib.WETH) StEthBundler(GoerliLib.WST_ETH) MorphoBundler(morpho) {}

    /* INTERNAL */

    /// @inheritdoc MorphoBundler
    function _isSenderAuthorized() internal view override(BaseBundler, MorphoBundler) returns (bool) {
        return MorphoBundler._isSenderAuthorized();
    }
}
