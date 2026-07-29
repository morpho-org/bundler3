// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {MarketParams} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IBluePublicAllocator, Reallocation} from "../interfaces/IBluePublicAllocator.sol";
import {CoreAdapter} from "./CoreAdapter.sol";

/// @custom:security-contact security@morpho.org
/// @notice Adapter topping up Morpho Blue market liquidity through the vault-v2 Blue public allocator.
contract PublicAllocatorAdapter is CoreAdapter {
    /* CONSTRUCTOR */

    /// @param bundler3 The address of the Bundler3 contract.
    constructor(address bundler3) CoreAdapter(bundler3) {}

    /* ACTIONS */

    /// @notice Tops up Morpho Blue market liquidity through the vault-v2 Blue public allocator.
    /// @dev First allocates the vault's idle liquidity (skipped when `allocateFromIdleAssets` is zero), then performs
    /// each reallocation hop in order.
    /// @dev The vault's native penalty is paid to the public allocator on each sub-call. The adapter must have been
    /// pre-funded with enough native tokens to cover every sub-call (through the bundle's `Call.value`).
    /// @param publicAllocator The address of the Blue public allocator.
    /// @param vault The vault whose liquidity is reallocated.
    /// @param allocateFromIdleAdapter The Blue adapter to allocate the idle liquidity to.
    /// @param allocateFromIdleMarketParams The Morpho market to allocate the idle liquidity to.
    /// @param allocateFromIdleAssets The amount of idle liquidity to allocate. Pass zero to skip the idle allocation.
    /// @param reallocations The reallocation hops to perform, in order.
    function reallocate(
        address publicAllocator,
        address vault,
        address allocateFromIdleAdapter,
        MarketParams calldata allocateFromIdleMarketParams,
        uint128 allocateFromIdleAssets,
        Reallocation[] calldata reallocations
    ) external payable onlyBundler3 {
        // The public allocator requires `msg.value` to equal the vault's native penalty on every sub-call.
        (, uint120 nativePenalty,) = IBluePublicAllocator(publicAllocator).vaultData(vault);

        if (allocateFromIdleAssets > 0) {
            IBluePublicAllocator(publicAllocator).allocateFromIdle{value: nativePenalty}(
                vault, allocateFromIdleAdapter, allocateFromIdleMarketParams, allocateFromIdleAssets
            );
        }

        for (uint256 i; i < reallocations.length; i++) {
            Reallocation calldata r = reallocations[i];
            IBluePublicAllocator(publicAllocator).reallocate{value: nativePenalty}(
                vault,
                r.deallocateAdapter,
                r.deallocateMarketParams,
                r.allocateAdapter,
                r.allocateMarketParams,
                r.assets
            );
        }
    }
}
