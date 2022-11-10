ifdef file
  match = --match-contract $(file)
endif

t:
	forge test $(match) -vv --fork-url https://mainnet.infura.io/v3/786a7764b8234b06b4cd6764a1646a17
tt:
	forge test $(match) -vvv --fork-url https://mainnet.infura.io/v3/786a7764b8234b06b4cd6764a1646a17
ttt:
	forge test $(match) -vvvv --fork-url https://mainnet.infura.io/v3/786a7764b8234b06b4cd6764a1646a17
