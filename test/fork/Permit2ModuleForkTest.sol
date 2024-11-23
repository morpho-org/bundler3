// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

import "./helpers/ForkTest.sol";
import {ERC20Mock} from "../../src/mocks/ERC20Mock.sol";

error InvalidNonce();

contract Permit2ModuleForkTest is ForkTest {
    using SafeTransferLib for ERC20;

    address internal DAI = config.getAddress("DAI");

    function testApprove2(uint256 seed, uint256 privateKey, uint256 amount) public {
        privateKey = bound(privateKey, 1, type(uint160).max);
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        address user = vm.addr(privateKey);
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

    function testApprove2Batch(uint256 privateKey, uint256 amount0, uint256 amount1) public {
        privateKey = bound(privateKey, 1, type(uint160).max);
        amount0 = bound(amount0, MIN_AMOUNT, MAX_AMOUNT);
        amount1 = bound(amount1, MIN_AMOUNT, MAX_AMOUNT);

        address user = vm.addr(privateKey);
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

    function testApprove2Unauthorized() public {
        IAllowanceTransfer.PermitSingle memory permitSingle;
        bytes memory signature;

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.UnauthorizedSender.selector, address(this)));
        genericModule1.approve2(permitSingle, signature, false);
    }

    function testApprove2BatchUnauthorized() public {
        IAllowanceTransfer.PermitBatch memory permitBatch;
        bytes memory signature;

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.UnauthorizedSender.selector, (address(this))));
        genericModule1.approve2Batch(permitBatch, signature, false);
    }

    function testApprove2InvalidNonce(uint256 seed, uint256 privateKey, uint256 amount) public {
        privateKey = bound(privateKey, 1, type(uint160).max);
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        address user = vm.addr(privateKey);
        MarketParams memory marketParams = _randomMarketParams(seed);

        bundle.push(_approve2(privateKey, marketParams.loanToken, amount, 0, false));
        bundle.push(_approve2(privateKey, marketParams.loanToken, amount, 0, false));

        vm.prank(user);
        vm.expectRevert(InvalidNonce.selector);
        bundler.multicall(bundle);
    }

    function testApprove2BatchInvalidNonce(uint256 privateKey, uint256 amount0, uint256 amount1) public {
        privateKey = bound(privateKey, 1, type(uint160).max);
        amount0 = bound(amount0, MIN_AMOUNT, MAX_AMOUNT);
        amount1 = bound(amount1, MIN_AMOUNT, MAX_AMOUNT);

        address user = vm.addr(privateKey);
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
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.UnauthorizedSender.selector, address(this)));
        genericModule1.transferFrom2(address(0), address(0), 0);
    }
}
