### DoubleLiquid smart contract, intergration tests and simulation



#### run integration tests

Sets up local node, deploy contract to it and run user behaviour with different strategies for few epochs to be sure everything work as expected

```bash
node test.js
```

#### run simulation

Check our run_simulation.js code to adjust parameters. Results will be stored in ./simulations folder, so it should be writable

```bash
node run_simulation.js
```

#### deploy smart contract

edit config.json with needed settings

```bash
node deploy_contract.js --chain=testnet --phrase="your wallet seed phrase"

```

seed phrase may be ommited for local chain

#### upgrade smart contract

edit config.json with needed settings, admincap for doubleliquid contract should be there

```bash
node upgrade_contract.js --chain=testnet --phrase="your wallet seed phrase"

```

seed phrase may be ommited for local chain