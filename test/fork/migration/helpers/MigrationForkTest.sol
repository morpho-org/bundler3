// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IERC20, SafeERC20} from "../../../../src/adapters/CoreAdapter.sol";
import {MarketParamsLib} from "../../../../lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import {MorphoLib} from "../../../../lib/morpho-blue/src/libraries/periphery/MorphoLib.sol";
import {Market} from "../../../../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {MorphoBalancesLib} from "../../../../lib/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";

import "../../helpers/ForkTest.sol";
import {ERC4626Mock} from "../../../helpers/mocks/ERC4626Mock.sol";

contract MigrationForkTest is ForkTest {
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    MarketParams internal marketParams;
    ERC4626Mock internal suppliersVault;

    function _initMarket(address collateral, address loan) internal {
        marketParams.collateralToken = collateral;
        marketParams.loanToken = loan;
        marketParams.oracle = address(oracle);
        marketParams.irm = address(irm);
        marketParams.lltv = 0.8 ether;

        Market memory market = morpho.market(marketParams.id());
        if (market.lastUpdate == 0) morpho.createMarket(marketParams);

        suppliersVault = new ERC4626Mock(marketParams.loanToken, "suppliers vault", "vault");
        vm.label(address(suppliersVault), "Suppliers Vault");
    }

    function _provideLiquidity(uint256 liquidity) internal {
        deal(marketParams.loanToken, address(this), liquidity);
        SafeERC20.forceApprove(IERC20(marketParams.loanToken), address(morpho), liquidity);
        morpho.supply(marketParams, liquidity, 0, address(this), hex"");
    }

    function _assertBorrowerPosition(uint256 collateralSupplied, uint256 borrowed, address user, address adapter)
        internal
        view
    {
        assertEq(morpho.expectedSupplyAssets(marketParams, user), 0, "supply != 0");
        assertEq(morpho.collateral(marketParams.id(), user), collateralSupplied, "wrong collateral supply amount");
        assertEq(morpho.expectedBorrowAssets(marketParams, user), borrowed, "wrong borrow amount");
        assertFalse(morpho.isAuthorized(user, adapter), "authorization not revoked");
    }

    function _assertSupplierPosition(uint256 supplied, address user, address adapter) internal view {
        assertEq(morpho.expectedSupplyAssets(marketParams, user), supplied, "wrong supply amount");
        assertEq(morpho.collateral(marketParams.id(), user), 0, "collateral supplied != 0");
        assertEq(morpho.expectedBorrowAssets(marketParams, user), 0, "borrow != 0");
        assertFalse(morpho.isAuthorized(user, adapter), "authorization not revoked");
    }

    function _assertVaultSupplierPosition(uint256 supplied, address user, address adapter) internal view {
        uint256 shares = suppliersVault.balanceOf(user);
        assertEq(suppliersVault.convertToAssets(shares), supplied, "wrong supply amount");
        assertFalse(morpho.isAuthorized(user, adapter), "authorization not revoked");
    }
}
