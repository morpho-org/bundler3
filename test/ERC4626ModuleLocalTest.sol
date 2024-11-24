// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";
import {ERC4626Mock} from "../src/mocks/ERC4626Mock.sol";
import {MathRayLib} from "../src/libraries/MathRayLib.sol";

import "./helpers/LocalTest.sol";

contract ERC4626ModuleLocalTest is LocalTest {
    using BundlerLib for Bundler;
    using MathRayLib for uint256;

    ERC4626Mock internal vault;

    function setUp() public override {
        super.setUp();

        vault = new ERC4626Mock(address(loanToken), "LoanToken Vault", "BV");

        vm.startPrank(USER);
        vault.approve(address(genericModule1), type(uint256).max);
        loanToken.approve(address(genericModule1), type(uint256).max);
        loanToken.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function test4626MintUnauthorized(uint256 shares) public {
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.UnauthorizedSender.selector, address(this)));
        genericModule1.erc4626Mint(address(vault), 0, shares, RECEIVER);
    }

    function testErc4626MintZeroAdressVault(uint256 shares) public {
        bundle.push(_erc4626Mint(address(0), shares, type(uint256).max, RECEIVER));

        vm.expectRevert();
        bundler.multicall(bundle);
    }

    function testErc4626MintZeroAdress(uint256 shares) public {
        bundle.push(_erc4626Mint(address(vault), shares, type(uint256).max, address(0)));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        bundler.multicall(bundle);
    }

    function test4626DepositUnauthorized(uint256 assets) public {
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.UnauthorizedSender.selector, address(this)));
        genericModule1.erc4626Deposit(address(vault), assets, type(uint256).max, RECEIVER);
    }

    function testErc4626DepositZeroAdressVault(uint256 assets) public {
        bundle.push(_erc4626Deposit(address(0), assets, type(uint256).max, RECEIVER));

        vm.expectRevert();
        bundler.multicall(bundle);
    }

    function testErc4626DepositZeroAdress(uint256 assets) public {
        bundle.push(_erc4626Deposit(address(vault), assets, type(uint256).max, address(0)));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        bundler.multicall(bundle);
    }

    function test4626WithdrawUnauthorized(uint256 assets) public {
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.UnauthorizedSender.selector, address(this)));
        genericModule1.erc4626Withdraw(address(vault), assets, 0, RECEIVER, address(genericModule1));
    }

    function testErc4626WithdrawZeroAdressVault(uint256 assets) public {
        bundle.push(_erc4626Withdraw(address(0), assets, 0, RECEIVER, address(genericModule1)));

        vm.expectRevert();
        bundler.multicall(bundle);
    }

    function testErc4626WithdrawUnexpectedOwner(uint256 assets, address owner) public {
        vm.assume(owner != address(this) && owner != address(genericModule1));

        bundle.push(_erc4626Withdraw(address(vault), assets, 0, RECEIVER, owner));

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.UnexpectedOwner.selector, owner));
        bundler.multicall(bundle);
    }

    function testErc4626WithdrawZeroAdress(uint256 assets) public {
        bundle.push(_erc4626Withdraw(address(vault), assets, 0, address(0), address(genericModule1)));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        bundler.multicall(bundle);
    }

    function test4626RedeemUnauthorized(uint256 shares) public {
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.UnauthorizedSender.selector, address(this)));
        genericModule1.erc4626Redeem(address(vault), shares, 0, RECEIVER, address(genericModule1));
    }

    function testErc4626RedeemZeroAdressVault(uint256 shares) public {
        bundle.push(_erc4626Redeem(address(0), shares, 0, RECEIVER, address(genericModule1)));

        vm.expectRevert();
        bundler.multicall(bundle);
    }

    function testErc4626RedeemUnexpectedOwner(uint256 shares, address owner) public {
        vm.assume(owner != address(this) && owner != address(genericModule1));

        bundle.push(_erc4626Redeem(address(vault), shares, 0, RECEIVER, owner));

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.UnexpectedOwner.selector, owner));
        bundler.multicall(bundle);
    }

    function testErc4626RedeemZeroAdress(uint256 shares) public {
        bundle.push(_erc4626Redeem(address(vault), shares, 0, address(0), address(genericModule1)));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        bundler.multicall(bundle);
    }

    function testErc4626MintZero() public {
        bundle.push(_erc4626Mint(address(vault), 0, type(uint256).max, RECEIVER));

        vm.expectRevert(ErrorsLib.ZeroShares.selector);
        bundler.multicall(bundle);
    }

    function testErc4626DepositZero() public {
        bundle.push(_erc4626Deposit(address(vault), 0, type(uint256).max, RECEIVER));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler.multicall(bundle);
    }

    function testErc4626WithdrawZero() public {
        bundle.push(_erc4626Withdraw(address(vault), 0, 0, RECEIVER, address(genericModule1)));

        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        bundler.multicall(bundle);
    }

    function testErc4626RedeemZero() public {
        bundle.push(_erc4626Redeem(address(vault), 0, 0, RECEIVER, address(genericModule1)));

        vm.expectRevert(ErrorsLib.ZeroShares.selector);
        bundler.multicall(bundle);
    }

    function testErc4626MintSlippageExceeded(uint256 shares) public {
        shares = bound(shares, MIN_AMOUNT, MAX_AMOUNT);

        uint256 assets = vault.previewMint(shares);

        bundle.push(_erc20TransferFrom(address(loanToken), assets * 2));
        bundle.push(_erc4626Mint(address(vault), shares, assets.rDivDown(shares), USER));

        loanToken.setBalance(address(vault), 1);

        loanToken.setBalance(USER, assets * 2);

        vm.expectRevert(ErrorsLib.SlippageExceeded.selector);
        vm.prank(USER);
        bundler.multicall(bundle);
    }

    function testErc4626Mint(uint256 shares) public {
        shares = bound(shares, MIN_AMOUNT, MAX_AMOUNT);

        uint256 assets = vault.previewMint(shares);

        bundle.push(_erc20TransferFrom(address(loanToken), assets));
        bundle.push(_erc4626Mint(address(vault), shares, assets.rDivDown(shares), USER));

        loanToken.setBalance(USER, assets);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(loanToken.balanceOf(address(vault)), assets, "loan.balanceOf(vault)");
        assertEq(loanToken.balanceOf(address(genericModule1)), 0, "loan.balanceOf(genericModule1)");
        assertEq(vault.balanceOf(address(genericModule1)), 0, "vault.balanceOf(USER)");
        assertEq(vault.balanceOf(USER), shares, "vault.balanceOf(USER)");
    }

    function testErc4626DepositSlippageExceeded(uint256 assets) public {
        assets = bound(assets, MIN_AMOUNT, MAX_AMOUNT);

        uint256 shares = vault.previewDeposit(assets);

        bundle.push(_erc20TransferFrom(address(loanToken), assets));
        bundle.push(_erc4626Deposit(address(vault), assets, assets.rDivDown(shares), USER));

        loanToken.setBalance(address(vault), 1);

        loanToken.setBalance(USER, assets);

        vm.expectRevert(ErrorsLib.SlippageExceeded.selector);
        vm.prank(USER);
        bundler.multicall(bundle);
    }

    function testErc4626Deposit(uint256 assets) public {
        assets = bound(assets, MIN_AMOUNT, MAX_AMOUNT);

        uint256 shares = vault.previewDeposit(assets);

        bundle.push(_erc20TransferFrom(address(loanToken), assets));
        bundle.push(_erc4626Deposit(address(vault), assets, assets.rDivDown(shares), USER));

        loanToken.setBalance(USER, assets);

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(loanToken.balanceOf(address(vault)), assets, "loan.balanceOf(vault)");
        assertEq(loanToken.balanceOf(address(genericModule1)), 0, "loan.balanceOf(genericModule1)");
        assertEq(vault.balanceOf(address(genericModule1)), 0, "vault.balanceOf(USER)");
        assertEq(vault.balanceOf(USER), shares, "vault.balanceOf(USER)");
    }

    function testErc4626WithdrawSlippageExceeded(uint256 deposited, uint256 assets) public {
        deposited = bound(deposited, MIN_AMOUNT + 1, MAX_AMOUNT);

        _depositVault(deposited);

        // Don't withdraw max to avoid being limited by `maxWithdraw`.
        assets = bound(assets, MIN_AMOUNT, deposited - 1);

        uint256 redeemed = vault.previewWithdraw(assets);

        bundle.push(_erc4626Withdraw(address(vault), assets, assets.rDivDown(redeemed), RECEIVER, USER));

        loanToken.setBalance(address(vault), deposited - 1);

        vm.expectRevert(ErrorsLib.SlippageExceeded.selector);
        vm.prank(USER);
        bundler.multicall(bundle);
    }

    function testErc4626Withdraw(uint256 deposited, uint256 assets) public {
        deposited = bound(deposited, MIN_AMOUNT, MAX_AMOUNT);

        uint256 minted = _depositVault(deposited);

        assets = bound(assets, MIN_AMOUNT, deposited);

        uint256 redeemed = vault.previewWithdraw(assets);

        bundle.push(_erc20TransferFrom(address(vault), redeemed));
        bundle.push(
            _erc4626Withdraw(address(vault), assets, assets.rDivDown(redeemed), RECEIVER, address(genericModule1))
        );

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(loanToken.balanceOf(address(vault)), deposited - assets, "loan.balanceOf(vault)");
        assertEq(loanToken.balanceOf(address(genericModule1)), 0, "loan.balanceOf(genericModule1)");
        assertEq(loanToken.balanceOf(RECEIVER), assets, "loan.balanceOf(RECEIVER)");
        assertEq(vault.balanceOf(USER), minted - redeemed, "vault.balanceOf(USER)");
        assertEq(vault.balanceOf(RECEIVER), 0, "vault.balanceOf(RECEIVER)");
    }

    function testErc4626RedeemSlippageExceeded(uint256 deposited, uint256 shares) public {
        deposited = bound(deposited, MIN_AMOUNT, MAX_AMOUNT);

        uint256 minted = _depositVault(deposited);

        shares = bound(shares, 1, minted);

        uint256 withdrawn = vault.previewRedeem(shares);

        bundle.push(_erc4626Redeem(address(vault), shares, withdrawn.rDivDown(shares), RECEIVER, USER));

        loanToken.setBalance(address(vault), deposited - 1);

        vm.expectRevert(ErrorsLib.SlippageExceeded.selector);
        vm.prank(USER);
        bundler.multicall(bundle);
    }

    function testErc4626Redeem(uint256 deposited, uint256 shares) public {
        deposited = bound(deposited, MIN_AMOUNT, MAX_AMOUNT);

        uint256 minted = _depositVault(deposited);

        shares = bound(shares, 1, minted);

        uint256 withdrawn = vault.previewRedeem(shares);

        bundle.push(_erc20TransferFrom(address(vault), shares));
        bundle.push(
            _erc4626Redeem(address(vault), shares, withdrawn.rDivDown(shares), RECEIVER, address(genericModule1))
        );

        vm.prank(USER);
        bundler.multicall(bundle);

        assertEq(loanToken.balanceOf(address(vault)), deposited - withdrawn, "loan.balanceOf(vault)");
        assertEq(loanToken.balanceOf(address(genericModule1)), 0, "loan.balanceOf(genericModule1)");
        assertEq(loanToken.balanceOf(RECEIVER), withdrawn, "loan.balanceOf(RECEIVER)");
        assertEq(vault.balanceOf(USER), minted - shares, "vault.balanceOf(USER)");
        assertEq(vault.balanceOf(RECEIVER), 0, "vault.balanceOf(RECEIVER)");
    }

    function _depositVault(uint256 assets) internal returns (uint256 shares) {
        loanToken.setBalance(USER, assets);

        vm.prank(USER);
        shares = vault.deposit(assets, USER);
    }
}
