# Morpho Blue Bundler v3

[Morpho Blue](https://github.com/morpho-org/morpho-blue) is a new lending primitive that offers better rates, high capital efficiency and extended flexibility to lenders & borrowers. `bundlers` hosts the logic that builds alongside the core protocol like MetaMorpho and bundlers.


The Bundler executes a sequence of calls atomically. EOAs should use the Bundler to execute multiple actions in a single transaction.


## Structure

The Bundler's entrypoint is `multicall(Call[] calldata bundle)`. A bundle is a sequence of calls, and each call specifies an arbitrary address and arbitrary calldata.

Before calling a contract, the `Bundler` stores its caller as the `initiator`. Called contracts can access the initiator's address during bundle execution. The Bundler can be called back by its most-recently-called contract using `multicallFromModule(Call[] calldata bundle)`. This is useful for callback-based flows such as flashloans.

Each call should be to a module such as [`GenericModule1`](./src/GenericModule1.sol). These modules contain domain-specific actions and may need to be approved by the initiator to e.g. transfer the initiator's assets. To minimize the number of transactions and signatures, it is preferable to use Permit2's [batch permitting](https://github.com/Uniswap/permit2/blob/main/src/AllowanceTransfer.sol#L43-L56) through `GenericModule1`'s `approve2Batch` action.

All modules inherit from [`BaseModule`](./src/BaseModule.sol), which provides essential features such as reading the current initiator address.

## Development

Install dependencies with `yarn`.

Run tests with `yarn test --chain <chainid>` (chainid can be 1 or 8453).

## Audits

TBA.

## License

Bundlers are licensed under `GPL-2.0-or-later`, see [`LICENSE`](./LICENSE).

## Links

- Deployments: TBA.
- SDK: TBA.
