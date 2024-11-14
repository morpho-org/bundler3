// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.27;

import {BaseBundler} from "../BaseBundler.sol";
import {TransferBundler} from "../TransferBundler.sol";
import {PermitBundler} from "../PermitBundler.sol";
import {Permit2Bundler} from "../Permit2Bundler.sol";
import {ERC4626Bundler} from "../ERC4626Bundler.sol";
import {WNativeBundler} from "../WNativeBundler.sol";
import {UrdBundler} from "../UrdBundler.sol";
import {MorphoBundler} from "../MorphoBundler.sol";
import {ERC20WrapperBundler} from "../ERC20WrapperBundler.sol";

/// @title Bundler1
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Chain agnostic bundler contract n°1.
contract GenericBundler1 is
    TransferBundler,
    PermitBundler,
    Permit2Bundler,
    ERC4626Bundler,
    WNativeBundler,
    UrdBundler,
    MorphoBundler,
    ERC20WrapperBundler
{
    /* CONSTRUCTOR */

    constructor(address hub, address morpho, address wNative)
        BaseBundler(hub)
        WNativeBundler(wNative)
        MorphoBundler(morpho)
    {}
}
