import { ethers } from "ethers";
import {
  getBrowserProvider,
  getContractABI,
  getContractAddress,
} from "./utils";

function getErrorMessage(error: unknown) {
  if (error instanceof Error) {
    return error.message;
  }
  return String(error);
}

async function getSigner() {
  if (typeof window === "undefined") {
    throw new Error("Wallet operations can only run in the browser.");
  }

  const ethereum = (window as any).ethereum;
  if (!ethereum) {
    throw new Error(
      "No browser wallet found. Install MetaMask or another Ethereum wallet.",
    );
  }

  await ethereum.request({ method: "eth_requestAccounts" });
  const provider = await getBrowserProvider();
  return await provider.getSigner();
}

export async function getUserAddress(): Promise<string> {
  const signer = await getSigner();
  return await signer.getAddress();
}

async function getDaoContract(signer: ethers.Signer) {
  const address = getContractAddress();
  if (!address) {
    throw new Error(
      "DAO contract address is not configured. Set NEXT_PUBLIC_DAO_CONTRACT_ADDRESS.",
    );
  }

  return new ethers.Contract(address, getContractABI(), signer);
}

export async function getFundTotalBalance(): Promise<string> {
  const browserProvider = await getBrowserProvider();
  const fundBalance = await browserProvider.getBalance(getContractAddress());
  return ethers.formatEther(fundBalance); // Format Wei to ETH
}

export async function getUserDaoBalance(userAddress: string): Promise<string> {
  // Use the BrowserProvider (MetaMask)
  const browserProvider = await getBrowserProvider();
  const contract = new ethers.Contract(
    getContractAddress(),
    getContractABI(),
    browserProvider,
  );

  const balanceWei = await contract.balanceOf(userAddress);
  return ethers.formatEther(balanceWei); // Format Wei to ETH
}

export async function depositToDao(amountEth: string) {
  if (!amountEth || Number(amountEth) <= 0) {
    throw new Error("Enter a deposit amount greater than 0.");
  }

  try {
    const signer = await getSigner();
    const daoContract = await getDaoContract(signer);
    const value = ethers.parseEther(amountEth);

    const tx = await daoContract.buyShares({ value });
    await tx.wait();

    return `Deposit of ${amountEth} ETH sent.`;
  } catch (error) {
    throw new Error(getErrorMessage(error));
  }
}

export async function withdrawFromDao(amountDao: string) {
  if (!amountDao || Number(amountDao) <= 0) {
    throw new Error("Enter a withdrawal amount greater than 0.");
  }

  try {
    const signer = await getSigner();
    const daoContract = await getDaoContract(signer);
    const withdrawalAmount = ethers.parseUnits(amountDao, 18);

    // Solidity: function retrieveShares(uint256 amount)
    const tx = await daoContract.retrieveShares(withdrawalAmount);
    await tx.wait();

    return `Withdraw request for ${amountDao} DAO submitted.`;
  } catch (error) {
    throw new Error(getErrorMessage(error));
  }
}
