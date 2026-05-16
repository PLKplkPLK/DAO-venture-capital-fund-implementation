// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {HedgeFundDAO} from "../src/HFD.sol";

contract HFDAOScript is Script {
    HedgeFundDAO public dao;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        dao = new HedgeFundDAO();

        vm.stopBroadcast();
    }
}
