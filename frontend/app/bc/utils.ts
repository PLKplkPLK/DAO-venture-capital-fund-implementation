import { ethers } from "ethers";

export {
  getProvider,
  getBrowserProvider,
  getContractABI,
  getContractAddress,
  getBrokerContractAddress,
  getBrokerContractABI,
  getNFTContractAddress,
  getNFTContractABI,
};

const DAO_CONTRACT_ADDRESS = process.env.NEXT_PUBLIC_DAO_CONTRACT_ADDRESS;

const BROKER_CONTRACT_ADDRESS = process.env.NEXT_PUBLIC_BROKER_CONTRACT_ADDRESS;

const NFT_CONTRACT_ADDRESS = process.env.NEXT_PUBLIC_NFT_CONTRACT_ADDRESS;

const DAO_CONTRACT_ABI = [
  "function buyShares() payable",
  "function depositBroker() payable",
  "function retrieveEth(uint256 amount)",
  "function balanceOf(address account) view returns (uint256)",
  "function nextProposalId() view returns (uint256)",
  "function proposals(uint256) view returns (uint256 id, uint8 toBuy, uint256 buyAmount, uint8 toSell, uint256 sellAmount, uint256 yesVotes, uint256 noVotes, uint256 snapshotBlock, uint256 endTime, bool executed)",
  "function createBuyProposal(uint8 toBuy, uint256 buyAmount)",
  "function createSellProposal(uint8 toSell, uint256 sellAmount)",
  "function executeProposal(uint256 proposalId, uint256 ethSpent, uint256 ethGained, uint8 stock, uint256 stockAmount, bool isBuy) payable",
  "function vote(uint256 proposalId, uint8 choice)",
  "function getFundTotalValue() view returns (uint256)",
  "function priceOracle() view returns (address)",
  "function nftContract() view returns (address)",
  "function brokerDepositOf(address) view returns (uint256)",
  "function requiredBrokerDeposit() view returns (uint256)",
  "function getPortfolioValue() view returns (uint256)",
  "function getPortfolioStock(uint8 stock) view returns (uint256)",
  "function portfolio(uint8) view returns (uint256)",
  "function cashBalance() view returns (uint256)",
  "event Transfer(address indexed from, address indexed to, uint256 value)",
  "event ProposalExecuted(uint256 indexed proposalId, uint256 ethSpent, uint256 ethGained)",
  "function delegate(address delegatee)",
  "function delegates(address account) view returns (address)",
  "function audits(uint256 nftTokenId) view returns (uint256 nftTokenId, uint256 proposalId, uint256 approveVotes, uint256 slashVotes, uint256 auditEndTime, bool auditClosed, bool brokerSlashed)",
  "function hasVotedInAudit(uint256 nftTokenId, address voter) view returns (bool)",
  "function userVotes(uint256 proposalId, address voter) view returns (uint8)",
  "function initializeAudit(uint256 nftTokenId, uint256 proposalId)",
  "function voteOnAudit(uint256 nftTokenId, uint8 choice)",
  "function finalizeAudit(uint256 nftTokenId)",
  "event AuditVoteSubmitted(uint256 indexed nftTokenId, address indexed voter, uint8 choice, uint256 weight)",
  "event AuditFinalized(uint256 indexed nftTokenId, bool slashed, uint256 amountSlashed)",
];

const NFT_CONTRACT_ABI = [
  "function getTransaction(uint256 tokenId) view returns (uint256 proposalId, uint8 stock, uint8 transactionType, uint256 amount, uint256 price, address broker, uint256 timestamp)",
  "function getBrokerTransactions(address) view returns (uint256[])",
  "function nextTransactionId() view returns (uint256)",
  "function ownerOf(uint256) view returns (address)",
  "function balanceOf(address owner) view returns (uint256)",
  "function mintTransaction(uint256 proposalId, uint8 stock, bool isBuy, uint256 stockAmount, uint256 price, address broker) returns (uint256)",
  "event Transfer(address indexed from, address indexed to, uint256 indexed tokenId)",
  "function getTransactionBroker(uint256 tokenId) view returns (address)",
  "function getTransaction(uint256 tokenId) view returns (uint256 proposalId, uint8 stock, uint8 transactionType, uint256 amount, uint256 price, address broker, uint256 timestamp)",
];

const BROKER_CONTRACT_ABI = [
  "function brokerAddress() view returns (address)",
  "function executeOrder(uint256 proposalId, uint8 stock, bool isBuy) returns (uint256)",
  "event OrderExecuted(uint256 indexed proposalId, uint256 indexed tokenId, uint256 executionPrice)",
];

function getProvider() {
  // return new ethers.JsonRpcProvider("http://127.0.0.1:8545");
  return new ethers.JsonRpcProvider(process.env.RPC_URL);
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
  const expectedChainId = BigInt(
    process.env.NEXT_PUBLIC_CHAIN_ID ?? "11155111",
  );

  if (network.chainId !== expectedChainId) {
    throw new Error(
      `Wrong network. Expected ${expectedChainId}, got ${network.chainId}`,
    );
  }

  return provider;
}

function getContractABI() {
  return DAO_CONTRACT_ABI;
}

function getContractAddress() {
  return DAO_CONTRACT_ADDRESS;
}

function getBrokerContractAddress() {
  return BROKER_CONTRACT_ADDRESS;
}
function getBrokerContractABI() {
  return BROKER_CONTRACT_ABI;
}

function getNFTContractAddress() {
  return NFT_CONTRACT_ADDRESS;
}

function getNFTContractABI() {
  return NFT_CONTRACT_ABI;
}
