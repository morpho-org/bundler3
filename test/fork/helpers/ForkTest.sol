// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IStEth} from "../../../src/interfaces/IStEth.sol";
import {IWstEth} from "../../../src/interfaces/IWstEth.sol";
import {IAllowanceTransfer} from "../../../lib/permit2/src/interfaces/IAllowanceTransfer.sol";

import {Permit2Lib} from "../../../lib/permit2/src/libraries/Permit2Lib.sol";

import {StEthModule} from "../../../src/ethereum/StEthModule.sol";
import {EthereumModule1} from "../../../src/ethereum/EthereumModule1.sol";

import "../../../config/Configured.sol";
import "../../helpers/CommonTest.sol";

abstract contract ForkTest is CommonTest, Configured {
    using ConfigLib for Config;
    using SafeTransferLib for ERC20;

    EthereumModule1 internal ethereumModule1;

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

        genericModule1 = new GenericModule1(address(bundler), address(morpho), address(WETH));

        if (block.chainid == 1) {
            ethereumModule1 = new EthereumModule1(address(bundler), DAI, WST_ETH);
            paraswapModule = new ParaswapModule(address(bundler), address(morpho), address(AUGUSTUS_REGISTRY));
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
        morpho.setAuthorization(address(genericModule1), true);
    }

    function _fork() internal virtual {
        string memory rpcUrl = vm.rpcUrl(network);
        uint256 forkBlockNumber = CONFIG.getForkBlockNumber(_forkBlockNumberKey());

        forkId = forkBlockNumber == 0 ? vm.createSelectFork(rpcUrl) : vm.createSelectFork(rpcUrl, forkBlockNumber);

        vm.chainId(CONFIG.getChainId());
    }

    function _forkBlockNumberKey() internal virtual returns (string memory) {
        return "default";
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
        returns (Call memory)
    {
        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: asset,
                amount: uint160(amount),
                expiration: type(uint48).max,
                nonce: uint48(nonce)
            }),
            spender: address(genericModule1),
            sigDeadline: SIGNATURE_DEADLINE
        });

        bytes32 digest = SigUtils.toTypedDataHash(Permit2Lib.PERMIT2.DOMAIN_SEPARATOR(), permitSingle);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        return _call(
            genericModule1,
            abi.encodeCall(GenericModule1.approve2, (permitSingle, abi.encodePacked(r, s, v), skipRevert))
        );
    }

    function _transferFrom2(address asset, uint256 amount) internal view returns (Call memory) {
        return _transferFrom2(asset, address(genericModule1), amount);
    }

    function _transferFrom2(address asset, address receiver, uint256 amount) internal view returns (Call memory) {
        return _call(genericModule1, abi.encodeCall(GenericModule1.transferFrom2, (asset, receiver, amount)));
    }

    /* STAKE ACTIONS */

    function _stakeEth(uint256 amount, uint256 shares, address referral, address receiver)
        internal
        view
        returns (Call memory)
    {
        return _stakeEth(amount, shares, referral, receiver, amount);
    }

    function _stakeEth(uint256 amount, uint256 shares, address referral, address receiver, uint256 callValue)
        internal
        view
        returns (Call memory)
    {
        return _call(
            ethereumModule1, abi.encodeCall(StEthModule.stakeEth, (amount, shares, referral, receiver)), callValue
        );
    }

    /* wstETH ACTIONS */

    function _wrapStEth(uint256 amount, address receiver) internal view returns (Call memory) {
        return _call(ethereumModule1, abi.encodeCall(StEthModule.wrapStEth, (amount, receiver)));
    }

    function _unwrapStEth(uint256 amount, address receiver) internal view returns (Call memory) {
        return _call(ethereumModule1, abi.encodeCall(StEthModule.unwrapStEth, (amount, receiver)));
    }

    /* WRAPPED NATIVE ACTIONS */

    function _wrapNativeNoFunding(uint256 amount, address receiver) internal view returns (Call memory) {
        return _call(genericModule1, abi.encodeCall(GenericModule1.wrapNative, (amount, receiver)), 0);
    }

    function _wrapNative(uint256 amount, address receiver) internal view returns (Call memory) {
        return _call(genericModule1, abi.encodeCall(GenericModule1.wrapNative, (amount, receiver)), amount);
    }

    function _unwrapNative(uint256 amount, address receiver) internal view returns (Call memory) {
        return _call(genericModule1, abi.encodeCall(GenericModule1.unwrapNative, (amount, receiver)));
    }
}
