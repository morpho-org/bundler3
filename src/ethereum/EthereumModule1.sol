// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {IDaiPermit} from "./interfaces/IDaiPermit.sol";
import {IWstEth} from "../interfaces/IWstEth.sol";
import {IStEth} from "../interfaces/IStEth.sol";

import {
    GenericModule1,
    BaseModule,
    ErrorsLib,
    ERC20Wrapper,
    ModuleLib,
    SafeTransferLib,
    ERC20
} from "../GenericModule1.sol";
import {MathRayLib} from "../libraries/MathRayLib.sol";

/// @title EthereumModule1
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Module contract specific to Ethereum n°1.
contract EthereumModule1 is GenericModule1 {
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
    ) GenericModule1(bundler, morpho, weth) {
        require(dai != address(0), ErrorsLib.ZeroAddress());
        require(wStEth != address(0), ErrorsLib.ZeroAddress());
        require(morphoToken != address(0), ErrorsLib.ZeroAddress());
        require(morphoWrapper != address(0), ErrorsLib.ZeroAddress());

        DAI = dai;
        ST_ETH = IWstEth(wStEth).stETH();
        WST_ETH = wStEth;
        MORPHO_TOKEN = morphoToken;
        MORPHO_WRAPPER = morphoWrapper;

        ModuleLib.approveMaxToIfAllowanceZero(ST_ETH, WST_ETH);
        ModuleLib.approveMaxToIfAllowanceZero(MORPHO_TOKEN, MORPHO_WRAPPER);
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

    /* DAI PERMIT ACTIONS */

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
    ) external onlyBundler {
        try IDaiPermit(DAI).permit(initiator(), spender, nonce, expiry, allowed, v, r, s) {}
        catch (bytes memory returnData) {
            if (!skipRevert) ModuleLib.lowLevelRevert(returnData);
        }
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

        SafeTransferLib.safeTransfer(ERC20(ST_ETH), receiver, amount);
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
