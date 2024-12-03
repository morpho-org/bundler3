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

For instance, [`EthereumGeneralModule1`](./src/modules/EthereumModule1.sol) contains generic as well as ethereum-specific actions.
It must be approved by the user to e.g. transfer their assets.

Users should not approve untrusted modules, just like they should not approve untrusted contracts in general.

Before calling a contract, the Bundler stores its own caller address as the bundle's `initiator`.
Modules can read the current initiator during bundle execution.
This is useful to secure a module that holds approvals or authorizations, by restricting function calls depending on the value of the current initiator.
For instance, such a module should only allow to move funds owned by the current initiator.

When the Bundler calls a module, the module can call it back using `multicallFromModule(Call[] calldata bundle)`.
This is useful for callback-based flows such as flashloans.

To minimize the number of transactions and signatures, it is preferable to use Permit2's [batch permitting](https://github.com/Uniswap/permit2/blob/main/src/AllowanceTransfer.sol#L43-L56) thanks to [`GeneralModule1.approve2Batch`](./src/modules/GeneralModule1.sol).

All modules inherit from [`CoreModule`](./src/modules/CoreModule.sol), which provides essential features such as reading the current initiator address.

## Modules

### [`GeneralModule1`](./src/modules/GeneralModule1.sol)

Contains the following actions:
- ERC20 transfers, permit, wrap & unwrap.
- Native token (e.g. WETH) wrap & unwrap.
- ERC4626 mint,deposit, withdraw & redeem.
- Morpho interactions.
- Permit2 approvals.
- URD claim.

### [`EthereumGeneralModule1`](./src/modules/EthereumModule1.sol)

Contains the following actions:

- Actions of `GeneralModule1`.
- Morpho token wrapper withdrawal.
- Dai permit.
- StEth staking.
- WStEth wrap & unwrap.

### Migration modules

For [Aave V2](./src/modules/migration/AaveV2MigrationModule.sol), [Aave V3](./src/modules/migration/AaveV3MigrationModule.sol), [Compound V2](./src/modules/migration/CompoundV2MigrationModule.sol), [Compound V3](./src/modules/migration/CompoundV3MigrationModule.sol), and [Morpho Aave V3 Optimizer](./src/modules/migration/AaveV3OptimizerMigrationModule.sol).

## Differences with [Bundler v2](https://github.com/morpho-org/morpho-blue-bundlers)

- Make use of transient storage.
- Bundler is now a call dispatcher that does not require any approval.
  Because call-dispatch and approvals are now separated, it is possible to add modules over time without additional risk to users of existing modules.
- All generic features are now in `GeneralModule1`, instead of being in separate files that are then all inherited by a single contract.
- All Ethereum related features are in the `EthereumModule1` which inherits from `GeneralModule1`.
- The `1` after `Module` is not a version number: when new features are development we will deploy additional modules, for instance `GeneralModule2`.
  Existing modules will still be used.
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
