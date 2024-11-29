# Morpho Blue Bundler v3

The [`Bundler`](./src/Bundler.sol) executes a sequence of calls atomically.
EOAs should use the Bundler to execute multiple actions in a single transaction.

## Structure

<img width="586" alt="bundler structure" src="https://github.com/user-attachments/assets/983b7e48-ba0c-4fda-a31b-e7c9cc212da4">

The Bundler's entrypoint is `multicall(Call[] calldata bundle)`.
A bundle is a sequence of calls, and each call specifies:
- an address to call;
- some calldata to pass to the call;
- an amount of native currency to send along the call;
- a boolean indicating whether the multicall should revert if the call failed.

A contract called by the Bundler is called a module.

For instance, [`EthereumModule1`](./src/ethereum/EthereumModule1.sol) contains generic as well as ethereum-specific actions.
It must be approved by the user to e.g. transfer the initiator's assets.

Users should not approve untrusted modules, just like they should not approve untrusted contracts in general.

Before calling a contract, the Bundler stores its own caller as the bundle's `initiator`.
Modules can read the current initiator during bundle execution.
This is useful to make a secure module: for instance, a module should only move funds owned by the current initiator.

When the Bundler calls a module, the module can call it back using `multicallFromModule(Call[] calldata bundle)`.
This is useful for callback-based flows such as flashloans.

To minimize the number of transactions and signatures, it is preferable to use Permit2's [batch permitting](https://github.com/Uniswap/permit2/blob/main/src/AllowanceTransfer.sol#L43-L56) thanks to [`GenericModule1.approve2Batch`](./src/GenericModule1.sol).

All modules inherit from [`BaseModule`](./src/BaseModule.sol), which provides essential features such as reading the current initiator address.

## Modules

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

### Migration modules

For [Aave V2](./src/migration/AaveV2MigrationModule.sol), [Aave V3](./src/migration/AaveV3MigrationModule.sol), [Compound V2](./src/migration/CompoundV2MigrationModule.sol), [Compound V3](./src/migration/CompoundV3MigrationModule.sol), and [Morpho Aave V3 Optimizer](./src/migration/AaveV3OptimizerMigrationModule.sol).

Contain the actions to repay current debt and withdraw supply/collateral on these protocols.

## Differences with [Bundler v2](https://github.com/morpho-org/morpho-blue-bundlers)

- Use transient storage where it makes sense.
- Bundler is now a call dispatcher that holds no approvals.
  This is useful to freely add bundlers over time without additional risk to users of existing bundlers.
- All generic features are in `GenericModule1`, instead of being in separate files that are then all inherited by a single contract.
- All ethereum features are in `EthereumModule1` which inherits `GenericModule1`.
- The `1` after `Module` is not a version number: when new features are development we will deploy additional modules, for instance `GenericModule2`. Existing modules will still be used.
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
