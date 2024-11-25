# Morpho Blue Bundler v3

The [`Bundler`](./src/Bundler.sol) executes a sequence of calls atomically. EOAs should use the Bundler to execute multiple actions in a single transaction.

## Structure

<img width="586" alt="bundler structure" src="https://github.com/user-attachments/assets/983b7e48-ba0c-4fda-a31b-e7c9cc212da4">

The Bundler's entrypoint is `multicall(Call[] calldata bundle)`. A bundle is a sequence of calls, and each call specifies an arbitrary address and arbitrary calldata.

A contract called by the Bundler is called a Module.

Before calling a contract, the `Bundler` stores its own caller as the `initiator`. Modules can access the initiator's address during bundle execution. The Bundler can be called back by its most-recently-called module using `multicallFromModule(Call[] calldata bundle)`. This is useful for callback-based flows such as flashloans.

Users should not call untrusted modules, just like they should not sign transactions to untrusted contracts.

Modules such as [`EthereumModule1`](./src/ethereum/EthereumModule1.sol) contain domain-specific actions and may need to be approved by the initiator to e.g. transfer the initiator's assets.

To minimize the number of transactions and signatures, it is preferable to use Permit2's [batch permitting](https://github.com/Uniswap/permit2/blob/main/src/AllowanceTransfer.sol#L43-L56) through `GenericModule1`'s `approve2Batch` action.

All modules inherit from [`BaseModule`](./src/BaseModule.sol), which provides essential features such as reading the current initiator address.

## Development

Run tests with `yarn test --chain <chainid>` (chainid can be 1 or 8453).

## Audits

TBA.

## License

Bundlers are licensed under `GPL-2.0-or-later`, see [`LICENSE`](./LICENSE).

## Links

- Deployments: TBA.
- SDK: TBA.
