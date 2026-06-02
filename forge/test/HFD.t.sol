// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HedgeFundDAO, Proposal, IPriceOracle} from "../src/HFD.sol";

// Mock Price Oracle for testing
contract MockPriceOracle is IPriceOracle {
    mapping(uint8 => uint256) public prices;

    constructor() {
        prices[0] = 1 ether;  // SP500
        prices[1] = 0.5 ether; // Wheat
        prices[2] = 0.1 ether; // Apple
    }

    function getPrice(uint8 stock) external view returns (uint256) {
        return prices[stock];
    }

    function setPrice(uint8 stock, uint256 price) external {
        prices[stock] = price;
    }
}

contract HedgeFundDAOTest is Test {
    HedgeFundDAO public hfdao;
    MockPriceOracle public oracle;
    address user1 = address(0x1);
    address user2 = address(0x2);
    address user3 = address(0x3);

    function setUp() public {
        hfdao = new HedgeFundDAO();
        oracle = new MockPriceOracle();
        hfdao.setPriceOracle(address(oracle));
        
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
    }

    // ============ Buy/Retrieve Shares Tests ============

    function test_BuyShares() public {
        vm.startPrank(user1);
        hfdao.buyShares{value: 2 ether}();
        
        assertEq(hfdao.balanceOf(user1), 2 ether); 
        assertEq(address(hfdao).balance, 2 ether);
        
        vm.stopPrank();
    }

    function test_BuySharesMultipleTimes() public {
        vm.startPrank(user1);
        hfdao.buyShares{value: 5 ether}();
        hfdao.buyShares{value: 3 ether}();
        
        assertEq(hfdao.balanceOf(user1), 8 ether);
        assertEq(address(hfdao).balance, 8 ether); // 8 tokens
        
        vm.stopPrank();
    }

    function test_BuySharesZeroEth() public {
        vm.startPrank(user1);
        vm.expectRevert("Need to send ETH");
        hfdao.buyShares{value: 0}();
        vm.stopPrank();
    }

    function test_RetrieveEth() public {
        vm.startPrank(user1);
        hfdao.buyShares{value: 5 ether}();
        
        uint256 ethBefore = user1.balance;
        hfdao.retrieveEth(3 ether);
        
        assertEq(hfdao.balanceOf(user1), 2 ether);
        assertEq(user1.balance, ethBefore + 3 ether);
        assertEq(address(hfdao).balance, 2 ether);
        
        vm.stopPrank();
    }

    function test_RetrieveEthInsufficientBalance() public {
        vm.startPrank(user1);
        hfdao.buyShares{value: 5 ether}();
        
        vm.expectRevert("Not enough tokens");
        hfdao.retrieveEth(10 ether);
        
        vm.stopPrank();
    }

    function test_RetrieveAllEth() public {
        vm.startPrank(user1);
        hfdao.buyShares{value: 10 ether}();
        
        uint256 ethBefore = user1.balance;
        hfdao.retrieveEth(10 ether);
        
        assertEq(hfdao.balanceOf(user1), 0);
        assertEq(user1.balance, ethBefore + 10 ether);
        
        vm.stopPrank();
    }

    // ============ Price Oracle Tests ============

    function test_SetPriceOracle() public {
        MockPriceOracle newOracle = new MockPriceOracle();
        hfdao.setPriceOracle(address(newOracle));
        
        assertEq(address(hfdao.priceOracle()), address(newOracle));
    }

    function test_SetPriceOracleInvalid() public {
        vm.expectRevert("Invalid oracle address");
        hfdao.setPriceOracle(address(0));
    }

    // ============ Proposal Creation Tests ============

    function test_CreateBuyProposal_Basic() public {
        vm.prank(user1);
        hfdao.buyShares{value: 2 ether}();

        vm.prank(user1);
        hfdao.createBuyProposal(0, 5 ether); // Buy SP500 with 5 ETH

        (
            uint256 id,
            uint8 toBuy,
            uint256 buyAmount,
            uint8 toSell,
            uint256 sellAmount,
            uint256 yesVotes,
            uint256 noVotes,
            uint256 snapshotBlock,
            uint256 endTime,
            bool executed
        ) = hfdao.proposals(0);

        assertEq(id, 0);
        assertEq(toBuy, 0);
        assertEq(buyAmount, 5 ether);
        assertEq(toSell, 255); // 255 = none
        assertEq(sellAmount, 0);
        assertEq(yesVotes, 0);
        assertEq(noVotes, 0);
        assertEq(snapshotBlock, block.number);
        assertEq(endTime, block.timestamp + 3 minutes);
        assertEq(executed, false);
    }

    function test_CreateBuyProposal_InvalidStock() public {
        vm.startPrank(user1);
        hfdao.buyShares{value: 2 ether}();
        
        vm.expectRevert("Invalid stock to buy");
        hfdao.createBuyProposal(3, 5 ether); // Invalid stock (>= 3)
        
        vm.stopPrank();
    }

    function test_CreateBuyProposal_ZeroBuyAmount() public {
        vm.startPrank(user1);
        hfdao.buyShares{value: 2 ether}();
        
        vm.expectRevert("Buy amount must be > 0");
        hfdao.createBuyProposal(0, 0);
        
        vm.stopPrank();
    }

    function test_CreateSellProposal_Basic() public {
        // First, execute a buy proposal to have stocks
        vm.startPrank(user1);
        hfdao.buyShares{value: 10 ether}();
        hfdao.delegate(user1);
        hfdao.createBuyProposal(0, 5 ether);
        vm.stopPrank();

        vm.roll(block.number + 1);

        vm.prank(user1);
        hfdao.vote(0, 1); // Vote yes

        vm.warp(block.timestamp + 4 minutes);
        vm.prank(user1);
        hfdao.executeProposal(0);

        // Now create a sell proposal
        vm.prank(user1);
        hfdao.createSellProposal(0, 1 ether);

        (
            uint256 id,
            uint8 toBuy,
            uint256 buyAmount,
            uint8 toSell,
            uint256 sellAmount,
            ,
            ,
            ,
            ,
            bool executed
        ) = hfdao.proposals(1);

        assertEq(id, 1);
        assertEq(toBuy, 255); // 255 = none
        assertEq(buyAmount, 0);
        assertEq(toSell, 0);
        assertEq(sellAmount, 1 ether);
        assertEq(executed, false);
    }

    function test_CreateSellProposal_InvalidStock() public {
        vm.startPrank(user1);
        hfdao.buyShares{value: 2 ether}();
        
        vm.expectRevert("Invalid stock to sell");
        hfdao.createSellProposal(3, 5 ether); // Invalid stock
        
        vm.stopPrank();
    }

    function test_CreateSellProposal_ZeroAmount() public {
        vm.startPrank(user1);
        hfdao.buyShares{value: 2 ether}();
        
        vm.expectRevert("Sell amount must be > 0");
        hfdao.createSellProposal(0, 0);
        
        vm.stopPrank();
    }

    function test_CreateSellProposal_InsufficientStock() public {
        // portfolio[0] remains 0
        vm.startPrank(user1);
        hfdao.buyShares{value: 2 ether}();
        
        vm.expectRevert("Not enough stock to sell");
        hfdao.createSellProposal(0, 10); // Try to sell 10 SP500 but have 0
        
        vm.stopPrank();
    }

    function test_NoTokensToCreateProposal() public {
        vm.prank(user1);
        vm.expectRevert("Must hold at least 1 DAO token to create proposals");
        hfdao.createBuyProposal(0, 5 ether);
    }

    // ============ Voting Tests ============

    function test_Voting_FixedProposal() public {
        // 1. User1 deposits 10 ETH and activates voting power via delegation
        vm.startPrank(user1);
        hfdao.buyShares{value: 10 ether}();
        hfdao.delegate(user1); 
        
        // 2. Create the proposal with proper parameters
        hfdao.createBuyProposal(0, 5 ether); // Buy SP500 with 5 ETH
        vm.stopPrank();

        // 3. Move forward one block so OpenZeppelin checkpoints update
        vm.roll(block.number + 1);

        // 4. User1 withdraws all ETH AFTER snapshot
        vm.prank(user1);
        hfdao.retrieveEth(10 ether);

        // 5. User1 attempts to vote. It should STILL use their 10 ETH weight!
        vm.prank(user1);
        hfdao.vote(0, 1); // 1 = Vote Yes

        // 6. Extract proposal to check vote tally
        (
            ,
            ,
            ,
            ,
            ,
            uint256 yesVotes,
            uint256 noVotes,
            ,
            ,
        ) = hfdao.proposals(0);

        // Assert that the 10 ETH weight counted, despite having 0 balance now
        assertEq(yesVotes, 10 ether);
        assertEq(noVotes, 0);
    }

    function test_Voting_MultipleUsers() public {
        // Setup
        vm.startPrank(user1);
        hfdao.buyShares{value: 10 ether}();
        hfdao.delegate(user1);
        vm.stopPrank();

        vm.startPrank(user2);
        hfdao.buyShares{value: 5 ether}();
        hfdao.delegate(user2);
        vm.stopPrank();

        vm.startPrank(user3);
        hfdao.buyShares{value: 3 ether}();
        hfdao.delegate(user3);
        vm.stopPrank();

        // Create proposal
        vm.prank(user1);
        hfdao.createBuyProposal(0, 5 ether);

        // Move forward one block
        vm.roll(block.number + 1);

        // User1 votes Yes
        vm.prank(user1);
        hfdao.vote(0, 1);

        // User2 votes Yes
        vm.prank(user2);
        hfdao.vote(0, 1);

        // User3 votes No
        vm.prank(user3);
        hfdao.vote(0, 2);

        (
            ,
            ,
            ,
            ,
            ,
            uint256 yesVotes,
            uint256 noVotes,
            ,
            ,
        ) = hfdao.proposals(0);

        assertEq(yesVotes, 15 ether); // 10 + 5
        assertEq(noVotes, 3 ether);   // 3
    }

    function test_Voting_ChangeVote() public {
        vm.startPrank(user1);
        hfdao.buyShares{value: 10 ether}();
        hfdao.delegate(user1);
        hfdao.createBuyProposal(0, 5 ether);
        vm.stopPrank();

        vm.roll(block.number + 1);

        // First vote - Yes
        vm.prank(user1);
        hfdao.vote(0, 1);

        (
            ,
            ,
            ,
            ,
            ,
            uint256 yesVotes1,
            uint256 noVotes1,
            ,
            ,
        ) = hfdao.proposals(0);

        assertEq(yesVotes1, 10 ether);
        assertEq(noVotes1, 0);

        // Change vote to No
        vm.prank(user1);
        hfdao.vote(0, 2);

        (
            ,
            ,
            ,
            ,
            ,
            uint256 yesVotes2,
            uint256 noVotes2,
            ,
            ,
        ) = hfdao.proposals(0);

        assertEq(yesVotes2, 0);
        assertEq(noVotes2, 10 ether);
    }

    function test_Voting_SameVoteTwice() public {
        vm.startPrank(user1);
        hfdao.buyShares{value: 10 ether}();
        hfdao.delegate(user1);
        hfdao.createBuyProposal(0, 5 ether);
        vm.stopPrank();

        vm.roll(block.number + 1);

        vm.prank(user1);
        hfdao.vote(0, 1);

        // Try to vote the same way again
        vm.prank(user1);
        vm.expectRevert("Already voted this way");
        hfdao.vote(0, 1);
    }

    function test_Voting_NoVotingPower() public {
        vm.startPrank(user1);
        hfdao.buyShares{value: 10 ether}();
        // Did NOT delegate
        hfdao.createBuyProposal(0, 5 ether);
        vm.stopPrank();

        vm.roll(block.number + 1);

        vm.prank(user2); // user2 has no tokens
        vm.expectRevert("No voting power at snapshot");
        hfdao.vote(0, 1);
    }

    function test_Voting_InvalidProposal() public {
        vm.prank(user1);
        vm.expectRevert("Proposal does not exist");
        hfdao.vote(999, 1);
    }

    function test_Voting_InvalidChoice() public {
        vm.startPrank(user1);
        hfdao.buyShares{value: 10 ether}();
        hfdao.delegate(user1);
        hfdao.createBuyProposal(0, 5 ether);
        vm.stopPrank();

        vm.roll(block.number + 1);

        vm.prank(user1);
        vm.expectRevert("1=Yes, 2=No");
        hfdao.vote(0, 3);
    }

    function test_Voting_AfterDeadline() public {
        vm.startPrank(user1);
        hfdao.buyShares{value: 10 ether}();
        hfdao.delegate(user1);
        hfdao.createBuyProposal(0, 5 ether);
        vm.stopPrank();

        vm.roll(block.number + 1);

        // Move time forward past the 3-minute voting period
        vm.warp(block.timestamp + 4 minutes);

        vm.prank(user1);
        vm.expectRevert("Voting has ended");
        hfdao.vote(0, 1);
    }

    function test_Voting_SnapshotBlockNotInPast() public {
        vm.startPrank(user1);
        hfdao.buyShares{value: 10 ether}();
        hfdao.delegate(user1);
        hfdao.createBuyProposal(0, 5 ether);
        // Don't advance block - vote on same block as proposal creation
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert();  // Will fail due to snapshot block check
        hfdao.vote(0, 1);
    }

    // ============ Proposal Execution Tests ============

    function test_ExecuteProposal_Successful() public {
        vm.startPrank(user1);
        hfdao.buyShares{value: 10 ether}();
        hfdao.delegate(user1);
        hfdao.createBuyProposal(0, 5 ether);
        vm.stopPrank();

        vm.roll(block.number + 1);

        vm.prank(user1);
        hfdao.vote(0, 1);

        // Move past voting deadline
        vm.warp(block.timestamp + 4 minutes);

        vm.prank(user2);
        hfdao.executeProposal(0);

        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            bool executed
        ) = hfdao.proposals(0);

        assertEq(executed, true);
    }

    function test_ExecuteProposal_NotPassed() public {
        vm.startPrank(user1);
        hfdao.buyShares{value: 5 ether}();
        hfdao.delegate(user1);
        vm.stopPrank();

        vm.startPrank(user2);
        hfdao.buyShares{value: 10 ether}();
        hfdao.delegate(user2);
        hfdao.createBuyProposal(0, 5 ether);
        vm.stopPrank();

        vm.roll(block.number + 1);

        // user1 votes Yes (5 ether)
        vm.prank(user1);
        hfdao.vote(0, 1);

        // user2 votes No (10 ether) - No votes win
        vm.prank(user2);
        hfdao.vote(0, 2);

        vm.warp(block.timestamp + 4 minutes);

        vm.prank(user3);
        vm.expectRevert("Proposal failed");
        hfdao.executeProposal(0);
    }

    function test_ExecuteProposal_AlreadyExecuted() public {
        vm.startPrank(user1);
        hfdao.buyShares{value: 10 ether}();
        hfdao.delegate(user1);
        hfdao.createBuyProposal(0, 5 ether);
        vm.stopPrank();

        vm.roll(block.number + 1);

        vm.prank(user1);
        hfdao.vote(0, 1);

        vm.warp(block.timestamp + 4 minutes);

        vm.prank(user2);
        hfdao.executeProposal(0);

        vm.prank(user3);
        vm.expectRevert("Already executed");
        hfdao.executeProposal(0);
    }

    function test_ExecuteProposal_VotingNotEnded() public {
        vm.startPrank(user1);
        hfdao.buyShares{value: 10 ether}();
        hfdao.delegate(user1);
        hfdao.createBuyProposal(0, 5 ether);
        vm.stopPrank();

        vm.roll(block.number + 1);

        vm.prank(user1);
        hfdao.vote(0, 1);

        // Try to execute before deadline
        vm.prank(user2);
        vm.expectRevert("Voting active");
        hfdao.executeProposal(0);
    }

    function test_ExecuteProposal_InvalidId() public {
        vm.prank(user1);
        vm.expectRevert("Proposal missing");
        hfdao.executeProposal(999);
    }

    function test_ExecuteBuyProposal_WithOracleExecution() public {
        vm.startPrank(user1);
        hfdao.buyShares{value: 20 ether}();
        hfdao.delegate(user1);
        hfdao.createBuyProposal(0, 5 ether);
        vm.stopPrank();

        vm.roll(block.number + 1);

        vm.prank(user1);
        hfdao.vote(0, 1);

        vm.warp(block.timestamp + 4 minutes);

        uint256 fundsBeforeExecution = hfdao.cashBalance();
        
        vm.prank(user2);
        hfdao.executeProposal(0);

        // Verify funds were spent
        uint256 fundsAfterExecution = hfdao.cashBalance();
        assertLt(fundsAfterExecution, fundsBeforeExecution);
        
        // Verify stock was acquired
        uint256 sp500Holdings = hfdao.getPortfolioStock(0);
        assertGt(sp500Holdings, 0);
    }

    function test_ExecuteSellProposal_WithOracleExecution() public {
        // First execute a buy proposal to have stocks
        vm.startPrank(user1);
        hfdao.buyShares{value: 20 ether}();
        hfdao.delegate(user1);
        hfdao.createBuyProposal(0, 5 ether);
        vm.stopPrank();

        vm.roll(block.number + 1);

        vm.prank(user1);
        hfdao.vote(0, 1);

        vm.warp(block.timestamp + 4 minutes);
        vm.prank(user1);
        hfdao.executeProposal(0);

        // Now create and execute a sell proposal
        uint256 stockToSell = hfdao.getPortfolioStock(0) / 2;
        
        vm.prank(user1);
        hfdao.createSellProposal(0, stockToSell);

        vm.roll(block.number + 1);

        vm.prank(user1);
        hfdao.vote(1, 1);

        vm.warp(block.timestamp + 4 minutes);

        uint256 cashBefore = hfdao.cashBalance();
        vm.prank(user2);
        hfdao.executeProposal(1);
        uint256 cashAfter = hfdao.cashBalance();

        // Verify we gained cash
        assertGt(cashAfter, cashBefore);
        
        // Verify stock decreased
        uint256 remainingStock = hfdao.getPortfolioStock(0);
        assertEq(remainingStock, stockToSell);
    }

    // ============ Portfolio and Value Tests ============

    function test_GetPortfolioValue_Empty() public view {
        uint256 value = hfdao.getPortfolioValue();
        assertEq(value, 0);
    }

    function test_GetPortfolioStock_InvalidStock() public {
        vm.expectRevert("Invalid stock");
        hfdao.getPortfolioStock(3);
    }

    function test_GetFundTotalValue_JustEth() public {
        vm.startPrank(user1);
        hfdao.buyShares{value: 5 ether}();
        vm.stopPrank();

        uint256 totalValue = hfdao.getFundTotalValue();
        assertEq(totalValue, 5 ether);
    }


    function test_GetPortfolioValue_NoOracleSet() public {
        // Create new DAO without oracle
        HedgeFundDAO newDao = new HedgeFundDAO();
        
        uint256 value = newDao.getPortfolioValue();
        assertEq(value, 0);
    }
}
