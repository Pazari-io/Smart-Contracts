# Welcome to Pazari Contracts
This repository holds the current version of our smart contracts:
- Marketplace
- Payment Router
- Pazari Token
- Pazari Token Factory

## Purpose

Smart contracts on Avalanche written in Solidity.

### Marketplace

This contract handles creating, purchasing, and restocking of market items. It supports any ERC1155 tokens for market items and any ERC20 tokens for payment methods.

This contract talks directly to the payment router contract to handle the payment process. When a user purchases an item, it will pull the payment token and split them according to the commission rate. 

### Payment Router

This contract takes in ERC20 tokens, splits them, and routes them to their recipients. It extracts a "route tax" before routing payment to recipients, which is used to fund the platform.

This contract's design was inspired by OpenZeppelin's PaymentSplitter contract, but does not resemble that contract very much anymore. It has since been heavily modified for our purposes. Unlike the OpenZeppelin PaymentSplitter contract, the PaymentRouter contract only accepts ERC20 tokens, and is designed to track many different "routes" for many users.

Payment routes are token-agnostic, and will redirect any ERC20 token of any amount that is passed through them to the recipients specified according to their commission, which is transferred after the platform tax is transferred to the treasury.

### Pazari Token

This contract is a modification of the standard ERC1155 token contract for use on the Pazari digital marketplace. These are one-time-payment tokens, and are used for ownership verification after a file has been purchased.

Because these are ERC1155 tokens, creators can mint fungible and non-fungible tokens, depending upon the item they wish to sell. However, they are not transferrable to anyone who isn't an owner of the contract. These tokens are pseudo-NFTs.

### Pazari Token Factory

This contract factory produces the Pazari Token contract, which is the primary token contract for Pazari market items. 

## Version

  **1.0.0-alpha.1**

## Setting up local development 

### Pre-requisites

- [Node.js](https://nodejs.org/en/) version 14.0+ and [yarn](https://yarnpkg.com/) for Javascript environment.
- [dapp.tools](https://github.com/dapphub/dapptools#installation) with [Nix](https://nixos.org/download.html) for running dapp tests.  
  For Apple Silicon macs, we recommend to install Nix v2.3.16-x86_64 (see [this issue](https://github.com/dapphub/dapptools/issues/878)).
- [Moralis account](https://moralis.io/) for RPC connection.
 
1. Clone this repository
```bash
git clone https://github.com/Pazari-io/Smart-Contracts.git
``` 
2. Install dependencies (Hardhat and Truffle)
```bash
yarn
```
3. Set your environment variables on the .env file according to .env.example
```bash
cp .env.example .env
nano .env
```
4. Compile Solidity programs
```bash
yarn compile
```

### Development

- To run truffle tests
```bash
yarn test:truffle
```
- To run hardhat tests
```bash
yarn test:hh
```
- To run dapp tests
```bash
yarn test:dapp
```
- To start local blockchain
```bash
yarn localnode
```
- To run scripts on Fuji testnet
```bash
yarn script:fuji ./scripts/....
```
- To run deploy contracts on Fuji testnet
```bash
yarn script:fuji ./scripts/deploy.ts
```

... see more useful commands in package.json file

## Main Dependencies

Our contracts are developed using well-known open-source software for utility libraries and developement tools. You can read more about each of them.

[OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts)

[Truffle](https://github.com/trufflesuite/truffle)

[Hardhat](https://github.com/nomiclabs/hardhat)

[dapp.tools](https://github.com/dapphub/dapptools)

[ethers.js](https://github.com/ethers-io/ethers.js/)

[TypeChain](https://github.com/dethcrypto/TypeChain)

## Security

We handle security and security issues with great care. Please contract `security [at] pazari.io` as soon as you find a valid vulnerability. 

## Important

Currently alpha and under development.
