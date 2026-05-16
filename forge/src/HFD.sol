// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

enum Stock {
    SP500,
    Wheat,
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

contract HedgeFundDAO is ERC20 {
    constructor() ERC20("HF Token", "HF") {}

    mapping(address => uint256) public shares;
    uint256 public totalShares;
    mapping(uint256 => Proposal) public proposals;

    function buyShares() external payable {
        require(msg.value > 0, "Need to send $ bro");
        _mint(msg.sender, msg.value);
        // shares[msg.sender] += msg.value;
        // totalShares += msg.value;
    }

    function retrieveShares(uint256 amount) external payable {
        require(amount <= balanceOf(msg.sender), "Not enough $ in HF");

        _burn(msg.sender, amount);
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed, unlucky");

        // require(amount <= shares[msg.sender], "Not enough $ in hedgefund");
        // shares[msg.sender] -= amount;
        // payable(address(msg.sender)).call{value: amount}("");
        // totalShares -= amount;
    }

    // view for read-only functions - doesn't use gas
    function checkShares(address user) external view returns (uint256) {
        return shares[user]; // TODO idk
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
