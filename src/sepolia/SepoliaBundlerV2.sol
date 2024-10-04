// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {SepoliaLib} from "./libraries/SepoliaLib.sol";

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

/// @title SepoliaBundlerV2
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Bundler contract specific to the Sepolia testnet.
contract SepoliaBundlerV2 is
    TransferBundler,
    PermitBundler,
    Permit2Bundler,
    ERC4626Bundler,
    WNativeBundler,
    StEthBundler,
    UrdBundler,
    MorphoBundler,
    ERC20WrapperBundler
{
    /* CONSTRUCTOR */

    constructor(address morpho)
        WNativeBundler(SepoliaLib.WETH)
        StEthBundler(SepoliaLib.WST_ETH)
        MorphoBundler(morpho)
    {}

    /* INTERNAL */

    /// @inheritdoc MorphoBundler
    function _isSenderAuthorized() internal view override(BaseBundler, MorphoBundler) returns (bool) {
        return MorphoBundler._isSenderAuthorized();
    }
}
