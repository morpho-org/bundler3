# Bundler3 formal verification

This folder contains the [CVL](https://docs.certora.com/en/latest/docs/cvl/index.html) specification and verification setup for [Bundler3](../src/Bundler3.sol).

## Getting started

This project depends on several [Solidity](https://soliditylang.org/) versions which are required for running the verification.
The compiler binaries should be available at the paths:

- `solc-0.4.19` for the solidity compiler version `0.4.19`;
- `solc-0.8.19` for the solidity compiler version `0.8.19`;
- `solc-0.8.17` for the solidity compiler version `0.8.17`;
- `solc-0.8.28` for the solidity compiler version `0.8.28`.

To verify a specification, run the command `certoraRun Spec.conf` where `Spec.conf` is the configuration file of the matching CVL specification.
Configuration files are available in [`certora/confs`](confs).
Please ensure that `CERTORAKEY` is set up in your environment.

## Overview

The Bundler3 contract enables an EOA to call different endpoint contracts onchain as well as grouping several calls in a single bundle.
These calls may themselves reenter the Bundler3 contract.

## Bundler3 safety restrictions

A key feature of the bundler is to restrict reentering in adapter calls.
That is we check that reentering an adapter is only possible during a multicall execution.
We also check that adapters' methods used during a bundle execution may only be called by the Bundler3 contract.
We check that it's only possible to reenter the adapter using a dedicated Bunlder3 function.
Bundler3 uses transient storage, it's checked that it's nullified on each entry-point call.
This is checked with a separate configuration as it requires to disable sanity-checks (because `reenter` cannot be an entry-point _per se_).

## Morpho Zero Conditions

Some adapters may call Morpho entry-points, we check that zero inputs that should revert on Morpho revert directly at the adapter level.

## Allowance isolation

Throughout the adapters, ERC20 allowances to the adapter may be increased.
We check that such allowances are safe in-between adapters entry-points by resetting them to zero after transactions are performed.
Note that this not verified for the Paraswap adapter.

## General adapter reverts

In this adapter, we ensure that the state changes when adapter functions are called, or the execution reverts.
In some cases this property doesn't hold, in those cases a dedicated rule justify this is included.
