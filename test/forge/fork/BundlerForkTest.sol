// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IAllowanceTransfer} from "../../../lib/permit2/src/interfaces/IAllowanceTransfer.sol";

import {EthereumBundlerV2} from "../../../src/ethereum/EthereumBundlerV2.sol";
import {ChainAgnosticBundlerV2} from "../../../src/chain-agnostic/ChainAgnosticBundlerV2.sol";
import {BaseMorphoBundlerModuleTest} from "../BaseMorphoBundlerModuleTest.sol";
import {ErrorsLib} from "../../../src/libraries/ErrorsLib.sol";

import "./helpers/ForkTest.sol";

contract EthereumBundlerForkTest is ForkTest {
    using MathLib for uint256;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;
    using SafeTransferLib for ERC20;

    function testSupplyWithPermit2(uint256 seed, uint256 amount, address onBehalf, uint256 privateKey, uint256 deadline)
        public
    {
        vm.assume(onBehalf != address(0));
        vm.assume(onBehalf != address(morpho));
        vm.assume(onBehalf != address(bundler));

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        privateKey = bound(privateKey, 1, type(uint160).max);
        deadline = bound(deadline, block.timestamp, type(uint48).max);

        address user = vm.addr(privateKey);
        MarketParams memory marketParams = _randomMarketParams(seed);

        bundle.push(_approve2(privateKey, marketParams.loanToken, amount, 0, false));
        bundle.push(_transferFrom2(marketParams.loanToken, amount));
        bundle.push(_morphoSupply(marketParams, amount, 0, 0, onBehalf));

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

    function testProtectedFailure(address initiator, address _module, address caller) public {
        vm.assume(initiator != address(0));
        vm.assume(caller != initiator);
        vm.assume(caller != _module);
        vm.assume(caller != address(morpho));

        _usePoser(address(bundler), abi.encodeCall(Poser.setCurrentModule,(_module)));
        _usePoser(address(bundler), abi.encodeCall(Poser.setInitiator,(initiator)));

        deal(DAI,address(morpho),1);

        vm.expectRevert(bytes(ErrorsLib.UNAUTHORIZED_SENDER));
        vm.prank(caller);
        MorphoBundler(address(bundler)).morphoFlashLoan(DAI,1,abi.encode(new bytes[](0)));
    }

    function testProtectedSuccessAsModule(address initiator, address _module) public {
        vm.assume(initiator != address(0));
        vm.assume(initiator != _module);

        _usePoser(address(bundler), abi.encodeCall(Poser.setInitiator,(initiator)));
        _usePoser(address(bundler), abi.encodeCall(Poser.setCurrentModule,(_module)));

        deal(DAI,address(morpho),1);

        vm.prank(_module);
        MorphoBundler(address(bundler)).morphoFlashLoan(DAI,1,abi.encode(new bytes[](0)));
    }

    function testProtectedSuccessAsMorpho(address initiator) public {
        vm.assume(initiator != address(0));
        vm.assume(initiator != address(morpho));

        _usePoser(address(bundler),abi.encodeCall(Poser.setInitiator,(initiator)));

        deal(DAI,address(morpho),1);
        vm.prank(address(morpho));
        MorphoBundler(address(bundler)).morphoFlashLoan(DAI,1,abi.encode(new bytes[](0)));
    }

}
