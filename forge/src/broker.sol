// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @dev Interface to interact with the main HedgeFundDAO contract.
interface IHedgeFundDAO {
    function proposals(uint256 proposalId) external view returns (
        uint256 id, uint8 toBuy, uint256 buyAmount, uint8 toSell, uint256 sellAmount,
        uint256 yesVotes, uint256 noVotes, uint256 snapshotBlock, uint256 endTime, bool executed
    );
    function finalizeTradeFromBroker(
        uint256 proposalId, uint256 ethSpent, uint256 ethGained, uint8 stock, uint256 stockAmount, bool isBuy
    ) external;
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

    /// @dev Emitted when the broker executes an order and mints a transaction NFT.
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
     * @param stock Asset type ID (0 = SP500, 1 = Wheat, 2 = Apple).
     * @param isBuy True for BUY, false for SELL.
     * @return tokenId unique tokenId of the newly minted transaction NFT.
     */
    function executeOrder(
        uint256 proposalId,
        uint8 stock,
        bool isBuy
    ) external onlyBroker returns (uint256) {
        // 1. Retrieve proposal and verify it's eligible for execution
        (, , uint256 buyAmount, , uint256 sellAmount, uint256 yesVotes, uint256 noVotes, , uint256 endTime, bool executed) = dao.proposals(proposalId);

        require(!executed, "Order already filled");
        require(block.timestamp >= endTime, "Voting is still active in DAO");
        require(yesVotes > noVotes, "Proposal failed voting requirements");
        require(stock < 3, "Invalid stock ID");

        // 2. Get price from on-chain oracle
        uint256 currentMarketPrice = priceOracle.getPrice(stock);
        require(currentMarketPrice > 0, "Oracle returned zero price");

        uint256 stockGained = 0;
        uint256 ethSpent = 0;
        uint256 ethGained = 0;

        if (isBuy) {
            ethSpent = buyAmount;
            // Calculate how many stock units are bought for ethSpent
            // stock units are denominated with 18 decimals in this system
            stockGained = (ethSpent * 1e18) / currentMarketPrice;
        } else {
            uint256 stockToSell = sellAmount;
            // Calculate ETH gained by selling stockToSell units
            ethGained = (stockToSell * currentMarketPrice) / 1e18;
        }

        // 3. Notify DAO to update internal accounting and (for buys) transfer ETH to this contract
        dao.finalizeTradeFromBroker(proposalId, ethSpent, ethGained, stock, isBuy ? stockGained : sellAmount, isBuy);

        // 4. If this was a SELL, the broker contract should forward obtained ETH back to DAO treasury
        // (DAO.finalizeTradeFromBroker for sells doesn't send ETH to broker, broker may have received ETH off-chain;
        // but keep the previously used safe pattern: if this contract holds ethGained we forward to DAO)
        if (!isBuy && ethGained > 0) {
            (bool success, ) = payable(address(dao)).call{value: ethGained}("");
            require(success, "Failed to send ethGained back to DAO");
        }

        // 5. Mint transaction NFT to DAO treasury as on-chain proof
        uint256 nftAmount = isBuy ? stockGained : sellAmount;
        require(nftAmount > 0, "Computed NFT amount is zero");

        uint256 tokenId = nftContract.mintTransaction(
            proposalId,
            stock,
            isBuy,
            nftAmount,
            currentMarketPrice,
            msg.sender
        );

        emit OrderExecuted(proposalId, tokenId, currentMarketPrice);
        return tokenId;
    }

    // Allow contract to receive ETH (DAO may send ETH for buys)
    receive() external payable {}
    fallback() external payable {}
}