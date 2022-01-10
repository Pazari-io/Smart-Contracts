# Welcome to Pazari Contracts
This repository holds the current version of our smart contracts:
- Marketplace
- Payment Router
- Pazari Token
- Pazari Token Factory

## Version

  **1.0.0-alpha.1**

## Setting up local development 

### Pre-requisites

- [Node.js](https://nodejs.org/en/) version 14.0+ and [yarn](https://yarnpkg.com/) for Javascript environment.
- [dapp.tools](https://github.com/dapphub/dapptools#installation) with [NixOS](https://nixos.org/download.html) for running dapp tests. 
- [Moralis account](https://moralis.io/) for RPC connection.
 
1. Clone this repository
```bash
git clone https://github.com/Pazari-io/Smart-Contracts.git
``` 
2. Install dependencies (Hardhat and Truffle)
```
yarn
```
3. Set your environment variables on the .env file according to .env.example
```
cp .env.example .env
nano .env
```
4. Compile Solidity programs
```
yarn compile
```

### Development

- To run truffle tests
```
yarn test:truffle
```
- To run hardhat tests
```
yarn test:hh
```
- To run dapp tests
```
yarn test:dapp
```
- To start local blockchain
```
yarn node
```

## Security

We handle security and security issues with great care. Please contract `security [at] pazari.io` as soon as you find a valid vulnerability. 

## Important

Currently alpha and under development .
