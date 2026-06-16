// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TransactionNFT} from "../src/transactionNFT.sol";

contract TransactionNFTTest is Test {
    TransactionNFT public nft;

    address public owner = address(0x1);
    address public daoContract = address(0x2);
    address public brokerContract = address(0x3);
    address public maliciousUser = address(0x4);
    address public brokerWallet = address(0x5);

    function setUp() public {
        vm.prank(owner);
        nft = new TransactionNFT();

        vm.startPrank(owner);
        nft.setDAO(daoContract);
        nft.setBroker(brokerContract);
        vm.stopPrank();
    }

    // ============ Minting Tests ============

    function test_MintTransaction_OnlyBrokerRevert() public {
        vm.prank(maliciousUser);
        vm.expectRevert("Only the registered Broker contract can call this");
        nft.mintTransaction(1, 0, true, 1 ether, 100, brokerWallet);
    }

    function test_MintTransaction_InvalidParametersRevert() public {
        vm.startPrank(brokerContract);

        vm.expectRevert("Invalid price");
        nft.mintTransaction(1, 0, true, 1 ether, 0, brokerWallet);

        vm.expectRevert("Invalid amount");
        nft.mintTransaction(1, 0, true, 0, 100, brokerWallet);

        vm.expectRevert("Invalid broker address");
        nft.mintTransaction(1, 0, true, 1 ether, 100, address(0));

        vm.stopPrank();
    }

    function test_MintTransaction_Success() public {
        uint256 proposalId = 10;
        uint8 stockId = 0;
        bool isBuy = true;
        uint256 amount = 2 ether;
        uint256 price = 50000 ether;

        vm.prank(brokerContract);
        uint256 tokenId = nft.mintTransaction(proposalId, stockId, isBuy, amount, price, brokerWallet);

        assertEq(tokenId, 0);
        assertEq(nft.nextTransactionId(), 1);

       assertEq(nft.ownerOf(tokenId), daoContract);
        assertEq(nft.balanceOf(daoContract), 1);

        (
            uint256 resProposalId,
            uint8 resStock,
            TransactionNFT.TransactionType resType,
            uint256 resAmount,
            uint256 resPrice,
            address resBroker,
            uint256 resTimestamp
        ) = nft.transactions(tokenId);

        assertEq(resProposalId, proposalId);
        assertEq(resStock, stockId);
        assertTrue(resType == TransactionNFT.TransactionType.BUY);
        assertEq(resAmount, amount);
        assertEq(resPrice, price);
        assertEq(resBroker, brokerWallet);
        assertEq(resTimestamp, block.timestamp);
    }

    // ============ Getters Tests ============
    
    function test_GetTransaction_NonexistentTokenRevert() public {
        vm.expectRevert("Nonexistent token");
        nft.getTransaction(999);
    }

    function test_GetTransactionBroker_Success() public {
        vm.prank(brokerContract);
        uint256 tokenId = nft.mintTransaction(1, 0, true, 1 ether, 100, brokerWallet);

        address foundBroker = nft.getTransactionBroker(tokenId);
        assertEq(foundBroker, brokerWallet);
    }

    function test_GetTransactionBroker_NonexistentTokenRevert() public {
        vm.expectRevert("Nonexistent token");
        nft.getTransactionBroker(999);
    }

    function test_GetBrokerTransactions_Tracking() public {
        vm.startPrank(brokerContract);
        nft.mintTransaction(1, 0, true, 1 ether, 100, brokerWallet);
        nft.mintTransaction(2, 1, false, 2 ether, 200, brokerWallet);
        vm.stopPrank();

        uint256[] memory txs = nft.getBrokerTransactions(brokerWallet);
        
        assertEq(txs.length, 2);
        assertEq(txs[0], 0);
        assertEq(txs[1], 1);
    }

}