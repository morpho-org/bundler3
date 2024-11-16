// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {
    IMorpho,
    Id,
    MarketParams,
    Authorization as MorphoBlueAuthorization,
    Signature as MorphoBlueSignature
} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IPublicAllocatorBase} from "../../lib/public-allocator/src/interfaces/IPublicAllocator.sol";

import {SigUtils} from "./SigUtils.sol";
import {MarketParamsLib} from "../../lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import {SharesMathLib} from "../../lib/morpho-blue/src/libraries/SharesMathLib.sol";
import {MathLib, WAD} from "../../lib/morpho-blue/src/libraries/MathLib.sol";
import {UtilsLib} from "../../lib/morpho-blue/src/libraries/UtilsLib.sol";
import {SafeTransferLib, ERC20} from "../../lib/solmate/src/utils/SafeTransferLib.sol";
import {MorphoLib} from "../../lib/morpho-blue/src/libraries/periphery/MorphoLib.sol";
import {MorphoBalancesLib} from "../../lib/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";
import {
    LIQUIDATION_CURSOR,
    MAX_LIQUIDATION_INCENTIVE_FACTOR,
    ORACLE_PRICE_SCALE
} from "../../lib/morpho-blue/src/libraries/ConstantsLib.sol";

import {IrmMock} from "../../lib/morpho-blue/src/mocks/IrmMock.sol";
import {OracleMock} from "../../lib/morpho-blue/src/mocks/OracleMock.sol";
import {WETH} from "../../lib/solmate/src/tokens/WETH.sol";

import {BaseModule} from "../../src/BaseModule.sol";
import {FunctionMocker} from "./FunctionMocker.sol";
import {GenericModule1, Withdrawal} from "../../src/GenericModule1.sol";
import {Bundler} from "../../src/Bundler.sol";
import {Call} from "../../src/interfaces/Call.sol";

import "../../lib/forge-std/src/Test.sol";
import "../../lib/forge-std/src/console2.sol";

// Simplify bundler.multicall in the absence of callbacks when writing tests.
library BundlerLib {
    function multicall(Bundler bundler, Call[] memory bundle) internal {
        bundler.multicall(bundle, new bytes32[](0));
    }
}

uint256 constant MIN_AMOUNT = 1000;
uint256 constant MAX_AMOUNT = 2 ** 64; // Must be less than or equal to type(uint160).max.
uint256 constant SIGNATURE_DEADLINE = type(uint32).max;

