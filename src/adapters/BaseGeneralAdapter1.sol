// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IWstEth} from "../interfaces/IWstEth.sol";
import {IStEth} from "../interfaces/IStEth.sol";

import {GeneralAdapter1, CoreAdapter, ErrorsLib, SafeERC20, IERC20} from "./GeneralAdapter1.sol";
import {ERC20Wrapper} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import {MathRayLib} from "../libraries/MathRayLib.sol";

/// @custom:security-contact security@morpho.org
/// @notice Adapter contract specific to Base n°1.
contract BaseGeneralAdapter1 is GeneralAdapter1 {
    using MathRayLib for uint256;

    /// @notice The address of the BundlerV2, to prevent unauthorized transfers.
    address public immutable BUNDLER_V2;

    /* CONSTRUCTOR */

    /// @param bundler3 The address of the Bundler3 contract.
    /// @param bundlerV2 The address of the BundlerV3 contract.
    /// @param morpho The address of Morpho.
    /// @param wNative The address of the canonical native token wrapper.
    constructor(address bundler3, address bundlerV2, address morpho, address wNative)
        GeneralAdapter1(bundler3, morpho, wNative)
    {
        require(bundlerV2 != address(0), ErrorsLib.ZeroAddress());

        BUNDLER_V2 = bundlerV2;
    }

    /* ERC20 ACTIONS */

    /// @inheritdoc CoreAdapter
    function erc20Transfer(address token, address receiver, uint256 amount) public override onlyBundler3 {
        require(receiver != BUNDLER_V2, ErrorsLib.UnauthorizedReceiver());
        super.erc20Transfer(token, receiver, amount);
    }
}
