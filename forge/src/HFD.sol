// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

enum Stock {
    SP500,
    Wheat,
    Apple
}

interface IPriceOracle {
    function getPrice(uint8 stock) external view returns (uint256);
}

struct Proposal {
    uint256 id;
    uint8 toBuy;           // Which stock to buy
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
    constructor() ERC20("HF Token", "HF") ERC20Permit("HF Token") {}

    uint256 public nextProposalId;
    mapping(uint256 => Proposal) public proposals;
    // 0 = None, 1 = Yes, 2 = No
    mapping(uint256 => mapping(address => uint8)) public userVotes;
    
    // Portfolio: tracks amount of each stock held by the fund
    mapping(uint8 => uint256) public portfolio;
    
    // Price oracle address (can be set by owner/governance)
    IPriceOracle public priceOracle;

    event ProposalCreated(uint256 indexed proposalId, uint8 toBuy, uint256 buyAmount, uint8 toSell, uint256 sellAmount);
    event Voted(uint256 indexed proposalId, address indexed voter, uint8 choice, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event PriceOracleUpdated(address newOracle);

    function buyShares() external payable {
        require(msg.value > 0, "Need to send $ bro");
        _mint(msg.sender, msg.value);
    }

    function retrieveEth(uint256 amount) external payable {
        require(amount <= balanceOf(msg.sender), "Not enough $ in HF");
        _burn(msg.sender, amount);
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed, unlucky");
    }

    function setPriceOracle(address _oracle) external {
        require(_oracle != address(0), "Invalid oracle address");
        priceOracle = IPriceOracle(_oracle);
        emit PriceOracleUpdated(_oracle);
    }

    function createProposal(
        uint8 toBuy,
        uint256 buyAmount,
        uint8 toSell,
        uint256 sellAmount
    ) external {
        require(toBuy < 3, "Invalid stock to buy");
        require(buyAmount > 0, "Buy amount must be > 0");
        if (toSell < 3) {
            require(sellAmount > 0, "Sell amount must be > 0 if selling");
            require(sellAmount <= portfolio[toSell], "Not enough stock to sell");
        }

        proposals[nextProposalId] = Proposal({
            id: nextProposalId,
            toBuy: toBuy,
            buyAmount: buyAmount,
            toSell: toSell,
            sellAmount: sellAmount,
            yesVotes: 0,
            noVotes: 0,
            snapshotBlock: block.number,
            endTime: block.timestamp + 3 days,
            executed: false
        });

        emit ProposalCreated(nextProposalId, toBuy, buyAmount, toSell, sellAmount);
        nextProposalId++;
    }

    function vote(uint256 proposalId, uint8 choice) external {
        require(proposalId < nextProposalId, "Proposal does not exist");
        require(choice == 1 || choice == 2, "Invalid choice: 1=Yes, 2=No");
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp < proposal.endTime, "Voting has ended");
        require(proposal.snapshotBlock < block.number, "Vote snapshot is not in the past");

        // Fetch historical voting power at the snapshot block
        uint256 weight = getPastVotes(msg.sender, proposal.snapshotBlock);
        require(weight > 0, "No voting power at snapshot");

        uint8 previousChoice = userVotes[proposalId][msg.sender];
        require(previousChoice != choice, "Already voted this way");

        if (previousChoice == 1) {
            proposal.yesVotes -= weight;
        } else if (previousChoice == 2) {
            proposal.noVotes -= weight;
        }

        if (choice == 1) {
            proposal.yesVotes += weight;
        } else if (choice == 2) {
            proposal.noVotes += weight;
        }

        userVotes[proposalId][msg.sender] = choice;
        emit Voted(proposalId, msg.sender, choice, weight);
    }

    // Get total value of the fund: ETH balance + portfolio value
    function getFundTotalValue() external view returns (uint256) {
        uint256 ethBalance = address(this).balance;
        uint256 portfolioValue = getPortfolioValue();
        return ethBalance + portfolioValue;
    }

    // Calculate portfolio value in ETH based on oracle prices
    function getPortfolioValue() public view returns (uint256) {
        if (address(priceOracle) == address(0)) {
            return 0; // Oracle not set yet
        }

        uint256 value = 0;
        for (uint8 i = 0; i < 3; i++) {
            uint256 stockAmount = portfolio[i];
            if (stockAmount > 0) {
                uint256 price = priceOracle.getPrice(i);
                value += (stockAmount * price) / 1e18; // Assuming prices are in wei
            }
        }
        return value;
    }

    // Get amount of specific stock in portfolio
    function getPortfolioStock(uint8 stock) external view returns (uint256) {
        require(stock < 3, "Invalid stock");
        return portfolio[stock];
    }

    // PLACEHOLDER: Execute proposal trades (to be implemented with actual oracle/broker)
    function executeProposal(uint256 proposalId) external {
        require(proposalId < nextProposalId, "Proposal does not exist");
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Already executed");
        require(block.timestamp >= proposal.endTime, "Voting not ended");
        require(proposal.yesVotes > proposal.noVotes, "Proposal did not pass");

        // PLACEHOLDER: Actual trade execution would happen here
        // For now, just mark as executed
        // In production, this would:
        // 1. Call oracle/broker API to execute trades
        // 2. Update portfolio mapping
        // 3. Handle ETH transfers
        proposal.executed = true;
        emit ProposalExecuted(proposalId);
    }

    function _update(address from, address to, uint256 value) 
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
