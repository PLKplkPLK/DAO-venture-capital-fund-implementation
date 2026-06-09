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

export type DaoBalances = {
  userBalance: string;
  fundTotal: string;
};

export type Proposal = {
  id: number;
  toBuy: number;
  buyAmount: string;
  toSell: number;
  sellAmount: string;
  label: string | null;
  sellLabel: string | null;
  yesVotes: string;
  noVotes: string;
  snapshotBlock: bigint;
  endTime: bigint;
  executed: boolean;
};

const STOCK_LABELS = ["S&P 500", "Wheat", "Apple"];

function getStockLabel(stock: number) {
  return STOCK_LABELS[stock] ?? `Stock #${stock}`;
}

export const STOCKS = STOCK_LABELS.map((label, index) => ({
  value: index,
  label,
}));

export async function getBalances(): Promise<DaoBalances> {
  const browserProvider = await getBrowserProvider();
  const userAddress = await getUserAddress();
  const contract = new ethers.Contract(
    getContractAddress(),
    getContractABI(),
    browserProvider,
  );

  const [balanceWei, fundBalance] = await Promise.all([
    contract.balanceOf(userAddress),
    browserProvider.getBalance(getContractAddress()),
  ]);

  return {
    userBalance: ethers.formatEther(balanceWei),
    fundTotal: ethers.formatEther(fundBalance),
  };
}

export async function getProposalCount(): Promise<number> {
  const browserProvider = await getBrowserProvider();
  const contract = new ethers.Contract(
    getContractAddress(),
    getContractABI(),
    browserProvider,
  );
  const count = await contract.nextProposalId();
  return Number(count);
}

export async function getProposal(id: number): Promise<Proposal> {
  const browserProvider = await getBrowserProvider();
  const contract = new ethers.Contract(
    getContractAddress(),
    getContractABI(),
    browserProvider,
  );

  const result = await contract.proposals(id);
  return {
    id: Number(result.id),
    toBuy: Number(result.toBuy),
    buyAmount: ethers.formatEther(result.buyAmount),
    toSell: Number(result.toSell),
    sellAmount: ethers.formatEther(result.sellAmount),
    label:
      Number(result.toBuy) < 3 ? getStockLabel(Number(result.toBuy)) : null,
    sellLabel:
      Number(result.toSell) < 3 ? getStockLabel(Number(result.toSell)) : null,
    yesVotes: ethers.formatEther(result.yesVotes),
    noVotes: ethers.formatEther(result.noVotes),
    snapshotBlock: result.snapshotBlock as bigint,
    endTime: result.endTime as bigint,
    executed: result.executed,
  };
}

export async function fetchAllProposals(): Promise<Proposal[]> {
  const count = await getProposalCount();
  const proposalPromises = Array.from({ length: count }, (_, index) =>
    getProposal(index),
  );
  return Promise.all(proposalPromises);
}

export async function createBuyProposal(
  toBuy: number,
  buyAmount: string,
): Promise<string> {
  const signer = await getSigner();
  const daoContract = await getDaoContract(signer);
  const buyAmountWei = ethers.parseEther(buyAmount);
  const tx = await daoContract.createBuyProposal(toBuy, buyAmountWei);
  await tx.wait();
  return "Buy proposal created successfully.";
}

export async function createSellProposal(
  toSell: number,
  sellAmount: string,
): Promise<string> {
  const signer = await getSigner();
  const daoContract = await getDaoContract(signer);
  const sellAmountWei = ethers.parseEther(sellAmount);
  const tx = await daoContract.createSellProposal(toSell, sellAmountWei);
  await tx.wait();
  return "Sell proposal created successfully.";
}

export async function voteOnProposal(
  proposalId: number,
  choice: number,
): Promise<string> {
  const signer = await getSigner();
  const daoContract = await getDaoContract(signer);
  const tx = await daoContract.vote(proposalId, choice);
  await tx.wait();
  return "Vote submitted successfully.";
}

export async function executeProposal(proposalId: number): Promise<string> {
  const signer = await getSigner();
  const contract = await getDaoContract(signer);
  try {
    const tx = await contract.executeProposal(proposalId);
    await tx.wait(); // Wait for confirmation block on local network
    return `Proposal #${proposalId} executed successfully! Portfolio updated.`;
  } catch (error) {
    console.error("Execution exception:", error);
    if (error instanceof Error) throw error;
    throw new Error(getErrorMessage(error));
  }
}

export async function subscribeToTransferEvents(
  onTransfer: (from: string, to: string, value: string) => void,
): Promise<() => void> {
  const provider = await getBrowserProvider();
  const contract = new ethers.Contract(
    getContractAddress(),
    getContractABI(),
    provider,
  );

  const listener = (from: string, to: string, value: bigint) => {
    onTransfer(from, to, ethers.formatEther(value));
  };

  contract.on("Transfer", listener);

  return () => {
    contract.off("Transfer", listener);
  };
}

