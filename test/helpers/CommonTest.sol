// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {
    IMorpho,
    Id,
    MarketParams,
    Authorization as MorphoBlueAuthorization,
    Signature as MorphoBlueSignature
} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

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
import {WETH as WethContract} from "../../lib/solmate/src/tokens/WETH.sol";

import {BaseModule} from "../../src/BaseModule.sol";
import {FunctionMocker} from "./FunctionMocker.sol";
import {GenericModule1} from "../../src/GenericModule1.sol";
import {Bundler, Call, ModeLib, Mode} from "../../src/Bundler.sol";

import "../../lib/forge-std/src/Test.sol";
import "../../lib/forge-std/src/console2.sol";

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
        console.log("OK?");
        vm.label(address(morpho), "Morpho");

        functionMocker = new FunctionMocker();

        bundler = new Bundler();
        genericModule1 = new GenericModule1(address(bundler), address(morpho), address(new WethContract()));

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

    function _boundPrivateKey(uint256 privateKey) internal returns (uint256) {
        privateKey = bound(privateKey, 1, type(uint160).max);

        address user = vm.addr(privateKey);
        vm.label(user, "address of generated private key");

        return privateKey;
    }

    function _delegatePrank(address target, bytes memory callData) internal {
        vm.mockFunction(target, address(functionMocker), callData);
        (bool success,) = target.call(callData);
        require(success, "Function mocker call failed");
    }

    // Pick a uint stable by timestamp.
    /// The environment variable PICK_UINT can be used to force a specific uint.
    // Used to make fork tests faster.
    function pickUint() internal view returns (uint256) {
        bytes32 _hash = keccak256(bytes.concat("pickUint", bytes32(block.timestamp)));
        uint256 num = uint256(_hash);
        return vm.envOr("PICK_UINT", num);
    }

    /* GENERIC MODULE CALL */
    function _call(BaseModule module, bytes memory data) internal pure returns (Call memory) {
        return _call(false, module, data, 0);
    }

    function _call(BaseModule module, bytes memory data, uint256 value) internal pure returns (Call memory) {
        return _call(false, module, data, value);
    }

    function _call(bool skipRevert, BaseModule module, bytes memory data, uint256 value)
        internal
        pure
        returns (Call memory)
    {
        require(address(module) != address(0), "Module address is zero");
        Mode mode = ModeLib.wrap(skipRevert, address(module));
        return Call(mode, data, value);
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

    function _erc4626Mint(address vault, uint256 shares, uint256 maxSharePriceE27, address receiver)
        internal
        view
        returns (Call memory)
    {
        return _call(
            genericModule1, abi.encodeCall(GenericModule1.erc4626Mint, (vault, shares, maxSharePriceE27, receiver))
        );
    }

    function _erc4626Deposit(address vault, uint256 assets, uint256 maxSharePriceE27, address receiver)
        internal
        view
        returns (Call memory)
    {
        return _call(
            genericModule1, abi.encodeCall(GenericModule1.erc4626Deposit, (vault, assets, maxSharePriceE27, receiver))
        );
    }

    function _erc4626Withdraw(address vault, uint256 assets, uint256 minSharePriceE27, address receiver, address owner)
        internal
        view
        returns (Call memory)
    {
        return _call(
            genericModule1,
            abi.encodeCall(GenericModule1.erc4626Withdraw, (vault, assets, minSharePriceE27, receiver, owner))
        );
    }

    function _erc4626Redeem(address vault, uint256 shares, uint256 minSharePriceE27, address receiver, address owner)
        internal
        view
        returns (Call memory)
    {
        return _call(
            genericModule1,
            abi.encodeCall(GenericModule1.erc4626Redeem, (vault, shares, minSharePriceE27, receiver, owner))
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
        uint256 maxSharePriceE27,
        address onBehalf,
        bytes memory data
    ) internal view returns (Call memory) {
        return _call(
            genericModule1,
            abi.encodeCall(
                GenericModule1.morphoSupply, (marketParams, assets, shares, maxSharePriceE27, onBehalf, data)
            )
        );
    }

    function _morphoBorrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        uint256 minSharePriceE27,
        address receiver
    ) internal view returns (Call memory) {
        return _call(
            genericModule1,
            abi.encodeCall(GenericModule1.morphoBorrow, (marketParams, assets, shares, minSharePriceE27, receiver))
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
        uint256 maxSharePriceE27,
        address onBehalf,
        bytes memory data
    ) internal view returns (Call memory) {
        return _call(
            genericModule1,
            abi.encodeCall(GenericModule1.morphoRepay, (marketParams, assets, shares, maxSharePriceE27, onBehalf, data))
        );
    }

    function _morphoSupplyCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address onBehalf,
        bytes memory data
    ) internal view returns (Call memory) {
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

    function _morphoFlashLoan(address token, uint256 amount, bytes memory data) internal view returns (Call memory) {
        return _call(genericModule1, abi.encodeCall(GenericModule1.morphoFlashLoan, (token, amount, data)));
    }
}
