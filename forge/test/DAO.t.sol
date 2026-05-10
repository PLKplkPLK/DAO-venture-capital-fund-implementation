// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {HedgeFundDAO} from "../src/DAO.sol";

contract DAOTest is Test {
    HedgeFundDAO public dao;

    function setUp() public {
        dao = new HedgeFundDAO();
    }

    function test_vote() public {
        // TEST
    }
}
