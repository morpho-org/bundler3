// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";
import "../../src/libraries/ConstantsLib.sol" as ConstantsLib;

import "./helpers/LocalTest.sol";

contract BaseBundlerLocalTest is LocalTest {
    function testMulticallEmpty() public {
        bundler.multicall(bundle);
    }

    function testNestedMulticall() public {
        bundle.push(abi.encodeCall(BaseBundler.multicall, (callbackBundle)));

        vm.expectRevert(bytes(ErrorsLib.ALREADY_INITIATED));
        bundler.multicall(bundle);
    }

    function testInitiatorSlot() public view {
        assertEq(ConstantsLib.INITIATOR_SLOT, keccak256("Morpho Bundler Initiator Slot"));
    }
}
