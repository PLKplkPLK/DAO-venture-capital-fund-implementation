// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title TransactionNFT
/// @notice Portfolio positions represented as NFTs minted by the Broker and owned by the DAO Treasury.
contract TransactionNFT is ERC721 {
    
    enum TransactionType {
        BUY,
        SELL
    }

    struct Transaction {
        uint256 proposalId;
        uint8 stock;
        TransactionType transactionType;
        uint256 amount;
        uint256 price;
        address broker;
        uint256 timestamp;
    }

    // ========== State Variables ==========

    uint256 public nextTransactionId;
    address public owner;
    
    address public daoContract;       // Destination address that will receive and own the NFTs (HedgeFundDAO)
    address public brokerContract;    // Authorized execution contract allowed to trigger minting (InvestmentBroker)

    mapping(uint256 => Transaction) public transactions;
    // broker address => list of transaction tokenIds minted for that broker
    mapping(address => uint256[]) public brokerTransactions;

    event TransactionMinted(uint256 indexed tokenId, address indexed broker, uint256 indexed proposalId);

    // ========== Modifiers ==========

    modifier onlyBroker() {
        require(msg.sender == brokerContract, "Only the registered Broker contract can call this");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this");
        _;
    }

    // ========== Constructor ==========

    constructor()
        ERC721("HF Transaction", "HFT")
    {
        owner = msg.sender;
    }

    // ========== Configuration ==========

    /// @notice Sets the main DAO contract address which will hold the minted NFTs.
    /// @param _dao Address of the HedgeFundDAO contract.
    function setDAO(address _dao) external onlyOwner {
        require(_dao != address(0), "Invalid DAO address");
        daoContract = _dao;
    }

    /// @notice Sets the InvestmentBroker contract address authorized to mint position certificates.
    /// @param _broker Address of the InvestmentBroker contract.
    function setBroker(address _broker) external onlyOwner {
        require(_broker != address(0), "Invalid Broker address");
        brokerContract = _broker;
    }

    // ========== External Functions ==========

    /// @notice Mints a new trade certificate NFT directly to the DAO contract treasury.
    /// @dev Accessible only by the authorized InvestmentBroker contract.
    function mintTransaction(
        uint256 proposalId,
        uint8 stock,
        bool isBuy,
        uint256 amount,
        uint256 price,
        address brokerWallet
    ) external onlyBroker returns (uint256) {
        require(daoContract != address(0), "DAO contract address not initialized");
        require(brokerWallet != address(0), "Invalid broker address");
        require(price > 0, "Invalid price");
        require(amount > 0, "Invalid amount");
        
        uint256 tokenId = nextTransactionId;

        transactions[tokenId] = Transaction({
            proposalId: proposalId,
            stock: stock,
            transactionType: isBuy
                ? TransactionType.BUY
                : TransactionType.SELL,
            amount: amount,
            price: price,
            broker: brokerWallet,
            timestamp: block.timestamp
        });

        // The DAO contract is the owner of the portfolio asset position
        _mint(daoContract, tokenId);

        // record that this broker initiated the transaction (helps broker query their activity)
        brokerTransactions[brokerWallet].push(tokenId);

        emit TransactionMinted(tokenId, brokerWallet, proposalId);

        nextTransactionId++;

        return tokenId;
    }

    /// @notice Returns transaction data details for a specific NFT token ID.
    function getTransaction(
        uint256 tokenId
    ) external view returns (Transaction memory) {
        require(tokenId < nextTransactionId, "Nonexistent token");
        return transactions[tokenId];
    }

    /// @notice Returns the broker address that initiated a given transaction NFT.
    /// @param tokenId The transaction NFT id
    function getTransactionBroker(uint256 tokenId) external view returns (address) {
        require(tokenId < nextTransactionId, "Nonexistent token");
        return transactions[tokenId].broker;
    }

    /// @notice Returns list of tokenIds minted that were initiated by a broker address
    function getBrokerTransactions(address broker) external view returns (uint256[] memory) {
        return brokerTransactions[broker];
    }
}