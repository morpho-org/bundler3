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
        } else if (block.chainid == 8453) {
            _whitelistForVerUsdc(address(generalAdapter1));
        }
    }

    function testWbib01NotUsableWithoutPermission(uint256 amount, address initiator) public onlyEthereum {
        vm.assume(initiator != address(0));
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        deal(address(ERC20Wrapper(WBIB01).underlying()), address(generalAdapter1), amount);

        bundle.push(_erc20WrapperDepositFor(address(WBIB01), amount));

        vm.expectRevert(abi.encodeWithSelector(NonWhitelistedToAddress.selector, initiator));
        vm.prank(initiator);
        bundler3.multicall(bundle);
    }

    function testWbibUsableWithPermission(uint256 amount, address initiator) public onlyEthereum {
        vm.assume(initiator != address(0));
        _whitelistForWbib01(initiator);

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.prank(initiator);
        IERC20(WBIB01).approve(address(generalAdapter1), amount);

        deal(address(ERC20Wrapper(WBIB01).underlying()), address(generalAdapter1), amount, true);

        bundle.push(_erc20WrapperDepositFor(address(WBIB01), amount));
        bundle.push(_erc20TransferFrom(address(WBIB01), address(generalAdapter1), amount));

        vm.prank(initiator);
        bundler3.multicall(bundle);

        vm.assertGt(IERC20(WBIB01).balanceOf(address(generalAdapter1)), 0);
    }

    function testVerUsdcNotUsableWithoutPermission(uint256 amount, address initiator) public onlyBase {
        vm.assume(initiator != address(0));
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        deal(address(ERC20Wrapper(VER_USDC).underlying()), address(generalAdapter1), amount);

        bundle.push(_erc20WrapperDepositFor(address(VER_USDC), amount));

        vm.expectRevert("PermissionedERC20Wrapper/no-attestation-found");
        vm.prank(initiator);
        bundler3.multicall(bundle);
    }

    function testVerUsdcUsableWithPermission(uint256 amount, address initiator) public onlyBase {
        vm.assume(initiator != address(0));
        _whitelistForVerUsdc(initiator);

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.prank(initiator);
        IERC20(VER_USDC).approve(address(generalAdapter1), amount);

        deal(address(ERC20Wrapper(VER_USDC).underlying()), address(generalAdapter1), amount, true);

        bundle.push(_erc20WrapperDepositFor(address(VER_USDC), amount));
        bundle.push(_erc20TransferFrom(address(VER_USDC), address(generalAdapter1), amount));

        vm.prank(initiator);
        bundler3.multicall(bundle);

        vm.assertGt(IERC20(VER_USDC).balanceOf(address(generalAdapter1)), 0);
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
