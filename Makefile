install:
	@forge test --chain 1 --fork-url "https://eth-mainnet.g.alchemy.com/v2/$(ALCHEMY_KEY)"
