// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {MarketParams} from "@morpho-blue/interfaces/IMorpho.sol";

struct MarketAllocation {
    MarketParams marketParams;
    uint256 assets;
}