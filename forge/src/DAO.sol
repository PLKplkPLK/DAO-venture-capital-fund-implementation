// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

enum Stock {
    SP500,
    Oil,
    Apple
}

struct Proposal {
    uint256 id;
    Stock stock;
    uint256 yesVotes;
    uint256 noVotes;
    uint256 endTime;
    bool executed;
}

contract HedgeFundDAO {
    mapping(address => uint256) public shares;
    uint256 public totalShares;
    mapping(uint256 => Proposal) public proposals;

    function deposit() external payable {
        // TODO user deposits ETH -> more totalShares
    }

    function createProposal(Stock stock) external {
        // TODO Anyone can propose what to buy?
    }

    function vote(uint256 proposalId, bool support) external {
        // TODO Vote for proposal
    }

    function executeProposal(uint256 proposalId) external {
        // TODO If endTime and more yes votes
    }
}
