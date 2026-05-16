import { ethers } from "ethers";

export { getProvider, getBrowserProvider, getContractABI, getContractAddress };

const DAO_CONTRACT_ADDRESS =
  process.env.NEXT_PUBLIC_DAO_CONTRACT_ADDRESS ??
  "0x5FbDB2315678afecb367f032d93F642f64180aa3";
const DAO_CONTRACT_ABI = [
  "function buyShares() payable",
  "function retrieveShares(uint256 amount)",
  "function balanceOf(address account) view returns (uint256)",
  "event Transfer(address indexed from, address indexed to, uint256 value)",
];

function getProvider() {
  return new ethers.JsonRpcProvider("http://127.0.0.1:8545");
}

async function getBrowserProvider() {
  if (typeof window === "undefined") {
    throw new Error("Browser only");
  }
  const ethereum = (window as any).ethereum;
  if (!ethereum) {
    throw new Error("Browser wallet not found. Install wallet (eg. MetaMask)");
  }

  const provider = new ethers.BrowserProvider(ethereum);

  const network = await provider.getNetwork();
  if (network.chainId !== BigInt(31337)) {
    console.log("Connected network:", network);
    throw new Error(`Wrong network. Connected to chain ${network.chainId}`);
  }

  return provider;
}

function getContractABI() {
  return DAO_CONTRACT_ABI;
}

function getContractAddress() {
  return DAO_CONTRACT_ADDRESS;
}
