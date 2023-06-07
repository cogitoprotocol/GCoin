# GCoin

This repository contains all the contracts for GCoin

with a few functions available:

1. GCoin minting
2. Treasury management
3. GCoin staking
4. CGV coin staking

## Unit Testing

All unit testing is in test folder

1. GCoin minting.
2. GCoin staking

## Development

First, [install Foundry](https://book.getfoundry.sh/getting-started/installation).

To build and test:

```sh
forge build
forge test -vv
```

## Deploying to localhost

Add the following to `.env`:

```sh
# Alchemy, Infura, etc
MAINNET_RPC_URL=...
SEPOLIA_RPC_URL=...

# anvil default account
DEPLOYER_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
DEPLOYER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

# your browser wallet, for frontend testing
TEST_WALLET=...
```

Then start anvil:

```sh
source .env
anvil --chain-id 1337 -b 10

# optionally, you can fork mainnet to test with live contracts
anvil --chain-id 1337 -b 10 -f $MAINNET_RPC_URL
```

In a new terminal, run the deploy script:

```sh
forge script script/DeployTestnet.s.sol -f http://localhost:8545 --broadcast
```

Contract addresses will be saved to `deploy/localhost.json`:

```sh
cat deploy/localhost.json
```

This can now be used in the frontend. You may need to send yourself some eth:

```sh
cast send --unlocked -f $DEPLOYER $TEST_WALLET --value 10ether
```
