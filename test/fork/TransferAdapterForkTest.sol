// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

import "./helpers/ForkTest.sol";

contract TransferAdapterForkTest is ForkTest {
    bool skipTest;

    function setUp() public override {
        super.setUp();

        if (block.chainid != 1 && block.chainid != 8453) {
            skipTest = true;
        }
    }

    function testTransferToBundlerV2(address token, uint256 amount) public {
        vm.skip(skipTest);
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bundle.push(_erc20Transfer(token, getAddress("BUNDLER_V2"), amount, generalAdapter1));

        vm.expectRevert(ErrorsLib.UnauthorizedReceiver.selector);
        bundler3.multicall(bundle);
    }
}
