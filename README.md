## Frontend

React Next.js app - inside `frontend` directory.

`cd frontend && npm run dev`

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
cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 "setPriceOracle(address)" 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

wsl and forge one-liner:
`wsl -e sh -lc "cd /mnt/d/Pobrane/DAO-venture-capital-fund-implementation/forge && /home/pelek/.foundry/bin/forge test"`

## Local ETH node - Foundry - Anvil

Use wsl on Windows.

`anvil`

# TODO

- broker
- real oracle
