// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {IUniversalRewardsDistributor} from
    "../lib/universal-rewards-distributor/src/interfaces/IUniversalRewardsDistributor.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";

import {BaseBundler} from "./BaseBundler.sol";
import {BundlerLib} from "./libraries/BundlerLib.sol";

/// @title UrdBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Bundler that allows to claim token rewards on the Universal Rewards Distributor.
abstract contract UrdBundler is BaseBundler {
    /// @notice Claims available `reward` tokens on behalf of `account` on the given rewards distributor, using `proof`.
    /// @dev Assumes the given distributor implements IUniversalRewardsDistributor.
    /// @param distributor The address of the reward distributor contract.
    /// @param account The address of the owner of the rewards (also the address that will receive the rewards).
    /// @param reward The address of the token reward.
    /// @param claimable The overall claimable amount of token rewards.
    /// @param proof The proof.
    /// @param skipRevert Whether to avoid reverting the call in case the proof is frontrunned.
    function urdClaim(
        address distributor,
        address account,
        address reward,
        uint256 claimable,
        bytes32[] calldata proof,
        bool skipRevert
    ) external hubOnly {
        require(account != address(0), ErrorsLib.ZeroAddress());
        require(account != address(this), ErrorsLib.BundlerAddress());

        try IUniversalRewardsDistributor(distributor).claim(account, reward, claimable, proof) {}
        catch (bytes memory returnData) {
            if (!skipRevert) BundlerLib.lowLevelRevert(returnData);
        }
    }
}
