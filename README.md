# Morpho Bundler v3

The [`Bundler`](./src/Bundler.sol) allows EOAs to batch-execute a sequence of arbitrary calls atomically.
It carries specific features to be able to perform actions that require authorizations, and handle callbacks.

## Structure

### Bundler

<img width="586" alt="bundler structure" src="https://github.com/user-attachments/assets/983b7e48-ba0c-4fda-a31b-e7c9cc212da4">

The bundler's entrypoint is `multicall(Call[] calldata bundle)`.
A bundle is a sequence of calls where each call is specified by:

- `to`, an address to call;
- `data`, some calldata to pass to the call;
- `value`, an amount of native currency to send with the call;
- `skipRevert`, a boolean indicating whether the multicall should revert if the call failed.

The bundler also defines two features, their usage is described in the [Adapters subsection](#adapters):

- the initial caller is transiently stored as `initiator` during the multicall;
- the last non-returned called address can re-enter the bundler using `reenter(Call[] calldata bundle)`.

### Adapters

The bundler can call either directly protocols, or wrappers of protocols (called "adapters").
Wrappers can be useful to perform “atomic checks" (e.g. slippage checks), manage slippage (e.g. in migrations) or perform actions that require authorizations.

In order to be safely authorized by users, adapters can restrict some functions calls depending on the value of the bundle's initiator, stored in the bundler.
For instance, a adapter that needs to hold some token approvals should only allow to call `transferFrom` with `from` being the initiator.

Since these functions can typically move user funds, only the bundler should be allowed to call them.
If a adapter gets called back (e.g. during a flashloan) and needs to perform more actions, it can use other adapters by calling the bundler's `reenter(Call[] calldata bundle)` function.

## Adapters List

All adapters inherit from [`CoreAdapter`](./src/adapters/CoreAdapter.sol), which provides essential features such as accessing the current initiator address.

### [`GeneralAdapter1`](./src/adapters/GeneralAdapter1.sol)

Contains the following actions:

- ERC20 transfers, permit, wrap & unwrap.
- Native token (e.g. WETH) transfes, wrap & unwrap.
- ERC4626 mint, deposit, withdraw & redeem.
- Morpho interactions.
- Permit2 approvals.
- URD claim.

### [`EthereumGeneralAdapter1`](./src/adapters/EthereumGeneralAdapter1.sol)

Contains the following actions:

- Actions of `GeneralAdapter1`.
- Morpho token wrapper withdrawal.
- DAI permit.
- stETH staking.
- wstETH wrap & unwrap.

### [`ParaswapAdapter`](./src/adapters/ParaswapAdapter.sol)

Contains the following actions, all using the paraswap aggregator:

- Sell a given amount or the balance.
- Buy a given amount.
- Buy a what's needed to fully repay on a given Morpho Market.

### Migration adapters

For [Aave V2](./src/adapters/migration/AaveV2MigrationAdapter.sol), [Aave V3](./src/adapters/migration/AaveV3MigrationAdapter.sol), [Compound V2](./src/adapters/migration/CompoundV2MigrationAdapter.sol), [Compound V3](./src/adapters/migration/CompoundV3MigrationAdapter.sol), and [Morpho Aave V3 Optimizer](./src/adapters/migration/AaveV3OptimizerMigrationAdapter.sol).

## Differences with [Bundler v2](https://github.com/morpho-org/morpho-blue-bundlers)

- Make use of transient storage.
- Bundler is now a call dispatcher that does not require any approval.
  Because call-dispatch and approvals are now separated, it is possible to add adapters over time without additional risk to users of existing adapters.
- All generic features are now in `GeneralAdapter1`, instead of being in separate files that are then all inherited by a single contract.
- All Ethereum related features are in the `EthereumAdapter1` which inherits from `GeneralAdapter1`.
- The `1` after `Adapter` is not a version number: when new features are development we will deploy additional adapters, for instance `GeneralAdapter2`.
  Existing adapters will still be used.
- Many adjustments such as:
  - A value `amount` is only taken to be the current balance (when it makes sense) if equal to `uint.max`
  - Slippage checks are done with a price argument instead of a limit amount.
  - When `shares` represents a supply or borrow position, `shares == uint.max` sets `shares` to the position's total value.
  - There are receiver arguments in all functions that give tokens to the adapter so the adapter can pass along those tokens.

## Development

Run tests with `forge test --chain <chainid>` (chainid can be 1 or 8453, 1 by default).

## Audits

TBA.

## License

Source files are licensed under `GPL-2.0-or-later`, see [`LICENSE`](./LICENSE).

## Links

- Deployments: TBA.
- SDK: TBA.
