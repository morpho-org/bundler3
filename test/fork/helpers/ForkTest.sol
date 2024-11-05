// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IStEth} from "../../../src/interfaces/IStEth.sol";
import {IWstEth} from "../../../src/interfaces/IWstEth.sol";
import {IAllowanceTransfer} from "../../../lib/permit2/src/interfaces/IAllowanceTransfer.sol";

import {Permit2Lib} from "../../../lib/permit2/src/libraries/Permit2Lib.sol";

import {Permit2Bundler} from "../../../src/Permit2Bundler.sol";
import {WNativeBundler} from "../../../src/WNativeBundler.sol";
import {StEthBundler} from "../../../src/StEthBundler.sol";
import {EthereumBundlerV2} from "../../../src/ethereum/EthereumBundlerV2.sol";
import {ChainAgnosticBundlerV2} from "../../../src/chain-agnostic/ChainAgnosticBundlerV2.sol";

import "../../../config/Configured.sol";
import "../../helpers/CommonTest.sol";

abstract contract ForkTest is CommonTest, Configured {
    using ConfigLib for Config;
    using SafeTransferLib for ERC20;

    uint256 internal forkId;

    uint256 internal snapshotId = type(uint256).max;

    MarketParams[] allMarketParams;

    function setUp() public virtual override {
        // Run fork tests on Ethereum by default.
        if (block.chainid == 31337) vm.chainId(1);

        _loadConfig();

        _fork();
        _label();

        super.setUp();

        if (block.chainid == 1) {
            bundler = new EthereumBundlerV2(address(morpho));
        } else if (block.chainid == 8453) {
            bundler = new ChainAgnosticBundlerV2(address(morpho), address(WETH));
        }

        for (uint256 i; i < configMarkets.length; ++i) {
            ConfigMarket memory configMarket = configMarkets[i];

            MarketParams memory marketParams = MarketParams({
                collateralToken: configMarket.collateralToken,
                loanToken: configMarket.loanToken,
                oracle: address(oracle),
                irm: address(irm),
                lltv: configMarket.lltv
            });

            vm.startPrank(OWNER);
            if (!morpho.isLltvEnabled(configMarket.lltv)) morpho.enableLltv(configMarket.lltv);
            morpho.createMarket(marketParams);
            vm.stopPrank();

            allMarketParams.push(marketParams);
        }

        vm.prank(USER);
        morpho.setAuthorization(address(bundler), true);
    }

    function _fork() internal virtual {
        string memory rpcUrl = vm.rpcUrl(network);
        uint256 forkBlockNumber = CONFIG.getForkBlockNumber();

        forkId = forkBlockNumber == 0 ? vm.createSelectFork(rpcUrl) : vm.createSelectFork(rpcUrl, forkBlockNumber);

        vm.chainId(CONFIG.getChainId());
    }

    function _label() internal virtual {
        for (uint256 i; i < allAssets.length; ++i) {
            address asset = allAssets[i];
            if (asset != address(0)) {
                string memory symbol = ERC20(asset).symbol();

                vm.label(asset, symbol);
            }
        }
    }

    function deal(address asset, address recipient, uint256 amount) internal virtual override {
        if (amount == 0) return;

        if (asset == WETH) super.deal(WETH, WETH.balance + amount); // Refill wrapped Ether.

        if (asset == ST_ETH) {
            if (amount == 0) return;

            deal(recipient, amount);

            vm.prank(recipient);
            uint256 stEthAmount = IStEth(ST_ETH).submit{value: amount}(address(0));

            vm.assume(stEthAmount != 0);

            return;
        }

        return super.deal(asset, recipient, amount);
    }

    modifier onlyEthereum() {
        vm.skip(block.chainid != 1);
        _;
    }

    /// @dev Reverts the fork to its initial fork state.
    function _revert() internal {
        if (snapshotId < type(uint256).max) vm.revertTo(snapshotId);
        snapshotId = vm.snapshot();
    }

    function _assumeNotAsset(address input) internal view {
        for (uint256 i; i < allAssets.length; ++i) {
            vm.assume(input != allAssets[i]);
        }
    }

    function _randomAsset(uint256 seed) internal view returns (address) {
        return allAssets[seed % allAssets.length];
    }

    function _randomMarketParams(uint256 seed) internal view returns (MarketParams memory) {
        return allMarketParams[seed % allMarketParams.length];
    }

    /* PERMIT2 ACTIONS */

    function _approve2(uint256 privateKey, address asset, uint256 amount, uint256 nonce, bool skipRevert)
        internal
        view
        returns (bytes memory)
    {
        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: asset,
                amount: uint160(amount),
                expiration: type(uint48).max,
                nonce: uint48(nonce)
            }),
            spender: address(bundler),
            sigDeadline: SIGNATURE_DEADLINE
        });

        bytes32 digest = SigUtils.toTypedDataHash(Permit2Lib.PERMIT2.DOMAIN_SEPARATOR(), permitSingle);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        return abi.encodeCall(Permit2Bundler.approve2, (permitSingle, abi.encodePacked(r, s, v), skipRevert));
    }

    function _transferFrom2(address asset, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeCall(Permit2Bundler.transferFrom2, (asset, amount));
    }

    /* wstETH ACTIONS */

    function _wrapStEth(uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeCall(StEthBundler.wrapStEth, (amount));
    }

    function _unwrapStEth(uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeCall(StEthBundler.unwrapStEth, (amount));
    }

    /* WRAPPED NATIVE ACTIONS */

    function _wrapNative(uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeCall(WNativeBundler.wrapNative, (amount));
    }

    function _unwrapNative(uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeCall(WNativeBundler.unwrapNative, (amount));
    }
}
