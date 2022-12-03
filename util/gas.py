import click

eth_price = 1270
gas_price = 13.7
gas = 853482
calls_per_hour = 6

@click.command()
@click.option('--gas', default=gas, help='Gas used')
@click.option('--gas_price', default=gas_price, help='Gas price per gwei')
@click.option('--eth_price', default=eth_price, help='ETH price')
@click.option('--calls_per_hour', default=calls_per_hour, help='Calls per hour')
def calc(gas, gas_price, eth_price, calls_per_hour):
    print(f"ETH price           ${eth_price}")
    print(f"Gas price (in gwei) {gas_price}")
    print(f"Gas used            {gas}")
    print(f"Calls per Hour      {calls_per_hour}")
    print()
    print(f"Call Costs            ${gas_price*gas/1000000000*eth_price:.2f}")
    print(f"Call Costs (per hour) ${calls_per_hour*gas_price*gas/1000000000*eth_price:.2f}")
    print(f"Call Costs (per day)  ${calls_per_hour*24*gas_price*gas/1000000000*eth_price:.2f}")

if __name__ == '__main__':
    calc()
