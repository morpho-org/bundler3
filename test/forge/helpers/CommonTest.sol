// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {
    IMorpho,
    Id,
    MarketParams,
    Authorization as MorphoBlueAuthorization,
    Signature as MorphoBlueSignature
} from "../../../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IPublicAllocatorBase} from "../../../lib/public-allocator/src/interfaces/IPublicAllocator.sol";

import {SigUtils} from "./SigUtils.sol";
import {MarketParamsLib} from "../../../lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import {SharesMathLib} from "../../../lib/morpho-blue/src/libraries/SharesMathLib.sol";
import {MathLib, WAD} from "../../../lib/morpho-blue/src/libraries/MathLib.sol";
import {UtilsLib} from "../../../lib/morpho-blue/src/libraries/UtilsLib.sol";
import {SafeTransferLib, ERC20} from "../../../lib/solmate/src/utils/SafeTransferLib.sol";
import {MorphoLib} from "../../../lib/morpho-blue/src/libraries/periphery/MorphoLib.sol";
import {MorphoBalancesLib} from "../../../lib/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";
import {
    LIQUIDATION_CURSOR,
    MAX_LIQUIDATION_INCENTIVE_FACTOR,
    ORACLE_PRICE_SCALE
} from "../../../lib/morpho-blue/src/libraries/ConstantsLib.sol";

import {IrmMock} from "../../../lib/morpho-blue/src/mocks/IrmMock.sol";
import {OracleMock} from "../../../lib/morpho-blue/src/mocks/OracleMock.sol";
import {WETH} from "../../../lib/solmate/src/tokens/WETH.sol";

import {BaseBundler} from "../../../src/BaseBundler.sol";
import {PermitBundler} from "../../../src/PermitBundler.sol";
import {ERC4626Bundler} from "../../../src/ERC4626Bundler.sol";
import {UrdBundler} from "../../../src/UrdBundler.sol";
import {MorphoBundler, Withdrawal} from "../../../src/MorphoBundler.sol";
import {ERC20WrapperBundler} from "../../../src/ERC20WrapperBundler.sol";
import {FunctionMocker} from "./FunctionMocker.sol";
import {GenericBundler1} from "../../../src/chain-agnostic/GenericBundler1.sol";
import {TransferBundler} from "../../../src/TransferBundler.sol";
import {Hub} from "../../../src/Hub.sol";
import {Call} from "../../../src/interfaces/Call.sol";

