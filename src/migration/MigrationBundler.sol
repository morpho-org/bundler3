// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {SafeTransferLib, ERC20} from "../../lib/solmate/src/utils/SafeTransferLib.sol";

import {BaseBundler} from "../BaseBundler.sol";
import {TransferBundler} from "../TransferBundler.sol";
import {PermitBundler} from "../PermitBundler.sol";
import {Permit2Bundler} from "../Permit2Bundler.sol";
import {ERC4626Bundler} from "../ERC4626Bundler.sol";
import {MorphoBundler} from "../MorphoBundler.sol";

/// @title MigrationBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Abstract contract allowing to migrate a position from one lending protocol to Morpho Blue easily.
abstract contract MigrationBundler is TransferBundler, PermitBundler, Permit2Bundler, ERC4626Bundler, MorphoBundler {
    using SafeTransferLib for ERC20;

    /* CONSTRUCTOR */

    constructor(address morpho) MorphoBundler(morpho) {}

    /* INTERNAL */

    /// @inheritdoc MorphoBundler
    function _isSenderAuthorized() internal view virtual override(BaseBundler, MorphoBundler) returns (bool) {
        return MorphoBundler._isSenderAuthorized();
    }
}
