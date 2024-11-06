// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {SigUtils, Permit} from "./helpers/SigUtils.sol";

import "../src/libraries/ErrorsLib.sol" as ErrorsLib;
import {IERC20Permit} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {ERC20Permit} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20PermitMock} from "../src/mocks/ERC20PermitMock.sol";

import {PermitBundler} from "../src/PermitBundler.sol";
import "./helpers/LocalTest.sol";

contract PermitBundlerLocalTest is LocalTest {
    ERC20PermitMock internal permitToken;

    function setUp() public override {
        super.setUp();

        permitToken = new ERC20PermitMock("Permit Token", "PT");
    }

    function testPermit(uint256 amount, uint256 privateKey, address spender, uint256 deadline) public {
        vm.assume(spender != address(0));
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        deadline = bound(deadline, block.timestamp, type(uint48).max);
        privateKey = bound(privateKey, 1, type(uint160).max);

        address user = vm.addr(privateKey);

        bundle.push(_permit(permitToken, privateKey, spender, amount, deadline, false));
        bundle.push(_permit(permitToken, privateKey, spender, amount, deadline, true));

        vm.prank(user);
        hub.multicall(bundle);

        assertEq(permitToken.allowance(user, spender), amount, "allowance(user, genericBundler1");
    }

    function testPermitUnauthorized(uint256 amount, address spender) public {
        vm.assume(spender != address(0));
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.UnauthorizedSender.selector, address(this)));
        genericBundler1.permit(address(loanToken), spender, amount, SIGNATURE_DEADLINE, 0, 0, 0, true);
    }

    function testPermitRevert(uint256 amount, uint256 privateKey, address spender, uint256 deadline) public {
        vm.assume(spender != address(0));
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        deadline = bound(deadline, block.timestamp, type(uint48).max);
        privateKey = bound(privateKey, 1, type(uint160).max);

        address user = vm.addr(privateKey);

        bundle.push(_permit(permitToken, privateKey, spender, amount, deadline, false));
        bundle.push(_permit(permitToken, privateKey, spender, amount, deadline, false));

        vm.prank(user);
        vm.expectPartialRevert(ERC20Permit.ERC2612InvalidSigner.selector);
        hub.multicall(bundle);
    }

    function testTransferFrom(uint256 amount, uint256 privateKey, uint256 deadline) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        deadline = bound(deadline, block.timestamp, type(uint48).max);
        privateKey = bound(privateKey, 1, type(uint160).max);

        address user = vm.addr(privateKey);

        bundle.push(_permit(permitToken, privateKey, address(genericBundler1), amount, deadline, false));
        bundle.push(_erc20TransferFrom(address(permitToken), amount));

        permitToken.setBalance(user, amount);

        vm.prank(user);
        hub.multicall(bundle);

        assertEq(permitToken.balanceOf(address(genericBundler1)), amount, "balanceOf(genericBundler1)");
        assertEq(permitToken.balanceOf(user), 0, "balanceOf(user)");
    }

    function _permit(
        IERC20Permit token,
        uint256 privateKey,
        address spender,
        uint256 amount,
        uint256 deadline,
        bool skipRevert
    ) internal view returns (Call memory) {
        address user = vm.addr(privateKey);

        Permit memory permit = Permit(user, spender, amount, token.nonces(user), deadline);

        bytes32 digest = SigUtils.toTypedDataHash(token.DOMAIN_SEPARATOR(), permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        bytes memory callData =
            abi.encodeCall(PermitBundler.permit, (address(token), spender, amount, deadline, v, r, s, skipRevert));
        return _call(genericBundler1, callData);
    }
}
