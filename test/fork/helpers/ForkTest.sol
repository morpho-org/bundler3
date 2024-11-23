// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IStEth} from "../../../src/interfaces/IStEth.sol";
import {IWstEth} from "../../../src/interfaces/IWstEth.sol";
import {IAllowanceTransfer} from "../../../lib/permit2/src/interfaces/IAllowanceTransfer.sol";

import {Permit2Lib} from "../../../lib/permit2/src/libraries/Permit2Lib.sol";

import {EthereumModule1} from "../../../src/ethereum/EthereumModule1.sol";

import "./NetworkConfig.sol";
import "../../helpers/CommonTest.sol";

abstract contract ForkTest is CommonTest, NetworkConfig {
    using SafeTransferLib for ERC20;

    EthereumModule1 internal ethereumModule1;
    MarketParams[] allMarketParams;

    function initializeConfig() internal override returns (bool) {
        // Run tests on Ethereum by default
        if (block.chainid == 31337) vm.chainId(1);
        return super.initializeConfig();
    }

    function setUp() public virtual override {
        string memory rpc = vm.rpcUrl(config.network);

        if (config.blockNumber == 0) vm.createSelectFork(rpc);
        else vm.createSelectFork(rpc, config.blockNumber);

        super.setUp();

        if (checkEq(config.network, "ethereum")) {
            ethereumModule1 = new EthereumModule1(
                address(bundler),
                address(morpho),
                getAddress("WETH"),
                getAddress("DAI"),
                getAddress("WST_ETH"),
                getAddress("MORPHO_TOKEN"),
                getAddress("MORPHO_WRAPPER")
            );
            genericModule1 = GenericModule1(ethereumModule1);
        } else {
            genericModule1 = new GenericModule1(address(bundler), address(morpho), getAddress("WETH"));
        }

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
        morpho.setAuthorization(address(genericModule1), true);
    }

    // Checks that two `string` values are equal.
    function checkEq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    function deal(address asset, address recipient, uint256 amount) internal virtual override {
        address _WETH = getAddress("WETH");
        address _ST_ETH = getAddress("ST_ETH");

        if (amount == 0) return;

        if (asset == _WETH) super.deal(_WETH, _WETH.balance + amount); // Refill wrapped Ether.

        if (asset == _ST_ETH) {
            if (amount == 0) return;

            deal(recipient, amount);

            vm.prank(recipient);
            uint256 stEthAmount = IStEth(_ST_ETH).submit{value: amount}(address(0));

            vm.assume(stEthAmount != 0);

            return;
        }

        return super.deal(asset, recipient, amount);
    }

    modifier onlyEthereum() {
        vm.skip(block.chainid != 1);
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
            spender: address(genericModule1),
            sigDeadline: SIGNATURE_DEADLINE
        });

        bytes32 digest = SigUtils.toTypedDataHash(Permit2Lib.PERMIT2.DOMAIN_SEPARATOR(), permitBatch);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        return _call(
            genericModule1,
            abi.encodeCall(GenericModule1.approve2Batch, (permitBatch, abi.encodePacked(r, s, v), skipRevert))
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
            ethereumModule1, abi.encodeCall(EthereumModule1.stakeEth, (amount, shares, referral, receiver)), callValue
        );
    }

    /* wstETH ACTIONS */

    function _wrapStEth(uint256 amount, address receiver) internal view returns (Call memory) {
        return _call(ethereumModule1, abi.encodeCall(EthereumModule1.wrapStEth, (amount, receiver)));
    }

    function _unwrapStEth(uint256 amount, address receiver) internal view returns (Call memory) {
        return _call(ethereumModule1, abi.encodeCall(EthereumModule1.unwrapStEth, (amount, receiver)));
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
