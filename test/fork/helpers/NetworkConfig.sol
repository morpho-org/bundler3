// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {CommonBase} from "../../../lib/forge-std/src/Base.sol";

// Holds fork-specific configuration data

struct ConfigMarket {
    string collateralToken;
    string loanToken;
    uint256 lltv;
}

// NetworkConfig loads config data at construction time.
// This makes config data available to inheriting test contracts when they are constructed.
// But `block.chainid` is not preserved between the constructor and the call to `setUp`. So we store the planned chainid
// in the config to have it available.
struct Config {
    string network;
    uint256 chainid;
    uint256 blockNumber;
    mapping(string => address) addresses;
    ConfigMarket[] markets;
}

abstract contract NetworkConfig is CommonBase {
    function initializeConfigData() private {
        /* ETHEREUM NETWORK */

        if (config.chainid == 1) {
            config.network = "ethereum";
            config.blockNumber = 21230000;
            config.markets.push(ConfigMarket({collateralToken: "WETH", loanToken: "DAI", lltv: 800000000000000000}));

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
            setAddress("AUGUSTUS_V6_2", 0x6A000F20005980200259B80c5102003040001068);
            setAddress("AUGUSTUS_REGISTRY", 0xa68bEA62Dc4034A689AA0F58A76681433caCa663);
            setAddress("WBIB01", 0xcA2A7068e551d5C4482eb34880b194E4b945712F);

            /* BASE NETWORK */
        } else if (config.chainid == 8453) {
            config.network = "base";
            config.blockNumber = 25641890;
            config.markets.push(ConfigMarket({collateralToken: "WETH", loanToken: "WETH", lltv: 800000000000000000}));

            setAddress("DAI", 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb);
            setAddress("USDC", 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
            setAddress("WETH", 0x4200000000000000000000000000000000000006);
            setAddress("CB_ETH", 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22);
            setAddress("AAVE_V3_POOL", 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5);
            setAddress("C_WETH_V3", 0x46e6b214b524310239732D51387075E0e70970bf);
            setAddress("AUGUSTUS_V6_2", 0x6A000F20005980200259B80c5102003040001068);
            setAddress("AUGUSTUS_REGISTRY", 0x7E31B336F9E8bA52ba3c4ac861b033Ba90900bb3);
            setAddress("VER_USDC", 0x59aaF835D34b1E3dF2170e4872B785f11E2a964b);
        }
    }

    address public constant UNINITIALIZED_ADDRESS = address(bytes20(bytes32("UNINITIALIZED ADDRESS")));

    Config internal config;

    // Load known addresses before tests try to use them when initializing their state variables.
    bool private initialized = initializeConfig();

    function initializeConfig() internal virtual returns (bool) {
        require(!initialized, "Configured: already initialized");

        vm.label(UNINITIALIZED_ADDRESS, "UNINITIALIZED_ADDRESS");

        // Run tests on Ethereum by default
        if (block.chainid == 31337) {
            config.chainid = 1;
        } else {
            config.chainid = block.chainid;
        }

        initializeConfigData();

        require(
            bytes(config.network).length > 0,
            string.concat("Configured: unknown chain id ", vm.toString(config.chainid))
        );
        return true;
    }

    function getAddress(string memory name) internal view returns (address addr) {
        addr = config.addresses[name];
        return addr == address(0) ? UNINITIALIZED_ADDRESS : addr;
    }

    function hasAddress(string memory name) internal view returns (bool) {
        return config.addresses[name] != address(0);
    }

    function setAddress(string memory name, address addr) internal {
        require(addr != address(0), "NetworkConfig: cannot set address 0");
        config.addresses[name] = addr;
        vm.label(addr, name);
    }
}
