// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../../../src/libraries/ErrorsLib.sol";

import "./helpers/ForkTest.sol";

error InvalidNonce();

contract Permit2BundlerForkTest is ForkTest {
    using SafeTransferLib for ERC20;

    function testApprove2(uint256 seed, uint256 privateKey, uint256 deadline, uint256 amount) public {
        privateKey = bound(privateKey, 1, type(uint160).max);
        deadline = bound(deadline, block.timestamp, type(uint48).max);
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        address user = vm.addr(privateKey);
        MarketParams memory marketParams = _randomMarketParams(seed);

        bundle.push(_approve2(privateKey, marketParams.loanToken, amount, 0, false));
        bundle.push(_approve2(privateKey, marketParams.loanToken, amount, 0, true));

        vm.startPrank(user);
        ERC20(marketParams.loanToken).safeApprove(address(Permit2Lib.PERMIT2), type(uint256).max);

        hub.multicall(bundle);
        vm.stopPrank();

        (uint160 permit2Allowance,,) = Permit2Lib.PERMIT2.allowance(user, marketParams.loanToken, address(bundler));

        assertEq(permit2Allowance, amount, "PERMIT2.allowance(user, bundler)");
        assertEq(ERC20(marketParams.loanToken).allowance(user, address(bundler)), 0, "loan.allowance(user, bundler)");
    }

    function testApprove2Unauthorized() public {
        IAllowanceTransfer.PermitSingle memory permitSingle;
        bytes memory signature;

        vm.expectRevert(bytes(ErrorsLib.UNAUTHORIZED_SENDER));
        Permit2Bundler(address(bundler)).approve2(permitSingle, signature, false);
    }

    function testApprove2InvalidNonce(uint256 seed, uint256 privateKey, uint256 deadline, uint256 amount) public {
        privateKey = bound(privateKey, 1, type(uint160).max);
        deadline = bound(deadline, block.timestamp, type(uint48).max);
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        address user = vm.addr(privateKey);
        MarketParams memory marketParams = _randomMarketParams(seed);

        bundle.push(_approve2(privateKey, marketParams.loanToken, amount, 0, false));
        bundle.push(_approve2(privateKey, marketParams.loanToken, amount, 0, false));

        vm.prank(user);
        vm.expectRevert(InvalidNonce.selector);
        hub.multicall(bundle);
    }

    function testTransferFrom2ZeroAmount() public {
        bundle.push(_transferFrom2(DAI, 0));

        vm.expectRevert(bytes(ErrorsLib.ZERO_AMOUNT));
        hub.multicall(bundle);
    }

    function testTransferFrom2Unauthorized() public {
        vm.expectRevert(bytes(ErrorsLib.UNAUTHORIZED_SENDER));
        Permit2Bundler(address(bundler)).transferFrom2(address(0), address(0), 0);
    }
}
