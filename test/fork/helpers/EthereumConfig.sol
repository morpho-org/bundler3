// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./NetworkConfig.sol";
import "forge-std/console.sol";

contract EthereumConfig is NetworkConfig {
    function initialize() internal virtual override {
        console.log("setting network");
        network = "ethereum";
        blockNumber = 21230000;

        markets.push(ConfigMarket({collateralToken: "WETH", loanToken: "DAI", lltv: 800000000000000000}));

        setAddress("DAI", 0x6B175474E89094C44Da98b954EedeAC495271d0F);
        setAddress("USDC", 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        setAddress("USDT", 0xdAC17F958D2ee523a2206206994597C13D831ec7);
        setAddress("WBTC", 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
        setAddress("WETH", 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        setAddress("ST_ETH", 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
        setAddress("WST_ETH", 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        setAddress("CB_ETH", 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704);
        setAddress("S_DAI", 0x83F20F44975D03b1b09e64809B757c47f942BEeA);
        setAddress("AAVE_V2_POOL", 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
        setAddress("AAVE_V3_POOL", 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
        setAddress("AAVE_V3_OPTIMIZER", 0x33333aea097c193e66081E930c33020272b33333);
        setAddress("COMPTROLLER", 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
        setAddress("C_DAI_V2", 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
        setAddress("C_ETH_V2", 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5);
        setAddress("C_USDC_V2", 0x39AA39c021dfbaE8faC545936693aC917d5E7563);
        setAddress("C_WETH_V3", 0xA17581A9E3356d9A858b789D68B4d866e593aE94);
        setAddress("MORPHO_SAFE_OWNER", 0x0b9915C13e8E184951Df0d9C0b104f8f1277648B);
        setAddress("MORPHO_WRAPPER", 0x9D03bb2092270648d7480049d0E58d2FcF0E5123);
        setAddress("MORPHO_TOKEN_LEGACY", 0x9994E35Db50125E0DF82e4c2dde62496CE330999);
        setAddress("MORPHO_TOKEN", 0x58D97B57BB95320F9a05dC918Aef65434969c2B2);
    }
}
