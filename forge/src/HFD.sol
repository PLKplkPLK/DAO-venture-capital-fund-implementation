// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

/// @dev Enum representing the available stocks the DAO can trade
enum Stock {
    SP500,  // 0 - S&P 500
    Wheat,  // 1 - Wheat
    Apple   // 2 - Apple
}

/// @dev Interface for price oracle to get stock prices
interface IPriceOracle {
    function getPrice(uint8 stock) external view returns (uint256);
}

/// @dev Represents a trading proposal in the DAO
struct Proposal {
    uint256 id;              // Unique proposal identifier
    uint8 toBuy;             // Stock to buy (255 = none)
    uint256 buyAmount;       // ETH to spend on buying
    uint8 toSell;            // Stock to sell (255 = none)
    uint256 sellAmount;      // Amount of stock to sell
    uint256 yesVotes;        // Total votes in favor
    uint256 noVotes;         // Total votes against
    uint256 snapshotBlock;   // Block number for voting power snapshot
    uint256 endTime;         // Voting period end time
    bool executed;           // Whether proposal has been executed
}

/// @dev A decentralized hedge fund managed through governance voting
contract HedgeFundDAO is ERC20, ERC20Permit, ERC20Votes {
    // ========== State Variables ==========

    uint256 public nextProposalId;
    uint256 public cashBalance;  // Uninvested ETH inside the fund

    /// @dev Vote choices: 0 = None, 1 = Yes, 2 = No
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => uint8)) public userVotes;
    mapping(uint8 => uint256) public portfolio;  // Holdings by stock type

    IPriceOracle public priceOracle;
    address public owner; 
    address public brokerContract;
    // Broker deposit tracking — brokers must post a deposit before executing proposals
    mapping(address => uint256) public brokerDeposits;
    uint256 public immutable requiredBrokerDeposit = 100 ether;

    // ========== Events ==========

    event ProposalCreated(
        uint256 indexed proposalId,
        uint8 toBuy,
        uint256 buyAmount,
        uint8 toSell,
        uint256 sellAmount
    );
    event Voted(
        uint256 indexed proposalId,
        address indexed voter,
        uint8 choice,
        uint256 weight
    );
    event ProposalExecuted(
        uint256 indexed proposalId,
        uint256 ethSpent,
        uint256 ethGained
    );
    event PriceOracleUpdated(address newOracle);

    // ========== Modifiers ==========

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyBrokerContract() {
        require(msg.sender == brokerContract, "Caller is not the Broker Contract");
        _;
    }

    // ========== Constructor ==========

    constructor() ERC20("HF Token", "HF") ERC20Permit("HF Token") {
        owner = msg.sender;
    }
    
    // ========== Setters ==========

    function setBroker(address _brokerContract) external onlyOwner {
        brokerContract = _brokerContract;
    }

    /// @notice Broker can deposit ETH to be eligible to execute proposals
    function depositBroker() external payable {
        require(msg.value > 0, "Deposit must be > 0");
        brokerDeposits[msg.sender] += msg.value;
    }

    /// @notice Broker may withdraw their deposit (if not slashed)
    function withdrawBrokerDeposit(uint256 amount) external {
        require(brokerDeposits[msg.sender] >= amount, "Not enough deposit");
        brokerDeposits[msg.sender] -= amount;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    /// @notice View broker deposit for address
    function brokerDepositOf(address broker) external view returns (uint256) {
        return brokerDeposits[broker];
    }

    /// @notice Slash a broker's deposit (collect into DAO cashBalance). Restricted to owner for now.
    function slashBrokerDeposit(address broker, uint256 amount) external onlyOwner {
        require(brokerDeposits[broker] >= amount, "Not enough deposit to slash");
        brokerDeposits[broker] -= amount;
        cashBalance += amount;
    }

    // ========== Fund Management ==========

    /// @notice Purchase fund shares by depositing ETH
    /// @dev Mints tokens proportional to the fund's net value
    function buyShares() external payable {
        require(msg.value > 0, "Need to send ETH");

        uint256 totalValue = getFundTotalValue();
        uint256 supply = totalSupply();
        uint256 tokensToMint;

        if (supply == 0 || totalValue == 0) {
            tokensToMint = msg.value;
        } else {
            // Price tokens proportional to the current net value of the fund
            tokensToMint = (msg.value * supply) / totalValue;
        }

        cashBalance += msg.value;
        _mint(msg.sender, tokensToMint);

        // Automatically self-delegate voting power if not already delegated
        if (delegates(msg.sender) == address(0)) {
            _delegate(msg.sender, msg.sender);
        }
    }

    /// @notice Withdraw ETH by burning fund shares
    /// @param tokenAmount Amount of fund tokens to redeem
    function retrieveEth(uint256 tokenAmount) external {
        require(tokenAmount <= balanceOf(msg.sender), "Not enough tokens");

        uint256 totalValue = getFundTotalValue();
        uint256 supply = totalSupply();

        uint256 ethToReturn = (tokenAmount * totalValue) / supply;
        require(ethToReturn <= cashBalance, "Not enough liquid ETH in fund; sell assets first");

        cashBalance -= ethToReturn;
        _burn(msg.sender, tokenAmount);

        (bool success, ) = msg.sender.call{value: ethToReturn}("");
        require(success, "ETH transfer failed");
    }

    /// @notice Set the price oracle contract address
    /// @param _oracle Address of the price oracle
    function setPriceOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0), "Invalid oracle address");
        priceOracle = IPriceOracle(_oracle);
        emit PriceOracleUpdated(_oracle);
    }

    // ========== Proposals ==========

    /// @notice Create a proposal to buy a stock
    /// @param toBuy Stock type to buy
    /// @param buyAmount ETH amount to spend
    function createBuyProposal(
        uint8 toBuy,
        uint256 buyAmount
    ) external {
        require(balanceOf(msg.sender) > 1, "Must hold at least 1 DAO token to create proposals");
        require(toBuy < 3, "Invalid stock to buy");
        require(buyAmount > 0, "Buy amount must be > 0");

        proposals[nextProposalId] = Proposal({
            id: nextProposalId,
            toBuy: toBuy,
            buyAmount: buyAmount,
            toSell: 255,
            sellAmount: 0,
            yesVotes: 0,
            noVotes: 0,
            snapshotBlock: block.number,
            endTime: block.timestamp + 1 minutes,
            executed: false
        });

        emit ProposalCreated(nextProposalId, toBuy, buyAmount, 255, 0);
        nextProposalId++;
    }

    /// @notice Create a proposal to sell a stock
    /// @param toSell Stock type to sell
    /// @param sellAmount Amount of stock to sell
    function createSellProposal(
        uint8 toSell,
        uint256 sellAmount
    ) external {
        require(balanceOf(msg.sender) > 1, "Must hold at least 1 DAO token to create proposals");
        require(toSell < 3, "Invalid stock to sell");
        require(sellAmount > 0, "Sell amount must be > 0");
        require(sellAmount <= portfolio[toSell], "Not enough stock to sell");

        proposals[nextProposalId] = Proposal({
            id: nextProposalId,
            toBuy: 255,
            buyAmount: 0,
            toSell: toSell,
            sellAmount: sellAmount,
            yesVotes: 0,
            noVotes: 0,
            snapshotBlock: block.number,
            endTime: block.timestamp + 3 minutes,
            executed: false
        });

        emit ProposalCreated(nextProposalId, 255, 0, toSell, sellAmount);
        nextProposalId++;
    }

    /// @notice Vote on a proposal
    /// @param proposalId ID of the proposal to vote on
    /// @param choice Vote choice (1 = Yes, 2 = No)
    function vote(uint256 proposalId, uint8 choice) external {
        require(proposalId < nextProposalId, "Proposal does not exist");
        require(choice == 1 || choice == 2, "1=Yes, 2=No");
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp < proposal.endTime, "Voting has ended");

        uint256 weight = getPastVotes(msg.sender, proposal.snapshotBlock);
        require(weight > 0, "No voting power at snapshot");

        uint8 previousChoice = userVotes[proposalId][msg.sender];
        require(previousChoice != choice, "Already voted this way");

        if (previousChoice == 1) proposal.yesVotes -= weight;
        if (previousChoice == 2) proposal.noVotes -= weight;

        if (choice == 1) proposal.yesVotes += weight;
        if (choice == 2) proposal.noVotes += weight;

        userVotes[proposalId][msg.sender] = choice;
        emit Voted(proposalId, msg.sender, choice, weight);
    }

    /// @notice This function is called by the Broker contract to update the DAO's portfolio state.
    function executeProposal(
        uint256 proposalId, 
        uint256 ethSpent, 
        uint256 ethGained, 
        uint8 stock, 
        uint256 stockAmount, 
        bool isBuy
    ) external payable onlyBrokerContract {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        if (isBuy) {
            require(cashBalance >= ethSpent, "Insufficient liquid cash in DAO");
            cashBalance -= ethSpent;
            portfolio[stock] += stockAmount;

            proposal.executed = true;
            
            (bool success, ) = payable(msg.sender).call{value: ethSpent}("");
            require(success, "ETH transfer to Broker failed");
        } else {
            require(msg.value == ethGained, "Sent ETH does not match ethGained");
            require(portfolio[stock] >= stockAmount, "Not enough stock in portfolio to sell");
            
            portfolio[stock] -= stockAmount;
            cashBalance += ethGained;
            
            proposal.executed = true;
        }

        emit ProposalExecuted(proposalId, ethSpent, ethGained);
    }

    // ========== View Functions ==========

    /// @notice Get the total value of the fund (cash + portfolio)
    function getFundTotalValue() public view returns (uint256) {
        return cashBalance + getPortfolioValue();
    }

    /// @notice Get the current value of all portfolio holdings
    function getPortfolioValue() public view returns (uint256) {
        if (address(priceOracle) == address(0)) return 0;

        uint256 totalValue = 0;
        for (uint8 i = 0; i < 3; i++) {
            uint256 amount = portfolio[i];
            if (amount > 0) {
                totalValue += (amount * priceOracle.getPrice(i)) / 1e18;
            }
        }
        return totalValue;
    }

    /// @notice Get the amount of a specific stock held in the portfolio
    /// @param stock Stock type to query
    function getPortfolioStock(uint8 stock) external view returns (uint256) {
        require(stock < 3, "Invalid stock");
        return portfolio[stock];
    }

    // ========== ERC20 Overrides ==========
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