import "../../../lib/forge-std/src/Test.sol";
import "../../../lib/forge-std/src/console2.sol";

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

    Hub internal hub;
    GenericBundler1 internal genericBundler1;

    Call[] internal bundle;
    Call[] internal callbackBundle;

    FunctionMocker functionMocker;

    function setUp() public virtual {
        morpho = IMorpho(deployCode("Morpho.sol", abi.encode(OWNER)));
        vm.label(address(morpho), "Morpho");

        functionMocker = new FunctionMocker();

        hub = new Hub();
        genericBundler1 = new GenericBundler1(address(hub), address(morpho), address(new WETH()));

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

    /* GENERIC BUNDLER CALL */
    function _call(BaseBundler bundler, bytes memory data) internal pure returns (Call memory) {
        return _call(bundler, data, 0);
    }

    function _call(BaseBundler bundler, bytes memory data, uint256 value) internal pure returns (Call memory) {
        return Call({to: address(bundler), data: data, value: value});
    }

    /* TRANSFER */

    function _nativeTransfer(address recipient, uint256 amount, BaseBundler bundler)
        internal
        pure
        returns (Call memory)
    {
        return _call(bundler, abi.encodeCall(bundler.nativeTransfer, (recipient, amount)), amount);
    }

    function _nativeTransferNoFunding(address recipient, uint256 amount, BaseBundler bundler)
        internal
        pure
        returns (Call memory)
    {
        return _call(bundler, abi.encodeCall(bundler.nativeTransfer, (recipient, amount)), 0);
    }

    /* ERC20 ACTIONS */

    function _erc20Transfer(address token, address recipient, uint256 amount, BaseBundler bundler)
        internal
        pure
        returns (Call memory)
    {
        return _call(bundler, abi.encodeCall(bundler.erc20Transfer, (token, recipient, amount)));
    }

    function _erc20TransferFrom(address token, uint256 amount) internal view returns (Call memory) {
        return _call(
            genericBundler1,
            abi.encodeCall(TransferBundler.erc20TransferFrom, (token, address(genericBundler1), amount))
        );
    }

    /* ERC20 WRAPPER ACTIONS */

    function _erc20WrapperDepositFor(address token, address receiver, uint256 amount)
        internal
        view
        returns (Call memory)
    {
        return _call(
            genericBundler1, abi.encodeCall(ERC20WrapperBundler.erc20WrapperDepositFor, (token, receiver, amount))
        );
    }

    function _erc20WrapperWithdrawTo(address token, address receiver, uint256 amount)
        internal
        view
        returns (Call memory)
    {
        return _call(
            genericBundler1, abi.encodeCall(ERC20WrapperBundler.erc20WrapperWithdrawTo, (token, receiver, amount))
        );
    }

    /* ERC4626 ACTIONS */

    function _erc4626Mint(address vault, uint256 shares, uint256 maxAssets, address receiver)
        internal
        view
        returns (Call memory)
    {
        return _call(genericBundler1, abi.encodeCall(ERC4626Bundler.erc4626Mint, (vault, shares, maxAssets, receiver)));
    }

    function _erc4626Deposit(address vault, uint256 assets, uint256 minShares, address receiver)
        internal
        view
        returns (Call memory)
    {
        return
            _call(genericBundler1, abi.encodeCall(ERC4626Bundler.erc4626Deposit, (vault, assets, minShares, receiver)));
    }

    function _erc4626Withdraw(address vault, uint256 assets, uint256 maxShares, address receiver, address owner)
        internal
        view
        returns (Call memory)
    {
        return _call(
            genericBundler1, abi.encodeCall(ERC4626Bundler.erc4626Withdraw, (vault, assets, maxShares, receiver, owner))
        );
    }

    function _erc4626Redeem(address vault, uint256 shares, uint256 minAssets, address receiver, address owner)
        internal
        view
        returns (Call memory)
    {
        return _call(
            genericBundler1, abi.encodeCall(ERC4626Bundler.erc4626Redeem, (vault, shares, minAssets, receiver, owner))
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
            genericBundler1,
            abi.encodeCall(UrdBundler.urdClaim, (distributor, account, reward, amount, proof, skipRevert))
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
            authorized: address(genericBundler1),
            isAuthorized: isAuthorized,
            nonce: nonce,
            deadline: SIGNATURE_DEADLINE
        });

        bytes32 digest = SigUtils.toTypedDataHash(morpho.DOMAIN_SEPARATOR(), authorization);

        MorphoBlueSignature memory signature;
        (signature.v, signature.r, signature.s) = vm.sign(privateKey, digest);

        return _call(
            genericBundler1,
            abi.encodeCall(MorphoBundler.morphoSetAuthorizationWithSig, (authorization, signature, skipRevert))
        );
    }

    function _morphoSupply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        uint256 slippageAmount,
        address onBehalf
    ) internal view returns (Call memory) {
        return _call(
            genericBundler1,
            abi.encodeCall(
                MorphoBundler.morphoSupply,
                (marketParams, assets, shares, slippageAmount, onBehalf, abi.encode(callbackBundle))
            )
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
            genericBundler1,
            abi.encodeCall(MorphoBundler.morphoBorrow, (marketParams, assets, shares, slippageAmount, receiver))
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
            genericBundler1,
            abi.encodeCall(MorphoBundler.morphoWithdraw, (marketParams, assets, shares, slippageAmount, receiver))
        );
    }

    function _morphoRepay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        uint256 slippageAmount,
        address onBehalf
    ) internal view returns (Call memory) {
        return _call(
            genericBundler1,
            abi.encodeCall(
                MorphoBundler.morphoRepay,
                (marketParams, assets, shares, slippageAmount, onBehalf, abi.encode(callbackBundle))
            )
        );
    }

    function _morphoSupplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf)
        internal
        view
        returns (Call memory)
    {
        return _call(
            genericBundler1,
            abi.encodeCall(
                MorphoBundler.morphoSupplyCollateral, (marketParams, assets, onBehalf, abi.encode(callbackBundle))
            )
        );
    }

    function _morphoWithdrawCollateral(MarketParams memory marketParams, uint256 assets, address receiver)
        internal
        view
        returns (Call memory)
    {
        return _call(
            genericBundler1, abi.encodeCall(MorphoBundler.morphoWithdrawCollateral, (marketParams, assets, receiver))
        );
    }

    function _morphoFlashLoan(address token, uint256 amount) internal view returns (Call memory) {
        return _call(
            genericBundler1, abi.encodeCall(MorphoBundler.morphoFlashLoan, (token, amount, abi.encode(callbackBundle)))
        );
    }

    function _reallocateTo(
        address publicAllocator,
        address vault,
        uint256 value,
        Withdrawal[] memory withdrawals,
        MarketParams memory supplyMarketParams
    ) internal view returns (Call memory) {
        return _call(
            genericBundler1,
            abi.encodeCall(MorphoBundler.reallocateTo, (publicAllocator, vault, value, withdrawals, supplyMarketParams)),
            value
        );
    }
}
