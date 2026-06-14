import { ethers } from "ethers";
import { getUserAddress } from "./daoContract";
import { getBrowserProvider, getBrokerContractABI, getBrokerContractAddress } from "./utils";

async function getBrokerContract(signer: ethers.Signer) {
  const address = getBrokerContractAddress();
  if (!address) {
    throw new Error("Broker contract address is not configured.");
  }
  return new ethers.Contract(address, getBrokerContractABI(), signer);
}

export async function isCurrentUserBroker(): Promise<boolean> {
  try {
    const browserProvider = await getBrowserProvider();

    const brokerContract = new ethers.Contract(
      getBrokerContractAddress(),
      getBrokerContractABI(),
      browserProvider 
    );

    const registeredBrokerAddress = await brokerContract.brokerAddress();
    const currentUserAddress = await getUserAddress();
    console.log(registeredBrokerAddress);
    console.log(currentUserAddress);

    return registeredBrokerAddress.toLowerCase() === currentUserAddress.toLowerCase();
  } catch (error) {
    console.error("Error checking broker identity:", error);
    return false;
  }
}

export async function brokerExecuteOrder(
  proposalId: number,
  stock: number,
  isBuy: boolean,
): Promise<string> {
  const browserProvider = await getBrowserProvider();
  const signer = await browserProvider.getSigner();
  const brokerContract = await getBrokerContract(signer);
  const tx = await brokerContract.executeOrder(proposalId, stock, isBuy);

  await tx.wait();
  return `Order for Proposal #${proposalId} executed successfully by Broker. NFT Minted!`;
}