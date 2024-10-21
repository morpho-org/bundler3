// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.27;

import {BaseBundler} from "../BaseBundler.sol";
import {PermitBundler} from "../PermitBundler.sol";
import {ERC4626Bundler} from "../ERC4626Bundler.sol";
import {WNativeBundler} from "../WNativeBundler.sol";
import {UrdBundler} from "../UrdBundler.sol";
import {MorphoBundler} from "../MorphoBundler.sol";
import {ERC20WrapperBundler} from "../ERC20WrapperBundler.sol";

/// @title Bundler1
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Chain agnostic bundler contract n°1.
/// @notice Future chain agnostic bundlers may be added in the future.
contract ChainAgnosticBundler1 is
    PermitBundler,
    ERC4626Bundler,
    WNativeBundler,
    UrdBundler,
    MorphoBundler,
    ERC20WrapperBundler
{
    /* CONSTRUCTOR */

    constructor(address hub, address morpho, address weth)
        BaseBundler(hub)
        WNativeBundler(weth)
        MorphoBundler(morpho)
    {}
}
