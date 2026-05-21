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
```

#### Local ETH node - Foundry - Anvil

Use wsl on Windows.

`anvil`
