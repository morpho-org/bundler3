// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {IDaiPermit} from "./interfaces/IDaiPermit.sol";

import {BaseModule} from "../BaseModule.sol";
import {ModuleLib} from "../libraries/ModuleLib.sol";
import {ErrorsLib} from "../libraries/ErrorsLib.sol";

/// @title EthereumDaiPermitModule
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice PermitModule contract specific to Ethereum, handling permit to DAI.
abstract contract EthereumDaiPermitModule is BaseModule {}
