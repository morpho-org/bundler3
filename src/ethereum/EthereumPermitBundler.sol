// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {IDaiPermit} from "./interfaces/IDaiPermit.sol";

import {MainnetLib} from "./libraries/MainnetLib.sol";

import {PermitBundler} from "../PermitBundler.sol";

/// @title EthereumPermitBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice PermitBundler contract specific to Ethereum, handling permit to DAI.
abstract contract EthereumPermitBundler is PermitBundler {
    /// @notice Permits DAI from sender to be spent by the bundler with the given `nonce`, `expiry` & EIP-712
    /// signature's `v`, `r` & `s`.
    /// @param nonce The nonce of the signed message.
    /// @param expiry The expiry of the signed message.
    /// @param allowed Whether the initiator gives the bundler infinite Dai approval or not.
    /// @param v The `v` component of a signature.
    /// @param r The `r` component of a signature.
    /// @param s The `s` component of a signature.
    /// @param skipRevert Whether to avoid reverting the call in case the signature is frontrunned.
    function permitDai(uint256 nonce, uint256 expiry, bool allowed, uint8 v, bytes32 r, bytes32 s, bool skipRevert)
        external
        hubOnly
    {
        try IDaiPermit(MainnetLib.DAI).permit(initiator(), address(this), nonce, expiry, allowed, v, r, s) {}
        catch (bytes memory returnData) {
            if (!skipRevert) _revert(returnData);
        }
    }
}
