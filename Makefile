ifdef FILE
  matchFile = --match-contract $(FILE)
endif
ifdef FUNC
  matchFunction = --match $(FUNC)
endif

t:
	forge test $(matchFile) $(matchFunction) -vv --fork-url https://mainnet.infura.io/v3/786a7764b8234b06b4cd6764a1646a17
tt:
	forge test $(matchFile) $(matchFunction) -vvv --fork-url https://mainnet.infura.io/v3/786a7764b8234b06b4cd6764a1646a17
ttt:
	forge test $(matchFile) $(matchFunction) -vvvv --fork-url https://mainnet.infura.io/v3/786a7764b8234b06b4cd6764a1646a17

lt:
	forge test $(matchFile) $(matchFunction) -vv 
ltt:
	forge test $(matchFile) $(matchFunction) -vvv 
lttt:
	forge test $(matchFile) $(matchFunction) -vvvv 

# --gas-report
anvil:
	anvil --fork-url https://mainnet.infura.io/v3/786a7764b8234b06b4cd6764a1646a17 --chain-id 1337 --block-time 5

ldeploy:
	forge script script/DeployLocally.s.sol --rpc-url http://localhost:8545 --chain-id 1337 --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --broadcast -i 1
