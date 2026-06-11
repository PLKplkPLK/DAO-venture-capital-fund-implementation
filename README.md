## Frontend

React Next.js app - inside `frontend` directory.

`cd frontend && npm run dev`

Local UI routes (when the frontend dev server is running):

- **/** : main user view (home)
- **/broker** : broker dashboard (execute approved proposals)
- **/portfolio** : view DAO-held NFTs (transaction certificates)

Open the app at: http://localhost:3000

## Smart Contracts - Foundry - Forge

Use wsl on Windows. TDD will probably be the best - write tests first, then code.

`curl -L https://foundry.paradigm.xyz | bash`
`foundryup`

Inside `forge`:

```sh
forge build
forge test
forge create src/HFD.sol:HedgeFundDAO --rpc-url http://127.0.0.1:8545 --private-key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" --broadcast
forge create src/oracle.sol:MockPriceOracle --rpc-url http://127.0.0.1:8545 --private-key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" --broadcast
cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 "setPriceOracle(address)" 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 --rpc-url http://127.0.0.1:8545 --private-key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
forge create src/transactionNFT.sol:TransactionNFT --rpc-url http://127.0.0.1:8545 --private-key "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d" --broadcast
forge create src/broker.sol:InvestmentBroker --rpc-url http://127.0.0.1:8545 --private-key "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d" --broadcast --constructor-args 0x5FbDB2315678afecb367f032d93F642f64180aa3 0x8464135c8F25Da09e49BC8782676a84730C318bC 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 "setBroker(address)" 0x71C95911E9a5D330f4D621842EC243EE1343292e --rpc-url http://127.0.0.1:8545 --private-key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
cast send 0x8464135c8F25Da09e49BC8782676a84730C318bC "setBroker(address)" 0x71C95911E9a5D330f4D621842EC243EE1343292e --rpc-url http://127.0.0.1:8545 --private-key "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
cast send 0x8464135c8F25Da09e49BC8782676a84730C318bC "setDAO(address)" 0x5FbDB2315678afecb367f032d93F642f64180aa3 --rpc-url http://127.0.0.1:8545 --private-key "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 "setNFTContract(address)" 0x8464135c8F25Da09e49BC8782676a84730C318bC --rpc-url http://127.0.0.1:8545 --private-key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
```

wsl and forge one-liner:
`wsl -e sh -lc "cd /mnt/d/Pobrane/DAO-venture-capital-fund-implementation/forge && /home/pelek/.foundry/bin/forge test"`

## Local ETH node - Foundry - Anvil

Use wsl on Windows.

`anvil`

# Deployed to Sepolia

Before running

```sh
forge script script/Deploy.s.sol:DeployScript --rpc-url "https://eth-sepolia.g.alchemy.com/v2/..." --broadcast --verify -vvvv
```

Make sure you have below env variables set `$env:RPC_URL="..."` for frontend app.

```
RPC_URL = "https://eth-sepolia.g.alchemy.com/v2/..."
NEXT_PUBLIC_CHAIN_ID = "11155111"  # sepolia ID

NEXT_PUBLIC_DAO_CONTRACT_ADDRESS="0xbBB566007Bc1Ec63d9518805A0EEb8d27Dc0A2D3"
NEXT_PUBLIC_BROKER_CONTRACT_ADDRESS="0x098540e5e8Bc875a413887bF4a16752c5c06b81f"
NEXT_PUBLIC_NFT_CONTRACT_ADDRESS="0x88D4bad5415124B0621cD8E80aE1a47d9D046f2C"
ORACLE_CONTRACT_ADDRESS="0xCf414260E7265c2EDF902D627DAa7bC473d7D01E"
```
