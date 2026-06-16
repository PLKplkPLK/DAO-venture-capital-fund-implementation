// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {InvestmentBroker, IPriceOracle} from "../src/broker.sol";
import {HedgeFundDAO, Proposal} from "../src/HFD.sol";


contract MockPriceOracle is IPriceOracle {
    mapping(uint8 => uint256) public prices;

    constructor() {
        prices[0] = 1 ether;  // BTC
        prices[1] = 0.5 ether; // LINK
        prices[2] = 0.1 ether; // ETH
    }

    function getPrice(uint8 stock) external view returns (uint256) {
        return prices[stock];
    }

    function setPrice(uint8 stock, uint256 price) external {
        prices[stock] = price;
    }
}

contract MockTransactionNFT {
    uint256 public nextTokenId = 1;
    mapping(uint256 => address) public tokenBrokers;

    function mintTransaction(uint256, uint8, bool, uint256, uint256, address broker) external returns (uint256) {
        uint256 id = nextTokenId++;
        tokenBrokers[id] = broker;
        return id;
    }
    
    function getTransactionBroker(uint256 tokenId) external view returns (address) {
        return tokenBrokers[tokenId];
    }
}

contract InvestmentBrokerTest is Test {
    InvestmentBroker public brokerContract;
    HedgeFundDAO public dao;
    MockPriceOracle public oracleMock;
    MockTransactionNFT public nftMock;

    address public owner = address(0x1);
    address public broker = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);

    uint8 public constant STOCK_BTC = 0;
    uint256 public constant MOCK_PRICE = 0.05 ether;

    event OrderExecuted(uint256 indexed proposalId, uint256 nftTokenId, uint256 price);

    function setUp() public {
        vm.startPrank(owner);
        
        dao = new HedgeFundDAO();
        oracleMock = new MockPriceOracle();
        nftMock = new MockTransactionNFT();

        brokerContract = new InvestmentBroker(
            address(dao),
            address(nftMock),
            address(oracleMock)
        );

        dao.setBroker(address(brokerContract));
        dao.setNFTContract(address(nftMock));
        dao.setPriceOracle(address(oracleMock));

        brokerContract.updateBrokerAddress(broker);
        vm.stopPrank();

        vm.deal(user1, 10 ether);
        vm.prank(user1);
        dao.buyShares{value: 10 ether}(); 

        vm.deal(user2, 5 ether);
        vm.prank(user2);
        dao.buyShares{value: 5 ether}(); 

        oracleMock.setPrice(STOCK_BTC, MOCK_PRICE);

        vm.deal(broker, 100 ether);
        vm.prank(broker);
        dao.depositBroker{value: 100 ether}();
    }


    // ============ Modifiers Tests ============

    function test_UpdateBrokerAddress_OnlyOwner() public {
        vm.prank(owner);
        brokerContract.updateBrokerAddress(user1);
        assertEq(brokerContract.brokerAddress(), user1);
    }

    function test_UpdateBrokerAddress_NonOwnerRevert() public {
        vm.prank(user1);
        vm.expectRevert("Not owner");
        brokerContract.updateBrokerAddress(user1);
    }

    function test_ExecuteOrder_NonBrokerRevert() public {
        vm.prank(user1);
        vm.expectRevert("Caller is not the authorized broker");
        brokerContract.executeOrder(0, STOCK_BTC, true);
    }


    // ============ Order Execution Tests ============

    function test_ExecuteOrder_InsufficientBrokerDepositRevert() public {
        vm.prank(owner);
        brokerContract.updateBrokerAddress(user1);

        vm.prank(user1);
        vm.expectRevert("Broker deposit insufficient");
        brokerContract.executeOrder(0, STOCK_BTC, true);
    }

    function test_ExecuteOrder_AlreadyExecutedRevert() public {
        uint256 buyAmount = 2 ether;

        vm.prank(user1);
        dao.createBuyProposal(STOCK_BTC, buyAmount);
        uint256 proposalId = 0;

        vm.roll(block.number + 1);
        vm.prank(user1);
        dao.vote(proposalId, 1); 

        vm.warp(block.timestamp + 1 minutes + 1 seconds);

        vm.prank(broker);
        brokerContract.executeOrder(proposalId, STOCK_BTC, true);

        vm.prank(broker);
        vm.expectRevert("Order already executed for this proposal");
        brokerContract.executeOrder(proposalId, STOCK_BTC, true);
    }

    function test_ExecuteOrder_VotingStillActiveRevert() public {
        vm.prank(user1);
        dao.createBuyProposal(STOCK_BTC, 2 ether); 

        vm.prank(broker);
        vm.expectRevert("Voting is still active in DAO");
        brokerContract.executeOrder(0, STOCK_BTC, true);
    }

    function test_ExecuteOrder_ProposalFailedVotingRevert() public {
        vm.prank(user1);
        dao.createBuyProposal(STOCK_BTC, 2 ether);
        
        vm.roll(block.number + 1);
        vm.prank(user1);
        dao.vote(0, 2); 

        vm.warp(block.timestamp + 1 minutes + 1 seconds);

        vm.prank(broker);
        vm.expectRevert("Proposal failed voting requirements");
        brokerContract.executeOrder(0, STOCK_BTC, true);
    }

    function test_ExecuteOrder_InvalidStockIdRevert() public {
        vm.prank(user1);
        dao.createBuyProposal(STOCK_BTC, 2 ether);
        
        vm.roll(block.number + 1);
        vm.prank(user1);
        dao.vote(0, 1);

        vm.warp(block.timestamp + 1 minutes + 1 seconds);

        vm.prank(broker);
        vm.expectRevert("Invalid stock ID");
        brokerContract.executeOrder(0, 4, true); 
    }

    function test_ExecuteOrder_StockMismatchRevert() public {
        vm.prank(user1);
        dao.createBuyProposal(1, 2 ether); 
        
        vm.roll(block.number + 1);
        vm.prank(user1);
        dao.vote(0, 1);

        vm.warp(block.timestamp + 1 minutes + 1 seconds);

        vm.prank(broker);
        vm.expectRevert("Stock does not match the buy proposal");
        brokerContract.executeOrder(0, STOCK_BTC, true); 
    }

    function test_ExecuteOrder_BuySuccess() public {
        uint256 buyAmount = 2 ether;
        uint256 expectedStockAmount = 40 ether;

        vm.prank(user1);
        dao.createBuyProposal(STOCK_BTC, buyAmount);
        uint256 proposalId = 0;

        vm.roll(block.number + 1);
        vm.prank(user1);
        dao.vote(proposalId, 1); 

        vm.warp(block.timestamp + 1 minutes + 1 seconds);

        vm.expectEmit(true, false, false, true);
        emit OrderExecuted(proposalId, 1, MOCK_PRICE);

        vm.prank(broker);
        uint256 tokenId = brokerContract.executeOrder(proposalId, STOCK_BTC, true);

        assertEq(tokenId, 1);
        assertEq(dao.getPortfolioStock(STOCK_BTC), expectedStockAmount);
    }

    function test_ExecuteOrder_SellSuccess() public {
        test_ExecuteOrder_BuySuccess();

        uint256 sellAmount = 10 ether; 
        uint256 expectedEthGained = 0.5 ether;
        uint256 cashBefore = dao.cashBalance();

        vm.prank(user1);
        dao.createSellProposal(STOCK_BTC, sellAmount);
        uint256 proposalId = 1; 

        vm.roll(block.number + 1);
        vm.prank(user1);
        dao.vote(proposalId, 1);

        vm.warp(block.timestamp + 1 minutes + 1 seconds);

        vm.prank(broker);
        brokerContract.executeOrder(proposalId, STOCK_BTC, false);

        assertEq(dao.cashBalance(), cashBefore + expectedEthGained);
    }

}