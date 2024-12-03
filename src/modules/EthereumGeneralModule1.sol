// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IDaiPermit} from "../interfaces/IDaiPermit.sol";
import {IWstEth} from "../interfaces/IWstEth.sol";
import {IStEth} from "../interfaces/IStEth.sol";

import {GeneralModule1, ErrorsLib, ERC20Wrapper, UtilsLib, SafeTransferLib, ERC20} from "./GeneralModule1.sol";
import {MathRayLib} from "../libraries/MathRayLib.sol";

/// @custom:contact security@morpho.org
/// @notice Module contract specific to Ethereum n°1.
contract EthereumGeneralModule1 is GeneralModule1 {
    using MathRayLib for uint256;

    /* IMMUTABLES */

    /// @dev The address of the DAI token on Ethereum.
    address public immutable DAI;

    /// @dev The address of the stETH contract.
    address public immutable ST_ETH;

    /// @dev The address of the wStETH contract.
    address public immutable WST_ETH;

    /// @notice The address of the Morpho token.
    address public immutable MORPHO_TOKEN;

    /// @notice The address of the wrapper.
    address public immutable MORPHO_WRAPPER;

    /* CONSTRUCTOR */

    /// @param bundler The address of the bundler.
    /// @param morpho The address of Morpho.
    /// @param weth The address of the weth.
    /// @param dai The address of the dai.
    /// @param wStEth The address of the wStEth.
    /// @param morphoToken The address of the morpho token.
    /// @param morphoWrapper The address of the morpho token wrapper.
    constructor(
        address bundler,
        address morpho,
        address weth,
        address dai,
        address wStEth,
        address morphoToken,
        address morphoWrapper
    ) GeneralModule1(bundler, morpho, weth) {
        require(dai != address(0), ErrorsLib.ZeroAddress());
        require(wStEth != address(0), ErrorsLib.ZeroAddress());
        require(morphoToken != address(0), ErrorsLib.ZeroAddress());
        require(morphoWrapper != address(0), ErrorsLib.ZeroAddress());

        DAI = dai;
        ST_ETH = IWstEth(wStEth).stETH();
        WST_ETH = wStEth;
        MORPHO_TOKEN = morphoToken;
        MORPHO_WRAPPER = morphoWrapper;

        UtilsLib.approveMaxToIfAllowanceZero(ST_ETH, WST_ETH);
        UtilsLib.approveMaxToIfAllowanceZero(MORPHO_TOKEN, MORPHO_WRAPPER);
    }

    /* MORPHO TOKEN WRAPPER ACTIONS */

    /// @notice Unwraps Morpho tokens.
    /// @dev Separated from the erc20WrapperWithdrawTo function because the Morpho wrapper is separated from the
    /// wrapped token, so it does not have a balanceOf function, and the wrapped token needs to be approved before
    /// withdrawTo.
    /// @param receiver The address to send the tokens to.
    /// @param amount The amount of tokens to unwrap.
    function morphoWrapperWithdrawTo(address receiver, uint256 amount) external onlyBundler {
        require(receiver != address(0), ErrorsLib.ZeroAddress());

        if (amount == type(uint256).max) amount = ERC20(MORPHO_TOKEN).balanceOf(address(this));

        require(amount != 0, ErrorsLib.ZeroAmount());

        require(ERC20Wrapper(MORPHO_WRAPPER).withdrawTo(receiver, amount), ErrorsLib.WithdrawFailed());
    }

    /* LIDO ACTIONS */

    /// @notice Stakes ETH via Lido.
    /// @dev ETH must have been previously sent to the module.
    /// @param amount The amount of ETH to stake. Pass `type(uint).max` to repay the module's ETH balance.
    /// @param maxSharePriceE27 The maximum amount of wei to pay for minting 1 share, scaled by 1e27.
    /// @param referral The address of the referral regarding the Lido Rewards-Share Program.
    /// @param receiver The account receiving the stETH tokens.
    function stakeEth(uint256 amount, uint256 maxSharePriceE27, address referral, address receiver)
        external
        payable
        onlyBundler
    {
        if (amount == type(uint256).max) amount = address(this).balance;

        require(amount != 0, ErrorsLib.ZeroAmount());

        uint256 sharesReceived = IStEth(ST_ETH).submit{value: amount}(referral);
        require(amount.rDivUp(sharesReceived) <= maxSharePriceE27, ErrorsLib.SlippageExceeded());

        if (receiver != address(this)) SafeTransferLib.safeTransfer(ERC20(ST_ETH), receiver, amount);
    }

    /// @notice Wraps stETH to wStETH.
    /// @dev stETH must have been previously sent to the module.
    /// @param amount The amount of stEth to wrap. Pass `type(uint).max` to wrap the module's balance.
    /// @param receiver The account receiving the wStETH tokens.
    function wrapStEth(uint256 amount, address receiver) external onlyBundler {
        if (amount == type(uint256).max) amount = ERC20(ST_ETH).balanceOf(address(this));

        require(amount != 0, ErrorsLib.ZeroAmount());

        uint256 received = IWstEth(WST_ETH).wrap(amount);
        if (receiver != address(this) && received > 0) SafeTransferLib.safeTransfer(ERC20(WST_ETH), receiver, received);
    }

    /// @notice Unwraps wStETH to stETH.
    /// @dev wStETH must have been previously sent to the module.
    /// @param amount The amount of wStEth to unwrap. Pass `type(uint).max` to unwrap the module's balance.
    /// @param receiver The account receiving the stETH tokens.
    function unwrapStEth(uint256 amount, address receiver) external onlyBundler {
        if (amount == type(uint256).max) amount = ERC20(WST_ETH).balanceOf(address(this));

        require(amount != 0, ErrorsLib.ZeroAmount());

        uint256 received = IWstEth(WST_ETH).unwrap(amount);
        if (receiver != address(this) && received > 0) SafeTransferLib.safeTransfer(ERC20(ST_ETH), receiver, received);
    }
}