export async function depositToDao(amountEth: string) {
  if (!amountEth || Number(amountEth) <= 0) {
    throw new Error("Enter a deposit amount greater than 0.");
  }

  try {
    const signer = await getSigner();
    const daoContract = await getDaoContract(signer);
    const userAddress = await signer.getAddress();
    const value = ethers.parseEther(amountEth);

    // 1. Execute the Deposit
    const tx = await daoContract.buyShares({ value });
    await tx.wait();

    // 2. Check if they have activated their voting power yet
    const currentDelegate = await daoContract.delegates(userAddress);

    // If currentDelegate is the zero address, they haven't delegated to themselves
    if (currentDelegate === ethers.ZeroAddress) {
      // Automatically trigger self-delegation
      const delegateTx = await daoContract.delegate(userAddress);
      await delegateTx.wait();
      return `Deposit successful and voting power automatically activated!`;
    }

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

    const tx = await daoContract.retrieveEth(withdrawalAmount);
    await tx.wait();

    return `Withdraw request for ${amountDao} DAO submitted.`;
  } catch (error) {
    throw new Error(getErrorMessage(error));
  }
}

export async function getFundTotalValue(): Promise<string> {
  const browserProvider = await getBrowserProvider();
  const contract = new ethers.Contract(
    getContractAddress(),
    getContractABI(),
    browserProvider,
  );

  try {
    const totalValue = await contract.getFundTotalValue();
    return ethers.formatEther(totalValue);
  } catch (error) {
    console.error("Error getting fund total value:", error);
    return "0";
  }
}

export async function getPortfolioValue(): Promise<string> {
  const browserProvider = await getBrowserProvider();
  const contract = new ethers.Contract(
    getContractAddress(),
    getContractABI(),
    browserProvider,
  );

  try {
    const value = await contract.getPortfolioValue();
    return ethers.formatEther(value);
  } catch (error) {
    console.error("Error getting portfolio value:", error);
    return "0";
  }
}

export async function getPortfolioStock(stock: number): Promise<string> {
  const browserProvider = await getBrowserProvider();
  const contract = new ethers.Contract(
    getContractAddress(),
    getContractABI(),
    browserProvider,
  );

  try {
    const amount = await contract.getPortfolioStock(stock);
    return ethers.formatEther(amount);
  } catch (error) {
    console.error("Error getting portfolio stock:", error);
    return "0";
  }
}

export async function getPriceForStock(stock: number): Promise<string> {
  const browserProvider = await getBrowserProvider();
  const daoContract = new ethers.Contract(getContractAddress(), getContractABI(), browserProvider);

  try {
    const oracleAddress: string = await daoContract.priceOracle();
    if (!oracleAddress || oracleAddress === ethers.ZeroAddress) return "0";

    const oracleAbi = ["function getPrice(uint8) view returns (uint256)"];
    const oracle = new ethers.Contract(oracleAddress, oracleAbi, browserProvider);
    const price = await oracle.getPrice(stock);
    return ethers.formatEther(price);
  } catch (error) {
    console.error("Error fetching oracle price:", error);
    return "0";
  }
}

export async function getAllPortfolioStocks(): Promise<Record<string, string>> {
  const holdings: Record<string, string> = {};
  for (let i = 0; i < 3; i++) {
    holdings[STOCK_LABELS[i]] = await getPortfolioStock(i);
  }
  return holdings;
}

export async function depositBroker(amountEth: string) {
  if (!amountEth || Number(amountEth) <= 0) {
    throw new Error("Enter a deposit amount greater than 0.");
  }

  try {
    const signer = await getSigner();
    const daoContract = await getDaoContract(signer);
    const value = ethers.parseEther(amountEth);

    const tx = await daoContract.depositBroker({ value });
    await tx.wait();
    return `Broker deposit of ${amountEth} ETH submitted.`;
  } catch (error) {
    throw new Error(getErrorMessage(error));
  }
}

export async function getBrokerDeposit(brokerAddress?: string): Promise<string> {
  const browserProvider = await getBrowserProvider();
  const contract = new ethers.Contract(getContractAddress(), getContractABI(), browserProvider);
  try {
    let addr = brokerAddress;
    if (!addr) {
      addr = await getUserAddress();
    }
    const amount = await contract.brokerDepositOf(addr);
    return ethers.formatEther(amount);
  } catch (error) {
    console.error("Error getting broker deposit:", error);
    return "0";
  }
}

export async function getRequiredBrokerDeposit(): Promise<string> {
  const browserProvider = await getBrowserProvider();
  console.log(getContractABI());
  const contract = new ethers.Contract(getContractAddress(), getContractABI(), browserProvider);
  try {
    const amount = await contract.requiredBrokerDeposit();
    return ethers.formatEther(amount);
  } catch (error) {
    console.error("Error getting required broker deposit:", error);
    return "N/A";
  }
}
