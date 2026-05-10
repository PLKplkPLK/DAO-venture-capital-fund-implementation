import { ethers } from "ethers";

// const API_KEY = ""

function getProvider() {
  const provider = new ethers.JsonRpcProvider("http://127.0.0.1:8545");
  return provider;
}

function getBrowserProvider() {
  return new ethers.BrowserProvider(window.ethereum);
}

function getContractABI() {
  return [];
}

function getContractAddress() {
  return "";
}

export { getProvider, getBrowserProvider, getContractABI, getContractAddress };
