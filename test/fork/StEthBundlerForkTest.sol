// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IAllowanceTransfer} from "../../lib/permit2/src/interfaces/IAllowanceTransfer.sol";

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

import "../../src/ethereum/EthereumStEthBundler.sol";

import "./helpers/ForkTest.sol";

bytes32 constant BEACON_BALANCE_POSITION = 0xa66d35f054e68143c18f32c990ed5cb972bb68a68f500cd2dd3a16bbf3686483; // keccak256("lido.Lido.beaconBalance");

contract EthereumStEthBundlerMock is TransferBundler, Permit2Bundler, EthereumStEthBundler {}

contract EthereumStEthBundlerForkTest is ForkTest {
    using SafeTransferLib for ERC20;

    function setUp() public override {
        super.setUp();

        if (block.chainid != 1) return;

        bundler = new EthereumStEthBundlerMock();
    }

    function testStakeEthZeroAmount() public onlyEthereum {
        bundle.push(abi.encodeCall(StEthBundler.stakeEth, (0, 0, address(0))));

        vm.expectRevert(bytes(ErrorsLib.ZERO_AMOUNT));
        vm.prank(USER);
        bundler.multicall(bundle);
    }

    function testStakeEth(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, 10_000 ether);

        uint256 shares = IStEth(ST_ETH).getSharesByPooledEth(amount);

        bundle.push(abi.encodeCall(StEthBundler.stakeEth, (amount, shares - 2, address(0))));
        bundle.push(_erc20Transfer(ST_ETH, RECEIVER, type(uint256).max));

        deal(USER, amount);

        vm.prank(USER);
        bundler.multicall{value: amount}(bundle);

        assertEq(USER.balance, 0, "USER.balance");
        assertEq(RECEIVER.balance, 0, "RECEIVER.balance");
        assertEq(address(bundler).balance, 0, "bundler.balance");
        assertEq(ERC20(ST_ETH).balanceOf(USER), 0, "balanceOf(USER)");
        assertApproxEqAbs(ERC20(ST_ETH).balanceOf(address(bundler)), 0, 1, "balanceOf(bundler)");
        assertApproxEqAbs(ERC20(ST_ETH).balanceOf(RECEIVER), amount, 3, "balanceOf(RECEIVER)");
    }

    function testStakeEthSlippageAdapts(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, 10_000 ether);

        uint256 shares = IStEth(ST_ETH).getSharesByPooledEth(amount);

        bundle.push(abi.encodeCall(StEthBundler.stakeEth, (amount, shares - 2, address(0))));
        bundle.push(_erc20Transfer(ST_ETH, USER, type(uint256).max));

        deal(USER, amount / 2);

        vm.prank(USER);
        bundler.multicall{value: amount / 2}(bundle);

        assertApproxEqAbs(ERC20(ST_ETH).balanceOf(USER), amount / 2, 3, "amount");
        assertApproxEqAbs(IStEth(ST_ETH).sharesOf(USER), shares / 2, 2, "shares");
    }

    function testStakeEthSlippageExceeded(uint256 amount) public onlyEthereum {
        amount = bound(amount, MIN_AMOUNT, 10_000 ether);

        uint256 shares = IStEth(ST_ETH).getSharesByPooledEth(amount);

        bundle.push(abi.encodeCall(StEthBundler.stakeEth, (amount, shares - 2, address(0))));

        vm.store(ST_ETH, BEACON_BALANCE_POSITION, bytes32(uint256(vm.load(ST_ETH, BEACON_BALANCE_POSITION)) * 2));

        deal(USER, amount);

        vm.prank(USER);
        vm.expectRevert(bytes(ErrorsLib.SLIPPAGE_EXCEEDED));
        bundler.multicall{value: amount}(bundle);
    }

    function testWrapZeroAmount() public onlyEthereum {
        bundle.push(abi.encodeCall(StEthBundler.wrapStEth, (0)));

        vm.expectRevert(bytes(ErrorsLib.ZERO_AMOUNT));
        vm.prank(USER);
        bundler.multicall(bundle);
    }

    function testWrapStEth(uint256 privateKey, uint256 amount) public onlyEthereum {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        deal(ST_ETH, user, amount);

        amount = ERC20(ST_ETH).balanceOf(user);

        bundle.push(_approve2(privateKey, ST_ETH, amount, 0, false));
        bundle.push(_transferFrom2(ST_ETH, amount));
        bundle.push(_wrapStEth(amount));
        bundle.push(_erc20Transfer(WST_ETH, RECEIVER, type(uint256).max));

        uint256 wstEthExpectedAmount = IStEth(ST_ETH).getSharesByPooledEth(ERC20(ST_ETH).balanceOf(user));

        vm.startPrank(user);
        ERC20(ST_ETH).safeApprove(address(Permit2Lib.PERMIT2), type(uint256).max);

        bundler.multicall(bundle);
        vm.stopPrank();

        assertEq(ERC20(WST_ETH).balanceOf(address(bundler)), 0, "wstEth.balanceOf(bundler)");
        assertEq(ERC20(WST_ETH).balanceOf(user), 0, "wstEth.balanceOf(user)");
        assertApproxEqAbs(ERC20(WST_ETH).balanceOf(RECEIVER), wstEthExpectedAmount, 1, "wstEth.balanceOf(RECEIVER)");

        assertApproxEqAbs(ERC20(ST_ETH).balanceOf(address(bundler)), 0, 1, "wstEth.balanceOf(bundler)");
        assertApproxEqAbs(ERC20(ST_ETH).balanceOf(user), 0, 1, "wstEth.balanceOf(user)");
        assertEq(ERC20(ST_ETH).balanceOf(RECEIVER), 0, "wstEth.balanceOf(RECEIVER)");
    }

    function testUnwrapZeroAmount() public onlyEthereum {
        bundle.push(_unwrapStEth(0));

        vm.expectRevert(bytes(ErrorsLib.ZERO_AMOUNT));
        vm.prank(USER);
        bundler.multicall(bundle);
    }

    function testUnwrapWstEth(uint256 privateKey, uint256 amount) public onlyEthereum {
        address user;
        (privateKey, user) = _boundPrivateKey(privateKey);
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_approve2(privateKey, WST_ETH, amount, 0, false));
        bundle.push(_transferFrom2(WST_ETH, amount));
        bundle.push(_unwrapStEth(amount));
        bundle.push(_erc20Transfer(ST_ETH, RECEIVER, type(uint256).max));

        deal(WST_ETH, user, amount);

        vm.startPrank(user);
        ERC20(WST_ETH).safeApprove(address(Permit2Lib.PERMIT2), type(uint256).max);

        bundler.multicall(bundle);
        vm.stopPrank();

        uint256 expectedUnwrappedAmount = IWstEth(WST_ETH).getStETHByWstETH(amount);

        assertEq(ERC20(WST_ETH).balanceOf(address(bundler)), 0, "wstEth.balanceOf(bundler)");
        assertEq(ERC20(WST_ETH).balanceOf(user), 0, "wstEth.balanceOf(user)");
        assertEq(ERC20(WST_ETH).balanceOf(RECEIVER), 0, "wstEth.balanceOf(RECEIVER)");

        assertApproxEqAbs(ERC20(ST_ETH).balanceOf(address(bundler)), 0, 1, "stEth.balanceOf(bundler)");
        assertEq(ERC20(ST_ETH).balanceOf(user), 0, "stEth.balanceOf(user)");
        assertApproxEqAbs(ERC20(ST_ETH).balanceOf(RECEIVER), expectedUnwrappedAmount, 3, "stEth.balanceOf(RECEIVER)");
    }
}
