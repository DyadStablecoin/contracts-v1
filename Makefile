include .env

ifdef FILE
  matchFile = --match-contract $(FILE)
endif
ifdef FUNC
  matchFunction = --match $(FUNC)
endif


t:
	forge test $(matchFile) $(matchFunction) -vv --fork-url $(RPC)
tt:
	forge test $(matchFile) $(matchFunction) -vvv --fork-url $(RPC)
ttt:
	forge test $(matchFile) $(matchFunction) -vvvv --fork-url $(RPC)

lt:
	forge test $(matchFile) $(matchFunction) -vv 
ltt:
	forge test $(matchFile) $(matchFunction) -vvv 
lttt:
	forge test $(matchFile) $(matchFunction) -vvvv 

anvil:
	anvil --fork-url $(RPC) --chain-id 1337 --block-time 5

# deploy on Locally forked mainnet 
ldeploy:
	forge script script/Deploy.Mainnet.s.sol --rpc-url http://localhost:8545 --chain-id 1337 --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --broadcast -i 1

# deploy on goerli
gdeploy:
	forge script script/Deploy.Goerli.s.sol --rpc-url $(GOERLI_RPC) --chain-id 5 --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --broadcast -i 1

# deploy on forked mainnet 
deploy:
	forge script script/Deploy.Mainnet.s.sol --rpc-url $(RPC) --chain-id 1 --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --broadcast -i 1
