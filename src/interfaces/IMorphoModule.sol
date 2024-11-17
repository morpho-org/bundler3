// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {
    IMorphoRepayCallback,
    IMorphoSupplyCallback,
    IMorphoSupplyCollateralCallback,
    IMorphoFlashLoanCallback
} from "../../lib/morpho-blue/src/interfaces/IMorphoCallbacks.sol";

/// @title IMorphoModule
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Interface of MorphoModule.
interface IMorphoModule is
    IMorphoSupplyCallback,
    IMorphoRepayCallback,
    IMorphoSupplyCollateralCallback,
    IMorphoFlashLoanCallback
{}
