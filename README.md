# DYAD

![dyad](https://pbs.twimg.com/profile_images/1580864472079532032/uCLwW3nb_200x200.jpg)

This repo contains the smart contracts for the dyad protocol.

## Run

1) Install [foundry](https://book.getfoundry.sh/getting-started/installation)
2) Run `forge build`

## Test

```
forge test --fork-url {FORK_URL}
```

## Deploy

```
forge script script/Deploy.Mainnet.s.sol --rpc-url ${RPC} --chain-id 1 --sender ${SENDER} --broadcast -i 1
```
