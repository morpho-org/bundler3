// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IStEth} from "../../../src/interfaces/IStEth.sol";
import {IWstEth} from "../../../src/interfaces/IWstEth.sol";
import {IAllowanceTransfer} from "../../../lib/permit2/src/interfaces/IAllowanceTransfer.sol";

import {Permit2Lib} from "../../../lib/permit2/src/libraries/Permit2Lib.sol";

import {EthereumGeneralAdapter1, MathRayLib} from "../../../src/adapters/EthereumGeneralAdapter1.sol";

import "./NetworkConfig.sol";
import "../../helpers/CommonTest.sol";

abstract contract ForkTest is CommonTest, NetworkConfig {
    EthereumGeneralAdapter1 internal ethereumGeneralAdapter1;
    MarketParams[] internal allMarketParams;
    // Overloaded function permit in IAllowanceTransfer cannot be directly referenced in Solidity. The selectors are
    // used directly.
    bytes4 constant permitSingleSelector = 0x2b67b570;
    bytes4 constant permitBatchSelector = 0x2a2d80d1;

    function setUp() public virtual override {
        string memory rpc = vm.rpcUrl(config.network);

        if (config.blockNumber == 0) vm.createSelectFork(rpc);
        else vm.createSelectFork(rpc, config.blockNumber);

        super.setUp();

        if (isEq(config.network, "ethereum")) {
            ethereumGeneralAdapter1 = new EthereumGeneralAdapter1(
                address(bundler3),
                address(morpho),
                getAddress("WETH"),
                getAddress("WST_ETH"),
                getAddress("MORPHO_TOKEN"),
                getAddress("MORPHO_WRAPPER")
            );
            generalAdapter1 = GeneralAdapter1(ethereumGeneralAdapter1);
        } else {
            generalAdapter1 = new GeneralAdapter1(address(bundler3), address(morpho), getAddress("WETH"));
        }
        paraswapAdapter = new ParaswapAdapter(address(bundler3), address(morpho), getAddress("AUGUSTUS_REGISTRY"));

        for (uint256 i; i < config.markets.length; ++i) {
            ConfigMarket memory configMarket = config.markets[i];

            MarketParams memory marketParams = MarketParams({
                collateralToken: getAddress(configMarket.collateralToken),
                loanToken: getAddress(configMarket.loanToken),
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
        morpho.setAuthorization(address(generalAdapter1), true);
    }

    // Checks that two `string` values are equal.
    function isEq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    function deal(address asset, address recipient, uint256 amount) internal virtual override {
        address wEth = getAddress("WETH");
        address stEth = getAddress("ST_ETH");

        if (amount == 0) return;

        if (asset == wEth) super.deal(wEth, wEth.balance + amount); // Refill wrapped Ether.

        if (asset == stEth) {
            deal(recipient, amount);

            vm.prank(recipient);
            uint256 stEthAmount = IStEth(stEth).submit{value: amount}(address(0));

            vm.assume(stEthAmount != 0);

            return;
        }

        return super.deal(asset, recipient, amount);
    }

    modifier onlyEthereum() {
        vm.skip(block.chainid != 1);
        _;
    }

    modifier onlyBase() {
        vm.skip(block.chainid != 8453);
        _;
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
            spender: address(generalAdapter1),
            sigDeadline: SIGNATURE_DEADLINE
        });

        bytes32 digest = SigUtils.toTypedDataHash(Permit2Lib.PERMIT2.DOMAIN_SEPARATOR(), permitSingle);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        return _call(
            address(Permit2Lib.PERMIT2),
            abi.encodeWithSelector(permitSingleSelector, vm.addr(privateKey), permitSingle, abi.encodePacked(r, s, v)),
            0,
            skipRevert
        );
    }

    function _approve2Batch(
        uint256 privateKey,
        address[] memory assets,
        uint256[] memory amounts,
        uint256[] memory nonces,
        bool skipRevert
    ) internal view returns (Call memory) {
        IAllowanceTransfer.PermitDetails[] memory details = new IAllowanceTransfer.PermitDetails[](assets.length);

        for (uint256 i; i < assets.length; i++) {
            details[i] = IAllowanceTransfer.PermitDetails({
                token: assets[i],
                amount: uint160(amounts[i]),
                expiration: type(uint48).max,
                nonce: uint48(nonces[i])
            });
        }

        IAllowanceTransfer.PermitBatch memory permitBatch = IAllowanceTransfer.PermitBatch({
            details: details,
            spender: address(generalAdapter1),
            sigDeadline: SIGNATURE_DEADLINE
        });

        bytes32 digest = SigUtils.toTypedDataHash(Permit2Lib.PERMIT2.DOMAIN_SEPARATOR(), permitBatch);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        return _call(
            address(Permit2Lib.PERMIT2),
            abi.encodeWithSelector(permitBatchSelector, vm.addr(privateKey), permitBatch, abi.encodePacked(r, s, v)),
            0,
            skipRevert
        );
    }

    function _permit2TransferFrom(address asset, uint256 amount) internal view returns (Call memory) {
        return _permit2TransferFrom(asset, address(generalAdapter1), amount);
    }

    function _permit2TransferFrom(address asset, address receiver, uint256 amount)
        internal
        view
        returns (Call memory)
    {
        return _call(generalAdapter1, abi.encodeCall(GeneralAdapter1.permit2TransferFrom, (asset, receiver, amount)));
    }

    /* STAKE ACTIONS */

    function _stakeEth(uint256 amount, uint256 maxSharePriceE27, address referral, address receiver)
        internal
        view
        returns (Call memory)
    {
        return _call(
            ethereumGeneralAdapter1,
            abi.encodeCall(EthereumGeneralAdapter1.stakeEth, (amount, maxSharePriceE27, referral, receiver))
        );
    }

    /* wstETH ACTIONS */

    function _wrapStEth(uint256 amount, address receiver) internal view returns (Call memory) {
        return _call(ethereumGeneralAdapter1, abi.encodeCall(EthereumGeneralAdapter1.wrapStEth, (amount, receiver)));
    }

    function _unwrapStEth(uint256 amount, address receiver) internal view returns (Call memory) {
        return _call(ethereumGeneralAdapter1, abi.encodeCall(EthereumGeneralAdapter1.unwrapStEth, (amount, receiver)));
    }

    /* WRAPPED NATIVE ACTIONS */

    function _wrapNativeNoFunding(uint256 amount, address receiver) internal view returns (Call memory) {
        return _call(generalAdapter1, abi.encodeCall(GeneralAdapter1.wrapNative, (amount, receiver)), uint256(0));
    }

    function _wrapNative(uint256 amount, address receiver) internal view returns (Call memory) {
        return _call(generalAdapter1, abi.encodeCall(GeneralAdapter1.wrapNative, (amount, receiver)));
    }

    function _unwrapNative(uint256 amount, address receiver) internal view returns (Call memory) {
        return _call(generalAdapter1, abi.encodeCall(GeneralAdapter1.unwrapNative, (amount, receiver)));
    }
}
