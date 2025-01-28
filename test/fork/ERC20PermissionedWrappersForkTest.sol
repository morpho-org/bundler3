// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

// import {ERC20WrapperMock, ERC20Wrapper} from "../helpers/mocks/ERC20WrapperMock.sol";

import "./helpers/ForkTest.sol";

/* WBIB01 INTERFACES */

error NonWhitelistedToAddress(address to);

interface IWrappedBackedToken {
    function whitelistControllerAggregator() external view returns (address);
    function underlying() external view returns (address);
}

interface IWhitelistControllerAggregator {
    function isWhitelisted(address) external view returns (bool, address);
}

/* TEST */

contract Erc20PermissionedWrappersForkTest is ForkTest {
    address internal immutable WBIB01 = getAddress("WBIB01");

    function setUp() public override {
        super.setUp();
        if (block.chainid != 1) return;

        _whitelistForWbib01(address(generalAdapter1));
    }

    function testWbib01NotUsableWithoutPermission(uint256 amount, address initiator) public onlyEthereum {
        vm.assume(initiator != address(0));
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        deal(IWrappedBackedToken(WBIB01).underlying(), address(generalAdapter1), amount);

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

        deal(IWrappedBackedToken(WBIB01).underlying(), address(generalAdapter1), amount, true);

        bundle.push(_erc20WrapperDepositFor(address(WBIB01), amount));
        bundle.push(_erc20TransferFrom(address(WBIB01), address(generalAdapter1), amount));

        vm.prank(initiator);
        bundler3.multicall(bundle);

        vm.assertGt(IERC20(WBIB01).balanceOf(address(generalAdapter1)), 0);
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
}
