// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @dev Interface to interact with the main HedgeFundDAO contract.
interface IHedgeFundDAO {
    function proposals(uint256 proposalId) external view returns (
        uint256 id, uint8 toBuy, uint256 buyAmount, uint8 toSell, uint256 sellAmount,
        uint256 yesVotes, uint256 noVotes, uint256 snapshotBlock, uint256 endTime, bool executed
    );
    function executeProposal(
        uint256 proposalId, uint256 ethSpent, uint256 ethGained, uint8 stock, uint256 stockAmount, bool isBuy
    ) external payable;
    // Broker deposit helpers
    function brokerDepositOf(address broker) external view returns (uint256);
    function requiredBrokerDeposit() external view returns (uint256);
    function cashBalance() external view returns (uint256);
    function initializeAudit(uint256 nftTokenId, uint256 proposalId) external;
}

/// @dev Interface for price oracle to return per-stock prices.
interface IPriceOracle {
    function getPrice(uint8 stock) external view returns (uint256);
}

/// @dev Interface to interact with the TransactionNFT contract.
interface ITransactionNFT {
    function mintTransaction(
        uint256 proposalId, uint8 stock, bool isBuy, uint256 amount, uint256 price, address broker
    ) external returns (uint256);
}


/// @title InvestmentBroker
/// @notice Broker contract that executes approved DAO proposals, interacts with an on-chain price oracle, and mints trade NFTs to the DAO treasury as proof-of-trade.
contract InvestmentBroker {
    // ========== State Variables ==========
    
    address public owner;             // The contract deployer/admin
    address public brokerAddress;     // The authorized wallet address of the actual broker (EOA)
    IHedgeFundDAO public dao;         // Instance of the main DAO contract
    ITransactionNFT public nftContract; // Instance of the Transaction NFT contract
    IPriceOracle public priceOracle;

    // ========== Events ==========

    event OrderExecuted(uint256 indexed proposalId, uint256 nftTokenId, uint256 price);

    // ========== Modifiers ==========
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyBroker() {
        require(msg.sender == brokerAddress, "Caller is not the authorized broker");
        _;
    }

    // ========== Constructor ==========
    
    /**
     * @notice Initializes the broker management contract.
     * @param _dao Address of the deployed HedgeFundDAO.
     * @param _nft Address of the deployed TransactionNFT.
     * @param _priceOracle Address of the price oracle contract.
     */
    constructor(address _dao, address _nft, address _priceOracle) {
        owner = msg.sender;
        dao = IHedgeFundDAO(_dao);
        nftContract = ITransactionNFT(_nft);
        priceOracle = IPriceOracle(_priceOracle);
        brokerAddress = msg.sender;
    }

    /**
     * @notice Updates the designated broker wallet address.
     * @param _newBroker The new address authorized to execute orders.
     */
    function updateBrokerAddress(address _newBroker) external onlyOwner {
        brokerAddress = _newBroker;
    }

    // ========== Order Execution (Mocked) ==========

    /**
     * @notice Called by the Broker to log execution details and mint a proof-of-trade NFT for the DAO.
     * @param proposalId The ID of the approved governance proposal.
     * @param stock Asset type ID (0 = BTC, 1 = LINK, 2 = ETH). Must match the asset the DAO voted on.
     * @param isBuy True for BUY, false for SELL. Must match the proposal's side.
     * @return tokenId unique tokenId of the newly minted transaction NFT.
     */
    function executeOrder(
        uint256 proposalId,
        uint8 stock,
        bool isBuy
    ) external onlyBroker returns (uint256) {
        // Ensure broker has posted required deposit in DAO
        require(dao.brokerDepositOf(msg.sender) >= dao.requiredBrokerDeposit(), "Broker deposit insufficient");
        
        // 1. Retrieve proposal and verify it's eligible for execution
        (, uint8 toBuy, uint256 buyAmount, uint8 toSell, uint256 sellAmount, uint256 yesVotes, uint256 noVotes, , uint256 endTime, bool executed) = dao.proposals(proposalId);

        require(!executed, "Order already executed for this proposal");
        require(block.timestamp >= endTime, "Voting is still active in DAO");
        require(yesVotes > noVotes, "Proposal failed voting requirements");
        require(stock < 3, "Invalid stock ID");

        // The broker must execute exactly what the DAO voted on: the side (buy/sell)
        // and the asset are dictated by the proposal, not chosen by the broker.
        if (isBuy) {
            require(toBuy == stock, "Stock does not match the buy proposal");
        } else {
            require(toSell == stock, "Stock does not match the sell proposal");
        }

        // 2. Get price from on-chain oracle
        uint256 currentMarketPrice = priceOracle.getPrice(stock);
        require(currentMarketPrice > 0, "Oracle returned zero price");

        uint256 stockAmountTransacted = 0;
        uint256 ethSpent = 0;
        uint256 ethGained = 0;

        if (isBuy) {
            ethSpent = buyAmount;
            require(dao.cashBalance() >= ethSpent, "DAO has insufficient cash balance for this buy");
            stockAmountTransacted = (ethSpent * 1e18) / currentMarketPrice;
        } else {
            stockAmountTransacted = sellAmount;
            ethGained = (stockAmountTransacted * currentMarketPrice) / 1e18;
        }

        require(stockAmountTransacted > 0, "Computed NFT amount is zero");
        
        // 5. Mint transaction NFT to DAO treasury
        uint256 tokenId = nftContract.mintTransaction(
            proposalId,
            stock,
            isBuy,
            stockAmountTransacted,
            currentMarketPrice,
            msg.sender
        );

        dao.initializeAudit(tokenId, proposalId);

        if (isBuy) {
            dao.executeProposal(proposalId, ethSpent, 0, stock, stockAmountTransacted, true);
        } else {
            dao.executeProposal(proposalId, 0, ethGained, stock, stockAmountTransacted, false);
        }

        emit OrderExecuted(proposalId, tokenId, currentMarketPrice);
        return tokenId;
    }

    receive() external payable {}
    fallback() external payable {}
}