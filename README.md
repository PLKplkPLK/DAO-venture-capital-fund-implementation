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
```

wsl and forge one-liner:
`wsl -e sh -lc "cd /mnt/d/Pobrane/DAO-venture-capital-fund-implementation/forge && /home/pelek/.foundry/bin/forge test"`

## Local ETH node - Foundry - Anvil

Use wsl on Windows.

`anvil`

# TODO

- broker
- real oracle
