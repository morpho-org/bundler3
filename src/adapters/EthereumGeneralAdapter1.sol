// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IWstEth} from "../interfaces/IWstEth.sol";
import {IStEth} from "../interfaces/IStEth.sol";

import {GeneralAdapter1, CoreAdapter, ErrorsLib, SafeERC20, IERC20} from "./GeneralAdapter1.sol";
import {ERC20Wrapper} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import {MathRayLib} from "../libraries/MathRayLib.sol";

/// @custom:security-contact security@morpho.org
/// @notice Adapter contract specific to Ethereum n°1.
contract EthereumGeneralAdapter1 is GeneralAdapter1 {
    using MathRayLib for uint256;

    /* IMMUTABLES */

    /// @dev The address of the stETH token.
    address public immutable ST_ETH;

    /// @dev The address of the wstETH token.
    address public immutable WST_ETH;

    /// @notice The address of the Morpho token.
    address public immutable MORPHO_TOKEN;

    /// @notice The address of the wrapper.
    address public immutable MORPHO_WRAPPER;

    /// @notice The address of the BundlerV2, to prevent unauthorized transfers.
    address public immutable BUNDLER_V2;

    /* CONSTRUCTOR */

    /// @param bundler3 The address of the Bundler3 contract.
    /// @param bundlerV2 The address of the BundlerV3 contract.
    /// @param morpho The address of Morpho.
    /// @param weth The address of the WETH token.
    /// @param wStEth The address of the wstETH token.
    /// @param morphoToken The address of the MORPHO token.
    /// @param morphoWrapper The address of the MORPHO token wrapper.
    constructor(
        address bundler3,
        address bundlerV2,
        address morpho,
        address weth,
        address wStEth,
        address morphoToken,
        address morphoWrapper
    ) GeneralAdapter1(bundler3, morpho, weth) {
        require(wStEth != address(0), ErrorsLib.ZeroAddress());
        require(morphoToken != address(0), ErrorsLib.ZeroAddress());
        require(morphoWrapper != address(0), ErrorsLib.ZeroAddress());
        require(bundlerV2 != address(0), ErrorsLib.ZeroAddress());

        ST_ETH = IWstEth(wStEth).stETH();
        WST_ETH = wStEth;
        MORPHO_TOKEN = morphoToken;
        MORPHO_WRAPPER = morphoWrapper;
        BUNDLER_V2 = bundlerV2;
    }

    /* MORPHO TOKEN WRAPPER ACTIONS */

    /// @notice Unwraps Morpho tokens.
    /// @dev Separated from the erc20WrapperWithdrawTo function because the Morpho wrapper is separated from the
    /// wrapped token, so it does not have a balanceOf function, and the wrapped token needs to be approved before
    /// withdrawTo.
    /// @param receiver The address to send the tokens to.
    /// @param amount The amount of tokens to unwrap.
    function morphoWrapperWithdrawTo(address receiver, uint256 amount) external onlyBundler3 {
        // Do not check `receiver` against the zero address as it's done at the Morpho Wrapper's level.
        if (amount == type(uint256).max) amount = IERC20(MORPHO_TOKEN).balanceOf(address(this));

        require(amount != 0, ErrorsLib.ZeroAmount());

        // The MORPHO wrapper's allowance is not reset as it is trusted.
        SafeERC20.forceApprove(IERC20(MORPHO_TOKEN), MORPHO_WRAPPER, type(uint256).max);

        require(ERC20Wrapper(MORPHO_WRAPPER).withdrawTo(receiver, amount), ErrorsLib.WithdrawFailed());
    }

    /* LIDO ACTIONS */

    /// @notice Stakes ETH via Lido.
    /// @dev ETH must have been previously sent to the adapter.
    /// @param amount The amount of ETH to stake. Pass `type(uint).max` to repay the adapter's ETH balance.
    /// @param maxSharePriceE27 The maximum amount of wei to pay for minting 1 share, scaled by 1e27.
    /// @param referral The address of the referral regarding the Lido Rewards-Share Program.
    /// @param receiver The account receiving the stETH tokens.
    function stakeEth(uint256 amount, uint256 maxSharePriceE27, address referral, address receiver)
        external
        onlyBundler3
    {
        if (amount == type(uint256).max) amount = address(this).balance;

        require(amount != 0, ErrorsLib.ZeroAmount());

        uint256 sharesReceived = IStEth(ST_ETH).submit{value: amount}(referral);
        require(amount.rDivUp(sharesReceived) <= maxSharePriceE27, ErrorsLib.SlippageExceeded());

        if (receiver != address(this)) SafeERC20.safeTransfer(IERC20(ST_ETH), receiver, amount);
    }

    /// @notice Wraps stETH to wStETH.
    /// @dev stETH must have been previously sent to the adapter.
    /// @param amount The amount of stEth to wrap. Pass `type(uint).max` to wrap the adapter's balance.
    /// @param receiver The account receiving the wStETH tokens.
    function wrapStEth(uint256 amount, address receiver) external onlyBundler3 {
        if (amount == type(uint256).max) amount = IERC20(ST_ETH).balanceOf(address(this));

        require(amount != 0, ErrorsLib.ZeroAmount());

        // The wStEth's allowance is not reset as it is trusted.
        SafeERC20.forceApprove(IERC20(ST_ETH), WST_ETH, type(uint256).max);

        uint256 received = IWstEth(WST_ETH).wrap(amount);

        if (receiver != address(this) && received > 0) SafeERC20.safeTransfer(IERC20(WST_ETH), receiver, received);
    }

    /// @notice Unwraps wStETH to stETH.
    /// @dev wStETH must have been previously sent to the adapter.
    /// @param amount The amount of wStEth to unwrap. Pass `type(uint).max` to unwrap the adapter's balance.
    /// @param receiver The account receiving the stETH tokens.
    function unwrapStEth(uint256 amount, address receiver) external onlyBundler3 {
        if (amount == type(uint256).max) amount = IERC20(WST_ETH).balanceOf(address(this));

        require(amount != 0, ErrorsLib.ZeroAmount());

        uint256 received = IWstEth(WST_ETH).unwrap(amount);
        if (receiver != address(this) && received > 0) SafeERC20.safeTransfer(IERC20(ST_ETH), receiver, received);
    }

    /* ERC20 ACTIONS */

    /// @inheritdoc CoreAdapter
    function erc20Transfer(address token, address receiver, uint256 amount) public override onlyBundler3 {
        require(receiver != BUNDLER_V2, ErrorsLib.ERC20TransferToBundlerV2());
        super.erc20Transfer(token, receiver, amount);
    }
}
