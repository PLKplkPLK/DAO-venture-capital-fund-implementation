// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HedgeFundDAO, Stock} from "../src/HFD.sol";

contract HedgeFundDAOTest is Test {
    HedgeFundDAO public hfdao;
    address user1 = address(0x1);
    address user2 = address(0x2);

    function setUp() public {
        hfdao = new HedgeFundDAO();
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    function test_BuyShares() public {
        vm.startPrank(user1);

        hfdao.buyShares{value: 2 ether}();
        
        // '2 ether' perfectly checks for 2 tokens (2 * 10^18)
        assertEq(hfdao.balanceOf(user1), 2 ether); 
        assertEq(address(hfdao).balance, 2 ether);
        
        vm.stopPrank();
    }

    function test_Voting() public {
        // 1. User1 deposits 10 ETH and activates voting power via delegation
        vm.startPrank(user1);
        hfdao.buyShares{value: 10 ether}();
        hfdao.delegate(user1); 
        
        // 2. Create the proposal 
        hfdao.createProposal(Stock.SP500);
        vm.stopPrank();

        // 3. Move forward one block so OpenZeppelin checkpoints update
        vm.roll(block.number + 1);

        // 4. Exploiter try: User1 withdraws all ETH AFTER snapshot
        vm.prank(user1);
        hfdao.retrieveEth(10 ether);

        // 5. User1 attempts to vote. It should STILL use their 10 ETH weight!
        vm.prank(user1);
        hfdao.vote(0, 1); // 1 = Vote Yes

        // 6. Explicitly extract the yes vote total from the proposal
        (, , uint256 yesVotes, , , , ) = hfdao.proposals(0);

        // Assert that the 10 ETH weight counted, despite having 0 balance now
        assertEq(yesVotes, 10 ether);
    }
}
