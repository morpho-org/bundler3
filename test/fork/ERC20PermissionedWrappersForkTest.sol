// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

import {ERC20Wrapper} from "../helpers/mocks/ERC20WrapperMock.sol";

import "./helpers/ForkTest.sol";

/* WBIB01 INTERFACES */

error NonWhitelistedToAddress(address to);

interface IWrappedBackedToken {
    function whitelistControllerAggregator() external view returns (address);
}

interface IWhitelistControllerAggregator {
    function isWhitelisted(address) external view returns (bool, address);
}

/* VER_USDC INTERFACES */

error NoPermission(address account);

interface IPermissionedERC20Wrapper {
    function memberlist() external view returns (address);
}

interface IMemberList {
    function isMember(address) external view returns (bool);
}

/* TEST */

contract Erc20PermissionedWrappersForkTest is ForkTest {
    address internal immutable WBIB01 = getAddress("WBIB01");
    address internal immutable VER_USDC = getAddress("VER_USDC");

    function setUp() public override {
        super.setUp();

        if (block.chainid == 1) {
            _whitelistForWbib01(address(generalAdapter1));
            _whitelistForWbib01(address(erc20WrapperAdapter));
        } else if (block.chainid == 8453) {
            _whitelistForVerUsdc(address(generalAdapter1));
            _whitelistForVerUsdc(address(erc20WrapperAdapter));
        }
    }

    function testWbib01NotUsableWithoutPermission(uint256 amount, address initiator) public onlyEthereum {
        vm.assume(initiator != address(0));
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        deal(address(ERC20Wrapper(WBIB01).underlying()), address(erc20WrapperAdapter), amount);

        bundle.push(_erc20WrapperDepositFor(address(WBIB01), amount));

        vm.expectRevert(abi.encodeWithSelector(NonWhitelistedToAddress.selector, initiator));
        vm.prank(initiator);
        bundler3.multicall(bundle);
    }

    function testWbibUsableWithPermission(uint256 amount, address initiator) public onlyEthereum {
        vm.assume(initiator != address(0));
        _whitelistForWbib01(initiator);
        _whitelistForWbib01(RECEIVER);

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.startPrank(initiator);
        IERC20(WBIB01).approve(address(erc20WrapperAdapter), type(uint256).max);
        IERC20(WBIB01).approve(address(generalAdapter1), type(uint256).max);
        vm.stopPrank();

        IERC20 underlying = ERC20Wrapper(WBIB01).underlying();
        deal(address(underlying), address(erc20WrapperAdapter), amount, true);

        bundle.push(_erc20WrapperDepositFor(address(WBIB01), amount));
        // check that a round-trip initiator=>wrapperAdapter=>generalAdapter=>wrapperAdapter is possible
        bundle.push(_erc20TransferFrom(address(WBIB01), address(erc20WrapperAdapter), amount));
        bundle.push(_erc20Transfer(address(WBIB01), address(generalAdapter1), amount, erc20WrapperAdapter));
        bundle.push(_erc20Transfer(address(WBIB01), address(erc20WrapperAdapter), amount, generalAdapter1));
        bundle.push(_erc20WrapperWithdrawTo(address(WBIB01), RECEIVER, amount));

        vm.prank(initiator);
        bundler3.multicall(bundle);

        vm.assertEq(underlying.balanceOf(RECEIVER), amount, "RECEIVER");
        vm.assertEq(IERC20(WBIB01).balanceOf(address(erc20WrapperAdapter)), 0, "erc20WrapperAdapter");
        vm.assertEq(IERC20(WBIB01).balanceOf(initiator), 0, "initiator");
    }

    function testWbib01BypassFailsWithdrawWithoutPermission(uint256 amount, address initiator) public onlyEthereum {
        vm.assume(initiator != address(0));

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        IERC20 underlying = ERC20Wrapper(WBIB01).underlying();

        vm.startPrank(initiator);
        IERC20(WBIB01).approve(address(erc20WrapperAdapter), type(uint256).max);
        underlying.approve(WBIB01, type(uint256).max);
        vm.stopPrank();

        deal(address(underlying), initiator, amount, true);

        vm.prank(initiator);
        ERC20Wrapper(WBIB01).depositFor(address(erc20WrapperAdapter), amount);

        vm.assertEq(IERC20(WBIB01).balanceOf(address(erc20WrapperAdapter)), amount);

        bundle.push(_erc20WrapperWithdrawTo(address(WBIB01), address(erc20WrapperAdapter), amount));
        vm.prank(initiator);
        vm.expectRevert();
        bundler3.multicall(bundle);
    }

    function testVerUsdcNotUsableWithoutPermission(uint256 amount, address initiator) public onlyBase {
        vm.assume(initiator != address(0));
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        deal(address(ERC20Wrapper(VER_USDC).underlying()), address(erc20WrapperAdapter), amount);

        bundle.push(_erc20WrapperDepositFor(address(VER_USDC), amount));

        vm.expectRevert("PermissionedERC20Wrapper/no-attestation-found");
        vm.prank(initiator);
        bundler3.multicall(bundle);
    }

    function testVerUsdcUsableWithPermission(uint256 amount, address initiator) public onlyBase {
        vm.assume(initiator != address(0));
        _whitelistForVerUsdc(initiator);
        _whitelistForVerUsdc(RECEIVER);

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.startPrank(initiator);
        IERC20(VER_USDC).approve(address(erc20WrapperAdapter), type(uint256).max);
        IERC20(VER_USDC).approve(address(generalAdapter1), type(uint256).max);
        vm.stopPrank();

        IERC20 underlying = ERC20Wrapper(VER_USDC).underlying();
        deal(address(underlying), address(erc20WrapperAdapter), amount, true);

        bundle.push(_erc20WrapperDepositFor(address(VER_USDC), amount));
        // check that a round-trip initiator=>wrapperAdapter=>generalAdapter=>wrapperAdapter is possible
        bundle.push(_erc20TransferFrom(address(VER_USDC), address(erc20WrapperAdapter), amount));
        bundle.push(_erc20Transfer(address(VER_USDC), address(generalAdapter1), amount, erc20WrapperAdapter));
        bundle.push(_erc20Transfer(address(VER_USDC), address(erc20WrapperAdapter), amount, generalAdapter1));
        bundle.push(_erc20WrapperWithdrawTo(address(VER_USDC), RECEIVER, amount));

        vm.prank(initiator);
        bundler3.multicall(bundle);

        vm.assertEq(underlying.balanceOf(RECEIVER), amount, "RECEIVER");
        vm.assertEq(IERC20(VER_USDC).balanceOf(address(erc20WrapperAdapter)), 0, "erc20WrapperAdapter");
        vm.assertEq(IERC20(VER_USDC).balanceOf(initiator), 0, "initiator");
    }

    function testVerUsdcBypassFailsWithdrawWithoutPermission(uint256 amount, address initiator) public onlyBase {
        vm.assume(initiator != address(0));

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        IERC20 underlying = ERC20Wrapper(VER_USDC).underlying();

        vm.startPrank(initiator);
        IERC20(VER_USDC).approve(address(erc20WrapperAdapter), type(uint256).max);
        underlying.approve(VER_USDC, type(uint256).max);
        vm.stopPrank();

        deal(address(underlying), initiator, amount, true);

        vm.prank(initiator);
        ERC20Wrapper(VER_USDC).depositFor(address(erc20WrapperAdapter), amount);

        vm.assertEq(IERC20(VER_USDC).balanceOf(address(erc20WrapperAdapter)), amount);

        bundle.push(_erc20WrapperWithdrawTo(address(VER_USDC), address(erc20WrapperAdapter), amount));
        vm.prank(initiator);
        vm.expectRevert(bytes("PermissionedERC20Wrapper/no-attestation-found"));
        bundler3.multicall(bundle);
    }

    /* WHITELISTING HELPERS */

    function _whitelistForWbib01(address account) internal {
        address controller = IWrappedBackedToken(WBIB01).whitelistControllerAggregator();
        vm.mockCall(
            controller,
            abi.encodeCall(IWhitelistControllerAggregator.isWhitelisted, (account)),
            abi.encode(true, address(0))
        );
    }

    function _whitelistForVerUsdc(address account) internal {
        address memberList = IPermissionedERC20Wrapper(VER_USDC).memberlist();
        vm.mockCall(memberList, abi.encodeCall(IMemberList.isMember, (account)), abi.encode(true));
    }
}
