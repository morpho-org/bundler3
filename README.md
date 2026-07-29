# Bundler3

[`Bundler3`](./src/Bundler3.sol) allows accounts to batch-execute a sequence of arbitrary calls atomically.
It carries specific features to be able to perform actions that require authorizations, and handle callbacks.

## Structure

### Bundler3

<img width="724" alt="image" src="https://github.com/user-attachments/assets/cc7c304a-9778-441d-b863-c158e5de21ee" />

Bundler3's entrypoint is `multicall(Call[] calldata bundle)`.
A bundle is a sequence of calls where each call is specified by:
<a name="bundle-call-fields"></a>

- `to`, an address to call;
- `data`, some calldata to pass to the call;
- `value`, an amount of native currency to send with the call;
- `skipRevert`, a boolean indicating whether the multicall should revert if the call failed.
- `callbackHash`, hash of the argument to the expected `reenter` (0 if no reentrance).


Bundler3 also implements two specific features, their usage is described in the [Adapters subsection](#adapters):

- the initial caller is transiently stored as `initiator` during the multicall;
- the last non-returned called address can re-enter Bundler3 using `reenter(Call[] calldata bundle)`, but the argument to the `reenter` call is specified in the bundle.

### Adapters

Bundler3 can call either directly protocols, or wrappers of protocols (called "adapters").
Wrappers can be useful to perform “atomic checks" (e.g. slippage checks), manage slippage (e.g. in migrations) or perform actions that require authorizations.

In order to be safely authorized by users, adapters can restrict some functions calls depending on the value of the bundle's initiator, stored in Bundler3.
For instance, an adapter that needs to hold some token approvals should call `token.transferFrom` only with `from` being the initiator.

Since these functions can typically move user funds, only Bundler3 should be allowed to call them.
If an adapter gets called back (e.g. during a flashloan) and needs to perform more actions, it can use other adapters by calling Bundler3's `reenter(Call[] calldata bundle)` function.

## Adapters List

All adapters inherit from [`CoreAdapter`](./src/adapters/CoreAdapter.sol), which provides essential features such as accessing the current initiator address.

### [`GeneralAdapter1`](./src/adapters/GeneralAdapter1.sol)

Contains the following actions:

- ERC20 transfers.
- Native token (e.g. WETH) transfers, wrap & unwrap.
- ERC4626 mint, deposit, withdraw & redeem.
- Morpho interactions.
- TransferFrom using Permit2.

### [`ERC20WrapperAdapter`](./src/adapters/ERC20WrapperAdapter.sol)

Contains the following actions:

- ERC20 wrap & unwrap.

### [`EthereumGeneralAdapter1`](./src/adapters/EthereumGeneralAdapter1.sol)

Contains the following actions:

- Actions of `GeneralAdapter1`.
- Morpho token wrapper deposit and withdrawal.
- stETH staking.
- wstETH wrap & unwrap.

### [`ParaswapAdapter`](./src/adapters/ParaswapAdapter.sol)

Contains the following actions, all using the paraswap aggregator:

- Sell a given amount or the balance.
- Buy a given amount.
- Buy a what's needed to fully repay on a given Morpho Market.

### [`PublicAllocatorAdapter`](./src/adapters/PublicAllocatorAdapter.sol)

Contains the following actions, all using the vault-v2 Blue public allocator:

- Allocate a vault's idle liquidity to a Morpho market, then reallocate liquidity across markets in a single call.

### Migration adapters

For [Aave V2](./src/adapters/migration/AaveV2MigrationAdapter.sol), [Aave V3](./src/adapters/migration/AaveV3MigrationAdapter.sol), [Compound V2](./src/adapters/migration/CompoundV2MigrationAdapter.sol), [Compound V3](./src/adapters/migration/CompoundV3MigrationAdapter.sol), and [Morpho Aave V3 Optimizer](./src/adapters/migration/AaveV3OptimizerMigrationAdapter.sol).

## Security notice on approvals to Bundler3

Bundler3 is a call dispatcher and can make arbitrary calls.
The Bundler3 contract must not receive any approvals, or funds risk being stolen.

Individual adapters such as `GenericAdapter1` are safe to approve.

## Development

Run tests with `forge test --chain <chainid>` (chainid can be 1 or 8453, 1 by default).

## Audits

All audits are stored in the [audits](./audits/) folder.

## License

Source files are licensed under `GPL-2.0-or-later`, see [`LICENSE`](./LICENSE).

## Links

- [Deployments](https://docs.morpho.org/addresses/#bundlers)
- SDK: TBA.
