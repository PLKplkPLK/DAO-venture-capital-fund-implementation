// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

enum Stock {
    SP500,     // 0 - S&P 500
    Wheat,     // 1 - Wheat
    Apple      // 2 - Apple
}

interface IPriceOracle {
    function getPrice(uint8 stock) external view returns (uint256);
}

struct Proposal {
    uint256 id;
    uint8 toBuy;           // Which stock to buy (255 = none)
    uint256 buyAmount;     // ETH to spend on buying
    uint8 toSell;          // Which stock to sell (255 = none)
    uint256 sellAmount;    // Amount of stock to sell
    uint256 yesVotes;
    uint256 noVotes;
    uint256 snapshotBlock;
    uint256 endTime;
    bool executed;
}

contract HedgeFundDAO is ERC20, ERC20Permit, ERC20Votes {
    uint256 public nextProposalId;
    uint256 public cashBalance; // Uninvested ETH inside the fund

    // 0 = None, 1 = Yes, 2 = No
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => uint8)) public userVotes;
    mapping(uint8 => uint256) public portfolio;

    IPriceOracle public priceOracle;
    address public owner; 

    event ProposalCreated(uint256 indexed proposalId, uint8 toBuy, uint256 buyAmount, uint8 toSell, uint256 sellAmount);
    event Voted(uint256 indexed proposalId, address indexed voter, uint8 choice, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId, uint256 ethSpent, uint256 ethGained);
    event PriceOracleUpdated(address newOracle);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor() ERC20("HF Token", "HF") ERC20Permit("HF Token") {
        owner = msg.sender;
    }

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

        if (delegates(msg.sender) == address(0)) {
            _delegate(msg.sender, msg.sender);
        }
    }

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

    function setPriceOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0), "Invalid oracle address");
        priceOracle = IPriceOracle(_oracle);
        emit PriceOracleUpdated(_oracle);
    }

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
            endTime: block.timestamp + 3 minutes,
            executed: false
        });

        emit ProposalCreated(nextProposalId, toBuy, buyAmount, 255, 0);
        nextProposalId++;
    }

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

    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposalId < nextProposalId, "Proposal missing");
        require(!proposal.executed, "Already executed");
        require(block.timestamp >= proposal.endTime, "Voting active");
        require(proposal.yesVotes > proposal.noVotes, "Proposal failed");
        require(address(priceOracle) != address(0), "Oracle not configured");

        uint256 ethGained = 0;
        uint256 ethSpent = 0;

        // 1. Process Sells First (to release cash pool liquidity)
        if (proposal.toSell < 3) {
            uint256 sellPrice = priceOracle.getPrice(proposal.toSell);
            ethGained = (proposal.sellAmount * sellPrice) / 1e18;
            
            portfolio[proposal.toSell] -= proposal.sellAmount;
            cashBalance += ethGained;
        }

        // 2. Process Buys
        if (proposal.toBuy < 3) {
            ethSpent = proposal.buyAmount;
            require(cashBalance >= ethSpent, "Insufficient liquid cash in DAO");

            uint256 buyPrice = priceOracle.getPrice(proposal.toBuy);
            uint256 stockGained = (ethSpent * 1e18) / buyPrice;

            cashBalance -= ethSpent;
            portfolio[proposal.toBuy] += stockGained;
        }

        proposal.executed = true;
        emit ProposalExecuted(proposalId, ethSpent, ethGained);
    }

    function getFundTotalValue() public view returns (uint256) {
        return cashBalance + getPortfolioValue();
    }

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

    function getPortfolioStock(uint8 stock) external view returns (uint256) {
        require(stock < 3, "Invalid stock");
        return portfolio[stock];
    }

    // Required Overrides
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}