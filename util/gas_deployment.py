import json

P = "./broadcast/Deploy.Mainnet.s.sol/1337/run-latest.json"

f = open(P)
d = json.load(f)

gas = 0
for k in d["transactions"]:
    gas += int(k["transaction"]["gas"], 16)

print(gas)
