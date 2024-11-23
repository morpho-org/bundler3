// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {CommonBase} from "../../../lib/forge-std/src/Base.sol";

// Holds fork-specific configuration data

struct ConfigMarket {
    string collateralToken;
    string loanToken;
    uint256 lltv;
}

abstract contract NetworkConfig is CommonBase {
    string public network;
    uint256 public blockNumber;
    ConfigMarket[] internal markets;
    mapping(string => address) public addresses;

    // Load known addresses before test contract are constructed.
    bool private initialized = safeInitialize();

    function safeInitialize() private returns (bool) {
        require(!initialized, "NetworkConfig: already initialized");

        initialize();

        require(
            bytes(network).length > 0, string.concat("NetworkConfig: unknown chain id ", vm.toString(block.chainid))
        );
        return true;
    }

    function initialize() internal virtual;

    function getAddress(string memory name) public view returns (address addr) {
        addr = addresses[name];
        require(addr != address(0), string.concat("Configured: unknown address ", name));
        return addr;
    }

    function setAddress(string memory name, address addr) public {
        addresses[name] = addr;
        vm.label(addr, name);
    }

    function market(uint256 index) external view returns (ConfigMarket memory) {
        return markets[index];
    }

    function marketsLength() external view returns (uint256) {
        return markets.length;
    }
}
