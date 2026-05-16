// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {HedgeFundDAO} from "../src/HFD.sol";

contract HedgeFundDAOTest is Test {
    HedgeFundDAO public hfdao;
    address public user = address(0x1);

    function setUp() public {
        hfdao = new HedgeFundDAO();
        vm.deal(user, 10 ether);
    }

    function testBuyShares() public {
        vm.prank(user);  // subsequent calls will be done by this user

        hfdao.buyShares{value: 2 ether}();
        assertEq(hfdao.balanceOf(user), 2 ether); // TODO ether czy tokens
        assertEq(address(hfdao).balance, 2 ether);
    }

    function testVote() public {
        // TEST
    }
}