abstract contract CommonTest is Test {
    using MathLib for uint256;
    using SharesMathLib for uint256;
    using MarketParamsLib for MarketParams;
    using SafeTransferLib for ERC20;
    using stdJson for string;

    address internal USER = makeAddr("User");
    address internal SUPPLIER = makeAddr("Owner");
    address internal OWNER = makeAddr("Supplier");
    address internal RECEIVER = makeAddr("Receiver");
    address internal LIQUIDATOR = makeAddr("Liquidator");

    IMorpho internal morpho;
    IrmMock internal irm;
    OracleMock internal oracle;

    Bundler internal bundler;
    GenericModule1 internal genericModule1;

    Call[] internal bundle;
    Call[] internal callbackBundle;

    FunctionMocker functionMocker;

    function setUp() public virtual {
        morpho = IMorpho(deployCode("Morpho.sol", abi.encode(OWNER)));
        vm.label(address(morpho), "Morpho");

        functionMocker = new FunctionMocker();

        bundler = new Bundler();
        genericModule1 = new GenericModule1(address(bundler), address(morpho), address(new WETH()));

        irm = new IrmMock();

        vm.startPrank(OWNER);
        morpho.enableIrm(address(irm));
        morpho.enableIrm(address(0));
        morpho.enableLltv(0);
        vm.stopPrank();

        oracle = new OracleMock();
        oracle.setPrice(ORACLE_PRICE_SCALE);

        vm.prank(USER);
        // So tests can borrow/withdraw on behalf of USER without pranking it.
        morpho.setAuthorization(address(this), true);
    }

    function _boundPrivateKey(uint256 privateKey) internal returns (uint256, address) {
        privateKey = bound(privateKey, 1, type(uint160).max);

        address user = vm.addr(privateKey);
        vm.label(user, "User");

        return (privateKey, user);
    }

    function _delegatePrank(address target, bytes memory callData) internal {
        vm.mockFunction(target, address(functionMocker), callData);
        (bool success,) = target.call(callData);
        require(success, "Function mocker call failed");
    }

    function _hashBundles(Call[] memory _bundle) internal pure returns (bytes32[] memory) {
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256(abi.encode(_bundle));
        return hashes;
    }

    function _hashBundles(Call[] memory bundle0, Call[] memory bundle1) internal pure returns (bytes32[] memory) {
        bytes32[] memory hashes = new bytes32[](2);
        hashes[0] = keccak256(abi.encode(bundle0));
        hashes[1] = keccak256(abi.encode(bundle1));
        return hashes;
    }

    /* GENERIC MODULE CALL */
    function _call(BaseModule module, bytes memory data) internal pure returns (Call memory) {
        return _call(module, data, 0);
    }

    function _call(BaseModule module, bytes memory data, uint256 value) internal pure returns (Call memory) {
        require(address(module) != address(0), "Module address is zero");
        return Call({to: address(module), data: data, value: value});
    }

    /* TRANSFER */

    function _nativeTransfer(address recipient, uint256 amount, BaseModule module)
        internal
        pure
        returns (Call memory)
    {
        return _call(module, abi.encodeCall(module.nativeTransfer, (recipient, amount)), amount);
    }

    function _nativeTransferNoFunding(address recipient, uint256 amount, BaseModule module)
        internal
        pure
        returns (Call memory)
    {
        return _call(module, abi.encodeCall(module.nativeTransfer, (recipient, amount)), 0);
    }

    /* ERC20 ACTIONS */

    function _erc20Transfer(address token, address recipient, uint256 amount, BaseModule module)
        internal
        pure
        returns (Call memory)
    {
        return _call(module, abi.encodeCall(module.erc20Transfer, (token, recipient, amount)));
    }

    function _erc20TransferFrom(address token, address recipient, uint256 amount) internal view returns (Call memory) {
        return _call(genericModule1, abi.encodeCall(GenericModule1.erc20TransferFrom, (token, recipient, amount)));
    }

    function _erc20TransferFrom(address token, uint256 amount) internal view returns (Call memory) {
        return _erc20TransferFrom(token, address(genericModule1), amount);
    }

    /* ERC20 WRAPPER ACTIONS */

    function _erc20WrapperDepositFor(address token, address receiver, uint256 amount)
        internal
        view
        returns (Call memory)
    {
        return _call(genericModule1, abi.encodeCall(GenericModule1.erc20WrapperDepositFor, (token, receiver, amount)));
    }

    function _erc20WrapperWithdrawTo(address token, address receiver, uint256 amount)
        internal
        view
        returns (Call memory)
    {
        return _call(genericModule1, abi.encodeCall(GenericModule1.erc20WrapperWithdrawTo, (token, receiver, amount)));
    }

    /* ERC4626 ACTIONS */

    function _erc4626Mint(address vault, uint256 shares, uint256 maxAssets, address receiver)
        internal
        view
        returns (Call memory)
    {
        return _call(genericModule1, abi.encodeCall(GenericModule1.erc4626Mint, (vault, shares, maxAssets, receiver)));
    }

    function _erc4626Deposit(address vault, uint256 assets, uint256 minShares, address receiver)
        internal
        view
        returns (Call memory)
    {
        return
            _call(genericModule1, abi.encodeCall(GenericModule1.erc4626Deposit, (vault, assets, minShares, receiver)));
    }

    function _erc4626Withdraw(address vault, uint256 assets, uint256 maxShares, address receiver, address owner)
        internal
        view
        returns (Call memory)
    {
        return _call(
            genericModule1, abi.encodeCall(GenericModule1.erc4626Withdraw, (vault, assets, maxShares, receiver, owner))
        );
    }

    function _erc4626Redeem(address vault, uint256 shares, uint256 minAssets, address receiver, address owner)
        internal
        view
        returns (Call memory)
    {
        return _call(
            genericModule1, abi.encodeCall(GenericModule1.erc4626Redeem, (vault, shares, minAssets, receiver, owner))
        );
    }

    /* URD ACTIONS */

    function _urdClaim(
        address distributor,
        address account,
        address reward,
        uint256 amount,
        bytes32[] memory proof,
        bool skipRevert
    ) internal view returns (Call memory) {
        return _call(
            genericModule1,
            abi.encodeCall(GenericModule1.urdClaim, (distributor, account, reward, amount, proof, skipRevert))
        );
    }

    /* MORPHO ACTIONS */

    function _morphoSetAuthorizationWithSig(uint256 privateKey, bool isAuthorized, uint256 nonce, bool skipRevert)
        internal
        view
        returns (Call memory)
    {
        address user = vm.addr(privateKey);

        MorphoBlueAuthorization memory authorization = MorphoBlueAuthorization({
            authorizer: user,
            authorized: address(genericModule1),
            isAuthorized: isAuthorized,
            nonce: nonce,
            deadline: SIGNATURE_DEADLINE
        });

        bytes32 digest = SigUtils.toTypedDataHash(morpho.DOMAIN_SEPARATOR(), authorization);

        MorphoBlueSignature memory signature;
        (signature.v, signature.r, signature.s) = vm.sign(privateKey, digest);

        return _call(
            genericModule1,
            abi.encodeCall(GenericModule1.morphoSetAuthorizationWithSig, (authorization, signature, skipRevert))
        );
    }

    function _morphoSupply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        uint256 slippageAmount,
        address onBehalf
    ) internal view returns (Call memory) {
        bytes memory data;
        if (callbackBundle.length > 0) {
            data = abi.encode(callbackBundle);
        }
        return _call(
            genericModule1,
            abi.encodeCall(GenericModule1.morphoSupply, (marketParams, assets, shares, slippageAmount, onBehalf, data))
        );
    }

    function _morphoBorrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        uint256 slippageAmount,
        address receiver
    ) internal view returns (Call memory) {
        return _call(
            genericModule1,
            abi.encodeCall(GenericModule1.morphoBorrow, (marketParams, assets, shares, slippageAmount, receiver))
        );
    }

    function _morphoWithdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        uint256 slippageAmount,
        address receiver
    ) internal view returns (Call memory) {
        return _call(
            genericModule1,
            abi.encodeCall(GenericModule1.morphoWithdraw, (marketParams, assets, shares, slippageAmount, receiver))
        );
    }

    function _morphoRepay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        uint256 slippageAmount,
        address onBehalf
    ) internal view returns (Call memory) {
        bytes memory data;
        if (callbackBundle.length > 0) {
            data = abi.encode(callbackBundle);
        }
        return _call(
            genericModule1,
            abi.encodeCall(GenericModule1.morphoRepay, (marketParams, assets, shares, slippageAmount, onBehalf, data))
        );
    }

    function _morphoSupplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf)
        internal
        view
        returns (Call memory)
    {
        bytes memory data;
        if (callbackBundle.length > 0) {
            data = abi.encode(callbackBundle);
        }
        return _call(
            genericModule1,
            abi.encodeCall(GenericModule1.morphoSupplyCollateral, (marketParams, assets, onBehalf, data))
        );
    }

    function _morphoWithdrawCollateral(MarketParams memory marketParams, uint256 assets, address receiver)
        internal
        view
        returns (Call memory)
    {
        return _call(
            genericModule1, abi.encodeCall(GenericModule1.morphoWithdrawCollateral, (marketParams, assets, receiver))
        );
    }

    function _morphoFlashLoan(address token, uint256 amount) internal view returns (Call memory) {
        bytes memory data;
        if (callbackBundle.length > 0) {
            data = abi.encode(callbackBundle);
        }
        return _call(genericModule1, abi.encodeCall(GenericModule1.morphoFlashLoan, (token, amount, data)));
    }

    function _reallocateTo(
        address publicAllocator,
        address vault,
        uint256 value,
        Withdrawal[] memory withdrawals,
        MarketParams memory supplyMarketParams
    ) internal view returns (Call memory) {
        return _call(
            genericModule1,
            abi.encodeCall(
                GenericModule1.reallocateTo, (publicAllocator, vault, value, withdrawals, supplyMarketParams)
            ),
            value
        );
    }
}
