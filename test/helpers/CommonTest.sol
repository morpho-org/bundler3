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
import {IParaswapModule, Offsets} from "../../src/interfaces/IParaswapModule.sol";
import {ParaswapModule} from "../../src/ParaswapModule.sol";
import {IERC20Permit} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {Permit} from "../helpers/SigUtils.sol";
import {IUniversalRewardsDistributorBase} from
    "../../lib/universal-rewards-distributor/src/interfaces/IUniversalRewardsDistributor.sol";

import {BaseModule} from "../../src/BaseModule.sol";
import {FunctionMocker} from "./FunctionMocker.sol";
import {GenericModule1} from "../../src/GenericModule1.sol";
import {Bundler, Call} from "../../src/Bundler.sol";

import {AugustusRegistryMock} from "../../src/mocks/AugustusRegistryMock.sol";
import {AugustusMock} from "../../src/mocks/AugustusMock.sol";

import "../../lib/forge-std/src/Test.sol";
import "../../lib/forge-std/src/console.sol";

uint256 constant MIN_AMOUNT = 1000;
uint256 constant MAX_AMOUNT = 2 ** 64; // Must be less than or equal to type(uint160).max.
uint256 constant SIGNATURE_DEADLINE = type(uint32).max;

abstract contract CommonTest is Test {
    using MathLib for uint256;
    using SharesMathLib for uint256;
    using MarketParamsLib for MarketParams;
    using SafeTransferLib for ERC20;
    using stdJson for string;

    address internal immutable USER = makeAddr("User");
    address internal immutable SUPPLIER = makeAddr("Owner");
    address internal immutable OWNER = makeAddr("Supplier");
    address internal immutable RECEIVER = makeAddr("Receiver");
    address internal immutable LIQUIDATOR = makeAddr("Liquidator");

    IMorpho internal morpho;
    IrmMock internal irm;
    OracleMock internal oracle;

    Bundler internal bundler;
    GenericModule1 internal genericModule1;

    ParaswapModule paraswapModule;

    AugustusRegistryMock augustusRegistryMock;
    AugustusMock augustus;

    Call[] internal bundle;
    Call[] internal callbackBundle;

    FunctionMocker internal functionMocker;

    function setUp() public virtual {
        morpho = IMorpho(deployCode("Morpho.sol", abi.encode(OWNER)));
        console.log("OK?");
        vm.label(address(morpho), "Morpho");

        augustusRegistryMock = new AugustusRegistryMock();
        functionMocker = new FunctionMocker();

        bundler = new Bundler();
        genericModule1 = new GenericModule1(address(bundler), address(morpho), address(new WethContract()));
        paraswapModule = new ParaswapModule(address(augustusRegistryMock));

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

    function emptyMarketParams() internal pure returns (MarketParams memory _emptyMarketParams) {}

    function _boundPrivateKey(uint256 privateKey) internal returns (uint256) {
        privateKey = bound(privateKey, 1, type(uint160).max);

        address user = vm.addr(privateKey);
        vm.label(user, "address of generated private key");

        return privateKey;
    }

    function _supplyCollateral(MarketParams memory _marketParams, uint256 amount, address onBehalf) internal {
        deal(_marketParams.collateralToken, onBehalf, amount, true);
        vm.prank(onBehalf);
        morpho.supplyCollateral(_marketParams, amount, onBehalf, hex"");
    }

    function _supply(MarketParams memory _marketParams, uint256 amount, address onBehalf) internal {
        deal(_marketParams.loanToken, onBehalf, amount, true);
        vm.prank(onBehalf);
        morpho.supply(_marketParams, amount, 0, onBehalf, hex"");
    }

    function _borrow(MarketParams memory _marketParams, uint256 amount, address onBehalf) internal {
        vm.prank(onBehalf);
        morpho.borrow(_marketParams, amount, 0, onBehalf, onBehalf);
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
        return _call(module, data, 0, false);
    }

    function _call(BaseModule module, bytes memory data, uint256 value) internal pure returns (Call memory) {
        return _call(module, data, value, false);
    }

    function _call(BaseModule module, bytes memory data, uint256 value, bool skipRevert)
        internal
        pure
        returns (Call memory)
    {
        require(address(module) != address(0), "Module address is zero");
        address to = address(module);
        return Call(to, data, value, skipRevert);
    }

    /* CALL WITH VALUE */

    function _sendNativeToModule(address payable module, uint256 amount) internal pure returns (Call memory) {
        return _call(BaseModule(module), hex"", amount);
    }

    /* TRANSFER */

    function _nativeTransfer(address recipient, uint256 amount, BaseModule module)
        internal
        pure
        returns (Call memory)
    {
        return _call(module, abi.encodeCall(module.nativeTransfer, (recipient, amount)));
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
        uint256 claimable,
        bytes32[] memory proof,
        bool skipRevert
    ) internal pure returns (Call memory) {
        return _call(
            BaseModule(payable(address(distributor))),
            abi.encodeCall(IUniversalRewardsDistributorBase.claim, (account, reward, claimable, proof)),
            0,
            skipRevert
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
            BaseModule(payable(address(morpho))),
            abi.encodeCall(morpho.setAuthorizationWithSig, (authorization, signature)),
            0,
            skipRevert
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

    function _morphoSupply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        uint256 slippageAmount,
        address onBehalf
    ) internal view returns (Call memory) {
        return _morphoSupply(marketParams, assets, shares, slippageAmount, onBehalf, abi.encode(callbackBundle));
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

    /* PARASWAP MODULE ACTIONS */

    function _paraswapSell(
        address _augustus,
        bytes memory callData,
        address srcToken,
        address destToken,
        bool sellEntireBalance,
        Offsets memory offsets,
        address receiver
    ) internal pure returns (bytes memory) {
        return abi.encodeCall(
            IParaswapModule.sell, (_augustus, callData, srcToken, destToken, sellEntireBalance, offsets, receiver)
        );
    }

    function _paraswapBuy(
        address _augustus,
        bytes memory callData,
        address srcToken,
        address destToken,
        uint256 newDestAmount,
        Offsets memory offsets,
        address receiver
    ) internal pure returns (bytes memory) {
        return abi.encodeCall(
            IParaswapModule.buy, (_augustus, callData, srcToken, destToken, newDestAmount, offsets, receiver)
        );
    }

    function _sell(
        address srcToken,
        address destToken,
        uint256 srcAmount,
        uint256 minDestAmount,
        bool sellEntireBalance,
        address receiver
    ) internal view returns (Call memory) {
        uint256 fromAmountOffset = 4 + 32 + 32;
        uint256 toAmountOffset = fromAmountOffset + 32;
        return _call(
            BaseModule(payable(address(paraswapModule))),
            _paraswapSell(
                address(augustus),
                abi.encodeCall(augustus.mockSell, (srcToken, destToken, srcAmount, minDestAmount)),
                srcToken,
                destToken,
                sellEntireBalance,
                Offsets({exactAmount: fromAmountOffset, limitAmount: toAmountOffset, quotedAmount: 0}),
                receiver
            )
        );
    }

    function _buy(
        address srcToken,
        address destToken,
        uint256 maxSrcAmount,
        uint256 destAmount,
        uint256 newDestAmount,
        address receiver
    ) internal view returns (Call memory) {
        uint256 fromAmountOffset = 4 + 32 + 32;
        uint256 toAmountOffset = fromAmountOffset + 32;
        return _call(
            BaseModule(payable(address(paraswapModule))),
            _paraswapBuy(
                address(augustus),
                abi.encodeCall(augustus.mockBuy, (srcToken, destToken, maxSrcAmount, destAmount)),
                srcToken,
                destToken,
                newDestAmount,
                Offsets({exactAmount: toAmountOffset, limitAmount: fromAmountOffset, quotedAmount: 0}),
                receiver
            )
        );
    }

    /* PERMIT ACTIONS */

    function _permit(
        IERC20Permit token,
        uint256 privateKey,
        address spender,
        uint256 amount,
        uint256 deadline,
        bool skipRevert
    ) internal view returns (Call memory) {
        address user = vm.addr(privateKey);

        Permit memory permit = Permit(user, spender, amount, token.nonces(user), deadline);

        bytes32 digest = SigUtils.toTypedDataHash(token.DOMAIN_SEPARATOR(), permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        bytes memory callData = abi.encodeCall(IERC20Permit.permit, (user, spender, amount, deadline, v, r, s));
        return _call(BaseModule(payable(address(token))), callData, 0, skipRevert);
    }
}
