// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import {MarketParams, IMorpho} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IWNative} from "./IWNative.sol";
import {IBaseModule} from "./IBaseModule.sol";

/// @custom:contact security@morpho.org
/// @notice Interface of chain agnostic module contract n°1.
interface IGenericModule1 is IBaseModule {
    function MORPHO() external view returns (IMorpho);
    function WRAPPED_NATIVE() external view returns (IWNative);

    function erc20WrapperDepositFor(address wrapper, address receiver, uint256 amount) external;
    function erc20WrapperWithdrawTo(address wrapper, address receiver, uint256 amount) external;
    function erc4626Mint(address vault, uint256 shares, uint256 maxSharePriceE27, address receiver) external;
    function erc4626Deposit(address vault, uint256 assets, uint256 maxSharePriceE27, address receiver) external;
    function erc4626Withdraw(address vault, uint256 assets, uint256 minSharePriceE27, address receiver, address owner)
        external;
    function erc4626Redeem(address vault, uint256 shares, uint256 minSharePriceE27, address receiver, address owner)
        external;
    function onMorphoSupply(uint256, bytes calldata data) external;
    function onMorphoSupplyCollateral(uint256, bytes calldata data) external;
    function onMorphoRepay(uint256, bytes calldata data) external;
    function onMorphoFlashLoan(uint256, bytes calldata data) external;
    function morphoSupply(
        MarketParams calldata marketParams,
        uint256 assets,
        uint256 shares,
        uint256 maxSharePriceE27,
        address onBehalf,
        bytes calldata data
    ) external;
    function morphoSupplyCollateral(
        MarketParams calldata marketParams,
        uint256 assets,
        address onBehalf,
        bytes calldata data
    ) external;
    function morphoBorrow(
        MarketParams calldata marketParams,
        uint256 assets,
        uint256 shares,
        uint256 minSharePriceE27,
        address receiver
    ) external;
    function morphoRepay(
        MarketParams calldata marketParams,
        uint256 assets,
        uint256 shares,
        uint256 maxSharePriceE27,
        address onBehalf,
        bytes calldata data
    ) external;
    function morphoWithdraw(
        MarketParams calldata marketParams,
        uint256 assets,
        uint256 shares,
        uint256 minSharePriceE27,
        address receiver
    ) external;
    function morphoWithdrawCollateral(MarketParams calldata marketParams, uint256 assets, address receiver) external;
    function morphoFlashLoan(address token, uint256 assets, bytes calldata data) external;
    function transferFrom2(address token, address receiver, uint256 amount) external;
    function erc20TransferFrom(address token, address receiver, uint256 amount) external;
    function wrapNative(uint256 amount, address receiver) external;
    function unwrapNative(uint256 amount, address receiver) external;
}
