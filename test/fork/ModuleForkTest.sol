// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IAllowanceTransfer} from "../../lib/permit2/src/interfaces/IAllowanceTransfer.sol";

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

import "./helpers/ForkTest.sol";

contract EthereumModuleForkTest is ForkTest {
    using MathLib for uint256;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;
    using SafeTransferLib for ERC20;

    function testSupplyWithPermit2(uint256 seed, uint256 amount, address onBehalf, uint256 deadline) public {
        (uint256 privateKey, address user) = _boundPrivateKey(pickUint());

        vm.assume(onBehalf != address(0));
        vm.assume(onBehalf != address(morpho));
        vm.assume(onBehalf != address(genericModule1));

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        privateKey = bound(privateKey, 1, type(uint160).max);
        deadline = bound(deadline, block.timestamp, type(uint48).max);

        MarketParams memory marketParams = _randomMarketParams(seed);

        bundle.push(_approve2(privateKey, marketParams.loanToken, amount, 0, false));
        bundle.push(_transferFrom2(marketParams.loanToken, amount));
        bundle.push(_morphoSupply(marketParams, amount, 0, 0, onBehalf, hex""));

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

    function testProtectedFailure(address initiator, address module, address caller) public {
        vm.assume(initiator != address(0));
        vm.assume(caller != initiator);
        vm.assume(caller != module);

        _delegatePrank(address(bundler), abi.encodeCall(FunctionMocker.setCurrentModule, (module)));
        _delegatePrank(address(bundler), abi.encodeCall(FunctionMocker.setInitiator, (initiator)));

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.UnauthorizedSender.selector, caller));
        vm.prank(caller);
        bundler.multicallFromModule(new Call[](0));
    }

    function testProtectedSuccessAsModule(address initiator, address module) public {
        vm.assume(initiator != address(0));
        vm.assume(initiator != module);

        _delegatePrank(address(bundler), abi.encodeCall(FunctionMocker.setInitiator, (initiator)));
        _delegatePrank(address(bundler), abi.encodeCall(FunctionMocker.setCurrentModule, (module)));

        vm.prank(module);
        bundler.multicallFromModule(new Call[](0));
    }
}
