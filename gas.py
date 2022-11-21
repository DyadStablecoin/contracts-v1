import click

eth_price = 1129
gas_price = 13.7
gas = 853482

@click.command()
@click.option('--gas', default=gas, help='Gas used')
@click.option('--gas_price', default=gas_price, help='Gas price per gwei')
@click.option('--eth_price', default=eth_price, help='ETH price')
def calc(gas, gas_price, eth_price):
    print(f"${gas_price*gas/1000000000*eth_price:.2f}")

if __name__ == '__main__':
    calc()
