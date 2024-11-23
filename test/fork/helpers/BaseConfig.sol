// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./NetworkConfig.sol";

contract BaseConfig is NetworkConfig {
    function initialize() internal virtual override {
        network = "base";
        blockNumber = 14000000;

        markets.push(ConfigMarket({collateralToken: "WETH", loanToken: "WETH", lltv: 800000000000000000}));

        setAddress("DAI", 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb);
        setAddress("USDC", 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
        setAddress("WETH", 0x4200000000000000000000000000000000000006);
        setAddress("CB_ETH", 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22);
        setAddress("AAVE_V3_POOL", 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5);
        setAddress("C_WETH_V3", 0x46e6b214b524310239732D51387075E0e70970bf);
    }
}
