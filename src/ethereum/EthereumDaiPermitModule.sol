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
abstract contract EthereumDaiPermitModule is BaseModule {
    /* IMMUTABLES */

    address public immutable DAI;

    /* CONSTRUCTOR */

    constructor(address dai) {
        require(dai != address(0), ErrorsLib.ZeroAddress());

        DAI = dai;
    }

    /// @notice Permits DAI.
    /// @param spender The account allowed to spend the Dai.
    /// @param nonce The nonce of the signed message.
    /// @param expiry The expiry of the signed message.
    /// @param allowed Whether the initiator gives the module infinite Dai approval or not.
    /// @param v The `v` component of a signature.
    /// @param r The `r` component of a signature.
    /// @param s The `s` component of a signature.
    /// @param skipRevert Whether to avoid reverting the call in case the signature is frontrunned.
    function permitDai(
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bool skipRevert
    ) external bundlerOnly {
        try IDaiPermit(DAI).permit(initiator(), spender, nonce, expiry, allowed, v, r, s) {}
        catch (bytes memory returnData) {
            if (!skipRevert) ModuleLib.lowLevelRevert(returnData);
        }
    }
}
