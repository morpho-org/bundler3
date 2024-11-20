// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {EthereumDaiPermitModule} from "./EthereumDaiPermitModule.sol";
import {StEthModule} from "./StEthModule.sol";

import {GenericModule1, BaseModule, ErrorsLib, ERC20Wrapper, ModuleLib, ERC20} from "../GenericModule1.sol";

/// @title EthereumModule1
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Module contract specific to Ethereum n°1.
contract EthereumModule1 is GenericModule1, EthereumDaiPermitModule, StEthModule {
    /* IMMUTABLES */

    /// @notice The address of the Morpho token.
    address public immutable MORPHO_TOKEN;

    /// @notice The address of the wrapper.
    address public immutable MORPHO_WRAPPER;

    /* CONSTRUCTOR */

    /// @param bundler The address of the bundler.
    /// @param morpho The address of the morpho.
    /// @param weth The address of the weth.
    /// @param dai The address of the dai.
    /// @param wStEth The address of the wstEth.
    /// @param morphoToken The address of the morpho token.
    /// @param morphoWrapper The address of the morpho wrapper.
    constructor(
        address bundler,
        address morpho,
        address weth,
        address dai,
        address wStEth,
        address morphoToken,
        address morphoWrapper
    ) GenericModule1(bundler, morpho, weth) EthereumDaiPermitModule(dai) StEthModule(wStEth) {
        require(morphoToken != address(0), ErrorsLib.ZeroAddress());
        require(morphoWrapper != address(0), ErrorsLib.ZeroAddress());

        MORPHO_TOKEN = morphoToken;
        MORPHO_WRAPPER = morphoWrapper;
    }

    /* EXTERNAL */

    /// @notice Unwraps Morpho tokens.
    /// @dev Separated from the erc20WrapperWithdrawTo function because the Morpho wrapper is separated from the
    /// underlying ERC20, so it does not have a balanceOf function and it needs to be approved on the underlying token.
    /// @param receiver The address to send the tokens to.
    /// @param amount The amount of tokens to unwrap.
    function morphoWrapperWithdrawTo(address receiver, uint256 amount) external bundlerOnly {
        require(receiver != address(0), ErrorsLib.ZeroAddress());

        if (amount == type(uint256).max) amount = ERC20(MORPHO_TOKEN).balanceOf(address(this));

        require(amount != 0, ErrorsLib.ZeroAmount());

        ModuleLib.approveMaxToIfAllowanceZero(MORPHO_TOKEN, MORPHO_WRAPPER);

        require(ERC20Wrapper(MORPHO_WRAPPER).withdrawTo(receiver, amount), ErrorsLib.WithdrawFailed());
    }
}
