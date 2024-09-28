// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {stdJson} from "../lib/forge-std/src/StdJson.sol";

struct Config {
    string json;
}

/// @dev Warning: keys must be ordered alphabetically.
struct RawConfigMarket {
    string collateralToken;
    uint256 lltv;
    string loanToken;
}

struct ConfigMarket {
    address collateralToken;
    address loanToken;
    uint256 lltv;
}

library ConfigLib {
    using stdJson for string;

    string internal constant CHAIN_ID_PATH = "$.chainId";
    string internal constant FORK_BLOCK_NUMBERS_PATH = "$.forkBlockNumbers";
    string internal constant MARKETS_PATH = "$.markets";
    string internal constant WRAPPED_NATIVE_PATH = "$.wrappedNative";
    string internal constant LSD_NATIVES_PATH = "$.lsdNatives";

    function getAddress(Config storage config, string memory key) internal view returns (address) {
        return config.json.readAddress(string.concat("$.", key));
    }

    function getAddressArray(Config storage config, string[] memory keys)
        internal
        view
        returns (address[] memory addresses)
    {
        addresses = new address[](keys.length);

        for (uint256 i; i < keys.length; ++i) {
            addresses[i] = getAddress(config, keys[i]);
        }
    }

    function getChainId(Config storage config) internal view returns (uint256) {
        return config.json.readUint(CHAIN_ID_PATH);
    }

    function getForkBlockNumber(Config storage config, string memory key) internal view returns (uint256) {
        return config.json.readUint(string.concat(FORK_BLOCK_NUMBERS_PATH, ".", key));
    }

    function getWrappedNative(Config storage config) internal view returns (address) {
        return getAddress(config, config.json.readString(WRAPPED_NATIVE_PATH));
    }

    function getLsdNatives(Config storage config) internal view returns (address[] memory) {
        return getAddressArray(config, config.json.readStringArray(LSD_NATIVES_PATH));
    }

    function getMarkets(Config storage config) internal view returns (ConfigMarket[] memory markets) {
        bytes memory encodedMarkets = config.json.parseRaw(MARKETS_PATH);
        RawConfigMarket[] memory rawMarkets = abi.decode(encodedMarkets, (RawConfigMarket[]));

        markets = new ConfigMarket[](rawMarkets.length);

        for (uint256 i; i < rawMarkets.length; ++i) {
            RawConfigMarket memory rawMarket = rawMarkets[i];

            markets[i] = ConfigMarket({
                collateralToken: getAddress(config, rawMarket.collateralToken),
                loanToken: getAddress(config, rawMarket.loanToken),
                lltv: rawMarket.lltv
            });
        }
    }
}
