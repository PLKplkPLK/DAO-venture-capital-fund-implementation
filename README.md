## Frontend

React Next.js app - inside `frontend` directory.

`cd frontend && npm run dev`

Local UI routes (when the frontend dev server is running):

- **/** : main user view (home)
- **/broker** : broker dashboard (execute approved proposals)
- **/portfolio** : view DAO-held NFTs (transaction certificates)

Open the app at: http://localhost:3000

## Smart Contracts - Foundry - Forge

Inside `forge`:

```sh
forge build
forge test
forge script script/Deploy.s.sol:DeployScript --rpc-url "https://127.0.0.1:8545" --broadcast --verify
```

## Local ETH node - Foundry - Anvil

Use wsl on Windows.

`anvil`

# Deployed to Sepolia

```sh
forge script script/Deploy.s.sol:DeployScript --rpc-url "https://eth-sepolia.g.alchemy.com/v2/..."
forge script script/Deploy.s.sol:DeployScript --rpc-url "https://eth-sepolia.g.alchemy.com/v2/..." --broadcast --verify
```

Make sure you have below env variables set for frontend app.

```
RPC_URL = "https://eth-sepolia.g.alchemy.com/v2/..."
NEXT_PUBLIC_CHAIN_ID = "11155111"  # sepolia ID

NEXT_PUBLIC_DAO_CONTRACT_ADDRESS="0xADAa2dA6a1D4ccb9b27150858d75bD79f5dcDa13"
NEXT_PUBLIC_BROKER_CONTRACT_ADDRESS="0xe75ab9C2F68DD999042B838F9a4eA4cA26Bd0196"
NEXT_PUBLIC_NFT_CONTRACT_ADDRESS="0x2c7f628848B9BD48c1de08A407DCe91A7aAcd707"
ORACLE_CONTRACT_ADDRESS="0x3DBfFB871c76C204710D55bEDab4be05BEd41E53"
```
