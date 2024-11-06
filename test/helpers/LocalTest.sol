// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ERC20Mock} from "../../src/mocks/ERC20Mock.sol";

import "./CommonTest.sol";

abstract contract LocalTest is CommonTest {
    using MathLib for uint256;
    using SharesMathLib for uint256;
    using MarketParamsLib for MarketParams;
    using stdStorage for StdStorage;

    uint256 internal constant LLTV = 0.8 ether;

    ERC20Mock internal loanToken;
    ERC20Mock internal collateralToken;

    MarketParams internal marketParams;
    Id internal id;

    function setUp() public virtual override {
        super.setUp();

        loanToken = new ERC20Mock("loan", "B");
        collateralToken = new ERC20Mock("collateral", "C");

        marketParams = MarketParams(address(loanToken), address(collateralToken), address(oracle), address(irm), LLTV);
        id = marketParams.id();

        vm.startPrank(OWNER);
        morpho.enableLltv(LLTV);
        morpho.createMarket(marketParams);
        vm.stopPrank();

        loanToken.approve(address(morpho), type(uint256).max);
        collateralToken.approve(address(morpho), type(uint256).max);

        vm.prank(SUPPLIER);
        loanToken.approve(address(morpho), type(uint256).max);
    }
}
