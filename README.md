# Morpho Blue Bundler v3

The [`Bundler`](./src/Bundler.sol) allows EOAs to batch-execute a sequence of arbitrary calls atomically.
It carries specific features to be able to perform actions that require authorizations, and handle callbacks.

## Structure

### Bundler

<img width="586" alt="bundler structure" src="https://github.com/user-attachments/assets/983b7e48-ba0c-4fda-a31b-e7c9cc212da4">

The Bundler's entrypoint is `multicall(Call[] calldata bundle)`.
A bundle is a sequence of calls where each call is specified by:
- `to`, an address to call;
- `data`, some calldata to pass to the call;
- `value`, an amount of native currency to send with the call;
- `skipRevert`, a boolean indicating whether the multicall should revert if the call failed.

A contract called by the Bundler is called a target.

The bundler transiently stores the initial caller (`initiator`) during the multicall (see in the Modules subsection for the use).

The last target can re-enter the bundler using `multicallFromTarget(Call[] calldata bundle)` (same).

### Modules

Targets can be either protocols, or wrappers of protocols (called "modules").
Wrappers can be useful to perform “atomic checks" (e.g. slippage checks), manage slippage (e.g. in migrations) or perform actions that require authorizations.

In order to be safely authorized by users, modules can restrict some functions calls depending on the value of the bundle's initiator, stored in the Bundler.
For instance, a module that needs to hold some token approvals should only allow to call `transferFrom` with from=initiator.

Since these functions can typically move user funds, only the bundler should be allowed to call them.
If a module gets called back (e.g. during a flashloan) and needs to perform more actions, it can use other modules by calling the bundler's ``multicallFromTarget(Call[] calldata bundle)` function.

## Modules

All modules inherit from [`BaseModule`](./src/BaseModule.sol), which provides essential features such as accessing the current initiator address.

### [`GenericModule1`](./src/GenericModule1.sol)

Contains the following actions:
- ERC20 transfers, permit, wrap & unwrap.
- Native token (e.g. WETH) wrap & unwrap.
- ERC4626 mint,deposit, withdraw & redeem.
- Morpho interactions.
- Permit2 approvals.
- URD claim.

### [`EthereumModule1`](./src/ethereum/EthereumModule1.sol)

Contains the following actions:
- Actions of `GenericModule1`.
- Morpho token wrapper withdrawal.
- Dai permit.
- StEth staking.
- WStEth wrap & unwrap.

### [`ParaswapModule`](./src/ParaswapModule.sol)

TBA.

### Migration modules

For [Aave V2](./src/migration/AaveV2MigrationModule.sol), [Aave V3](./src/migration/AaveV3MigrationModule.sol), [Compound V2](./src/migration/CompoundV2MigrationModule.sol), [Compound V3](./src/migration/CompoundV3MigrationModule.sol), and [Morpho Aave V3 Optimizer](./src/migration/AaveV3OptimizerMigrationModule.sol).

Contain the actions to repay current debt and withdraw supply/collateral on these protocols.

## Differences with [Bundler v2](https://github.com/morpho-org/morpho-blue-bundlers)

- Make use of transient storage.
- Bundler is now a call dispatcher that does not require any approval.
  Because call-dispatch and approvals are now separated, it is possible to add bundlers over time without additional risk to users of existing bundlers.
- All generic features are now in `GenericModule1`, instead of being in separate files that are then all inherited by a single contract.
- All Ethereum related features are in the `EthereumModule1` which inherits from `GenericModule1`.
- The `1` after `Module` is not a version number: when new features are development we will deploy additional modules, for instance `GenericModule2`.
  Existing modules will still be used.
- There is a new action `permit2Batch` to allow multiple contracts to move multiple tokens using a single signature.
- Many adjustments such as:
  - A value `amount` is only taken to be the current balance (when it makes sense) if equal to `uint.max`
  - Slippage checks are done with a price argument instead of a limit amount.
  - When `shares` represents a supply or borrow position, `shares == uint.max` sets `shares` to the position's total value.
  - There are receiver arguments in all functions that give tokens to the module so the module can pass along those tokens.

## Development

Run tests with `forge test --chain <chainid>` (chainid can be 1 or 8453, 1 by default).

## Audits

TBA.

## License

Bundlers are licensed under `GPL-2.0-or-later`, see [`LICENSE`](./LICENSE).

## Links

- Deployments: TBA.
- SDK: TBA.
