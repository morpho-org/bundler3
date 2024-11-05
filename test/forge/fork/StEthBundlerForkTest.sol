// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IAllowanceTransfer} from "../../../lib/permit2/src/interfaces/IAllowanceTransfer.sol";

import "../../../src/libraries/ErrorsLib.sol" as ErrorsLib;

import "../../../src/ethereum/EthereumBundler1.sol";

import "./helpers/ForkTest.sol";

bytes32 constant BEACON_BALANCE_POSITION = 0xa66d35f054e68143c18f32c990ed5cb972bb68a68f500cd2dd3a16bbf3686483; // keccak256("lido.Lido.beaconBalance");

contract EthereumStEthBundlerForkTest is ForkTest {
    using SafeTransferLib for ERC20;

    function setUp() public override {
        super.setUp();

        if (block.chainid != 1) return;

        ethereumBundler1 = new EthereumBundler1(address(hub), DAI, WST_ETH);
    }

    function testStakeEthZeroAmount(address receiver) public onlyEthereum {
        bundle.push(_stakeEth(0, 0, address(0), receiver));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        vm.prank(USER);
        hub.multicall(bundle);
    }

    function testStakeEth(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, 10_000 ether);

        uint256 shares = IStEth(ST_ETH).getSharesByPooledEth(amount);

        bundle.push(_stakeEth(amount, shares - 2, address(0), RECEIVER));

        deal(USER, amount);

        vm.prank(USER);
        hub.multicall{value: amount}(bundle);

        assertEq(USER.balance, 0, "USER.balance");
        assertEq(RECEIVER.balance, 0, "RECEIVER.balance");
        assertEq(address(ethereumBundler1).balance, 0, "ethereumBundler1.balance");
        assertEq(ERC20(ST_ETH).balanceOf(USER), 0, "balanceOf(USER)");
        assertApproxEqAbs(ERC20(ST_ETH).balanceOf(address(ethereumBundler1)), 0, 1, "balanceOf(ethereumBundler1)");
        assertApproxEqAbs(ERC20(ST_ETH).balanceOf(RECEIVER), amount, 3, "balanceOf(RECEIVER)");
    }

    function testStakeEthSlippageAdapts(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, 10_000 ether);

        uint256 shares = IStEth(ST_ETH).getSharesByPooledEth(amount);

        bundle.push(_stakeEth(amount, shares - 2, address(0), USER, amount / 2));

        deal(USER, amount / 2);

        vm.prank(USER);
        hub.multicall{value: amount / 2}(bundle);

        assertApproxEqAbs(ERC20(ST_ETH).balanceOf(USER), amount / 2, 3, "amount");
        assertApproxEqAbs(IStEth(ST_ETH).sharesOf(USER), shares / 2, 2, "shares");
    }

    function testStakeEthSlippageExceeded(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, 10_000 ether);

        uint256 shares = IStEth(ST_ETH).getSharesByPooledEth(amount);

        bundle.push(_stakeEth(amount, shares - 2, address(0), address(ethereumBundler1)));

        vm.store(ST_ETH, BEACON_BALANCE_POSITION, bytes32(uint256(vm.load(ST_ETH, BEACON_BALANCE_POSITION)) * 2));

        deal(USER, amount);

        vm.prank(USER);
        vm.expectRevert(ErrorsLib.SlippageExceeded.selector);
        hub.multicall{value: amount}(bundle);
    }

    function testWrapZeroAmount(address receiver) public onlyEthereum {
        bundle.push(_wrapStEth(0, receiver));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        vm.prank(USER);
        hub.multicall(bundle);
    }

    function testWrapStEth(uint256 privateKey, uint256 amount) public onlyEthereum {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        deal(ST_ETH, user, amount);

        amount = ERC20(ST_ETH).balanceOf(user);

        bundle.push(_approve2(privateKey, ST_ETH, amount, 0, false));
        bundle.push(_transferFrom2(ST_ETH, address(ethereumBundler1), amount));
        bundle.push(_wrapStEth(amount, RECEIVER));

        uint256 wstEthExpectedAmount = IStEth(ST_ETH).getSharesByPooledEth(ERC20(ST_ETH).balanceOf(user));

        vm.startPrank(user);
        ERC20(ST_ETH).safeApprove(address(Permit2Lib.PERMIT2), type(uint256).max);

        hub.multicall(bundle);
        vm.stopPrank();

        assertEq(ERC20(WST_ETH).balanceOf(address(ethereumBundler1)), 0, "wstEth.balanceOf(ethereumBundler1)");
        assertEq(ERC20(WST_ETH).balanceOf(user), 0, "wstEth.balanceOf(user)");
        assertApproxEqAbs(ERC20(WST_ETH).balanceOf(RECEIVER), wstEthExpectedAmount, 1, "wstEth.balanceOf(RECEIVER)");

        assertApproxEqAbs(
            ERC20(ST_ETH).balanceOf(address(ethereumBundler1)), 0, 1, "wstEth.balanceOf(ethereumBundler1)"
        );
        assertApproxEqAbs(ERC20(ST_ETH).balanceOf(user), 0, 1, "wstEth.balanceOf(user)");
        assertEq(ERC20(ST_ETH).balanceOf(RECEIVER), 0, "wstEth.balanceOf(RECEIVER)");
    }

    function testUnwrapZeroAmount(address receiver) public onlyEthereum {
        bundle.push(_unwrapStEth(0, receiver));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        vm.prank(USER);
        hub.multicall(bundle);
    }

    function testUnwrapWstEth(uint256 privateKey, uint256 amount) public onlyEthereum {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_approve2(privateKey, WST_ETH, amount, 0, false));
        bundle.push(_transferFrom2(WST_ETH, address(ethereumBundler1), amount));
        bundle.push(_unwrapStEth(amount, RECEIVER));

        deal(WST_ETH, user, amount);

        vm.startPrank(user);
        ERC20(WST_ETH).safeApprove(address(Permit2Lib.PERMIT2), type(uint256).max);

        hub.multicall(bundle);
        vm.stopPrank();

        uint256 expectedUnwrappedAmount = IWstEth(WST_ETH).getStETHByWstETH(amount);

        assertEq(ERC20(WST_ETH).balanceOf(address(ethereumBundler1)), 0, "wstEth.balanceOf(ethereumBundler1)");
        assertEq(ERC20(WST_ETH).balanceOf(user), 0, "wstEth.balanceOf(user)");
        assertEq(ERC20(WST_ETH).balanceOf(RECEIVER), 0, "wstEth.balanceOf(RECEIVER)");

        assertApproxEqAbs(ERC20(ST_ETH).balanceOf(address(ethereumBundler1)), 0, 1, "stEth.balanceOf(ethereumBundler1)");
        assertEq(ERC20(ST_ETH).balanceOf(user), 0, "stEth.balanceOf(user)");
        assertApproxEqAbs(ERC20(ST_ETH).balanceOf(RECEIVER), expectedUnwrappedAmount, 3, "stEth.balanceOf(RECEIVER)");
    }
}
