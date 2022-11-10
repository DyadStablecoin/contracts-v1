ifdef file
  matchFile = --match-contract $(file)
endif
ifdef func
  matchFunction = --match $(func)
endif

t:
	forge test $(matchFile) $(matchFunction) -vv --fork-url https://mainnet.infura.io/v3/786a7764b8234b06b4cd6764a1646a17
tt:
	forge test $(matchFile) $(matchFunction) -vvv --fork-url https://mainnet.infura.io/v3/786a7764b8234b06b4cd6764a1646a17
ttt:
	console.log(j)
	forge test $(matchFile) $(matchFunction) -vvvv --fork-url https://mainnet.infura.io/v3/786a7764b8234b06b4cd6764a1646a17
