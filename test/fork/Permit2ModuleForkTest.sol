// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

import "./helpers/ForkTest.sol";
import {ERC20Mock} from "../helpers/mocks/ERC20Mock.sol";

error InvalidNonce();

contract Permit2ModuleForkTest is ForkTest {
    using SafeTransferLib for ERC20;
    using MarketParamsLib for MarketParams;
    using MorphoBalancesLib for IMorpho;
    using MorphoLib for IMorpho;

    address internal DAI = getAddress("DAI");

    function testSupplyWithPermit2(uint256 seed, uint256 amount, address onBehalf, uint256 deadline) public {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);

        vm.assume(onBehalf != address(0));
        vm.assume(onBehalf != address(morpho));
        vm.assume(onBehalf != address(genericModule1));

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        privateKey = bound(privateKey, 1, type(uint160).max);
        deadline = bound(deadline, block.timestamp, type(uint48).max);

        MarketParams memory marketParams = _randomMarketParams(seed);

        bundle.push(_approve2(privateKey, marketParams.loanToken, amount, 0, false));
        bundle.push(_transferFrom2(marketParams.loanToken, amount));
        bundle.push(_morphoSupply(marketParams, amount, 0, type(uint256).max, onBehalf, hex""));

        uint256 collateralBalanceBefore = ERC20(marketParams.collateralToken).balanceOf(onBehalf);
        uint256 loanBalanceBefore = ERC20(marketParams.loanToken).balanceOf(onBehalf);

        deal(marketParams.loanToken, user, amount);

        vm.startPrank(user);
        ERC20(marketParams.loanToken).safeApprove(address(Permit2Lib.PERMIT2), type(uint256).max);
        ERC20(marketParams.collateralToken).safeApprove(address(Permit2Lib.PERMIT2), type(uint256).max);

        bundler.multicall(bundle);
        vm.stopPrank();

        assertEq(ERC20(marketParams.collateralToken).balanceOf(user), 0, "collateral.balanceOf(user)");
        assertEq(ERC20(marketParams.loanToken).balanceOf(user), 0, "loan.balanceOf(user)");

        assertEq(
            ERC20(marketParams.collateralToken).balanceOf(onBehalf),
            collateralBalanceBefore,
            "collateral.balanceOf(onBehalf)"
        );
        assertEq(ERC20(marketParams.loanToken).balanceOf(onBehalf), loanBalanceBefore, "loan.balanceOf(onBehalf)");

        Id id = marketParams.id();

        assertEq(morpho.collateral(id, onBehalf), 0, "collateral(onBehalf)");
        assertEq(morpho.supplyShares(id, onBehalf), amount * SharesMathLib.VIRTUAL_SHARES, "supplyShares(onBehalf)");
        assertEq(morpho.borrowShares(id, onBehalf), 0, "borrowShares(onBehalf)");

        if (onBehalf != user) {
            assertEq(morpho.collateral(id, user), 0, "collateral(user)");
            assertEq(morpho.supplyShares(id, user), 0, "supplyShares(user)");
            assertEq(morpho.borrowShares(id, user), 0, "borrowShares(user)");
        }
    }

    function testApprove2(uint256 seed, uint256 amount) public {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        MarketParams memory marketParams = _randomMarketParams(seed);

        bundle.push(_approve2(privateKey, marketParams.loanToken, amount, 0, false));
        bundle.push(_approve2(privateKey, marketParams.loanToken, amount, 0, true));

        vm.startPrank(user);
        ERC20(marketParams.loanToken).safeApprove(address(Permit2Lib.PERMIT2), type(uint256).max);

        bundler.multicall(bundle);
        vm.stopPrank();

        (uint160 permit2Allowance,,) =
            Permit2Lib.PERMIT2.allowance(user, marketParams.loanToken, address(genericModule1));

        assertEq(permit2Allowance, amount, "PERMIT2.allowance(user, genericModule1)");
        assertEq(
            ERC20(marketParams.loanToken).allowance(user, address(genericModule1)),
            0,
            "loan.allowance(user, genericModule1)"
        );
    }

    function testApprove2Batch(uint256 amount0, uint256 amount1) public {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);
        amount0 = bound(amount0, MIN_AMOUNT, MAX_AMOUNT);
        amount1 = bound(amount1, MIN_AMOUNT, MAX_AMOUNT);

        address token0 = address(new ERC20Mock("Token 0", "T0"));
        address token1 = address(new ERC20Mock("Token 1", "T1"));

        address[] memory assets = new address[](2);
        assets[0] = token0;
        assets[1] = token1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;

        uint256[] memory nonces = new uint256[](2);
        nonces[0] = 0;
        nonces[1] = 0;

        bundle.push(_approve2Batch(privateKey, assets, amounts, nonces, false));
        bundle.push(_approve2Batch(privateKey, assets, amounts, nonces, true));

        vm.startPrank(user);
        ERC20(token0).safeApprove(address(Permit2Lib.PERMIT2), type(uint256).max);
        ERC20(token1).safeApprove(address(Permit2Lib.PERMIT2), type(uint256).max);

        bundler.multicall(bundle);
        vm.stopPrank();

        (uint160 permit2Allowance1,,) = Permit2Lib.PERMIT2.allowance(user, token0, address(genericModule1));

        (uint160 permit2Allowance2,,) = Permit2Lib.PERMIT2.allowance(user, token1, address(genericModule1));

        assertEq(permit2Allowance1, amount0, "PERMIT2.allowance(user, asset 1, genericModule1)");
        assertEq(permit2Allowance2, amount1, "PERMIT2.allowance(user, asset 2,genericModule1)");
        assertEq(
            ERC20(token0).allowance(user, address(genericModule1)), 0, "loan.allowance(user, asset 1, genericModule1)"
        );
        assertEq(
            ERC20(token1).allowance(user, address(genericModule1)), 0, "loan.allowance(user, asset 2, genericModule1)"
        );
    }

    function testApprove2InvalidNonce(uint256 seed, uint256 amount) public {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        MarketParams memory marketParams = _randomMarketParams(seed);

        bundle.push(_approve2(privateKey, marketParams.loanToken, amount, 0, false));
        bundle.push(_approve2(privateKey, marketParams.loanToken, amount, 0, false));

        vm.prank(user);
        vm.expectRevert(InvalidNonce.selector);
        bundler.multicall(bundle);
    }

    function testApprove2BatchInvalidNonce(uint256 amount0, uint256 amount1) public {
        uint256 privateKey = _boundPrivateKey(pickUint());
        address user = vm.addr(privateKey);
        amount0 = bound(amount0, MIN_AMOUNT, MAX_AMOUNT);
        amount1 = bound(amount1, MIN_AMOUNT, MAX_AMOUNT);

        address token0 = address(new ERC20Mock("Token 0", "T0"));
        address token1 = address(new ERC20Mock("Token 1", "T1"));

        address[] memory assets = new address[](2);
        assets[0] = token0;
        assets[1] = token1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;

        uint256[] memory nonces = new uint256[](2);
        nonces[0] = 0;
        nonces[1] = 0;

        bundle.push(_approve2Batch(privateKey, assets, amounts, nonces, false));
        bundle.push(_approve2Batch(privateKey, assets, amounts, nonces, false));

        vm.prank(user);
        vm.expectRevert(InvalidNonce.selector);
        bundler.multicall(bundle);
    }

    function testTransferFrom2ZeroAmount() public {
        bundle.push(_transferFrom2(DAI, 0));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler.multicall(bundle);
    }

    function testTransferFrom2Unauthorized() public {
        vm.expectRevert(ErrorsLib.UnauthorizedSender.selector);
        genericModule1.transferFrom2(address(0), address(0), 0);
    }
}
