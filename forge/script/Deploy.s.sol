// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

// Import your contracts (adjust the relative paths to match your src/ or contracts/ folder)
import {ChainlinkPriceOracle} from "../src/oracle_chainlink.sol";
import {TransactionNFT} from "../src/transactionNFT.sol";
import {HedgeFundDAO} from "../src/HFD.sol";
import {InvestmentBroker} from "../src/broker.sol";

contract DeployScript is Script {
    // Hardcoded Sepolia Chainlink Price Feed Addresses
    address constant SEPOLIA_BTC_FEED = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
    address constant SEPOLIA_LINK_FEED = 0xc59E3633BAAC79493d908e63626716e204A45EdF;
    address constant SEPOLIA_ETH_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    function run() external {
        // Fetch the private key from the .env file
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("starting deployment from account:", deployer);
        console.log("account balance:", deployer.balance);

        // Broadcast block tells Forge to sign and submit these transactions to the blockchain
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy ChainlinkPriceOracle
        console.log("\nDeploying ChainlinkPriceOracle...");
        ChainlinkPriceOracle oracle = new ChainlinkPriceOracle(
            SEPOLIA_BTC_FEED,
            SEPOLIA_LINK_FEED,
            SEPOLIA_ETH_FEED
        );
        console.log("ChainlinkPriceOracle deployed to:", address(oracle));

        // 2. Deploy TransactionNFT
        console.log("\n2 Deploying TransactionNFT...");
        TransactionNFT nft = new TransactionNFT();
        console.log("TransactionNFT deployed to:", address(nft));

        // 3. Deploy HedgeFundDAO
        console.log("\nDeploying HedgeFundDAO...");
        HedgeFundDAO dao = new HedgeFundDAO();
        console.log("HedgeFundDAO deployed to:", address(dao));

        // 4. Deploy InvestmentBroker
        console.log("\nDeploying InvestmentBroker...");
        InvestmentBroker broker = new InvestmentBroker(
            address(dao),
            address(nft),
            address(oracle)
        );
        console.log("InvestmentBroker deployed to:", address(broker));

        // 5. Resolving Cross-Contract References
        console.log("\nResolving Cross-Contract References...");

        // A. Configure TransactionNFT
        console.log("-> Linking DAO and Broker contracts inside TransactionNFT...");
        nft.setDAO(address(dao));
        nft.setBroker(address(broker));

        // B. Configure HedgeFundDAO
        console.log("-> Setting Broker, NFT, and Oracle addresses inside HedgeFundDAO...");
        dao.setBroker(address(broker));
        dao.setNFTContract(address(nft));
        dao.setPriceOracle(address(oracle));

        vm.stopBroadcast();

        console.log("\nVerification and setup completed successfully!");

        console.log("\nDEPLOYMENT SUMMARY:");
        console.log("=================================================");
        console.log("NEXT_PUBLIC_DAO_CONTRACT_ADDRESS=\"%s\"", address(dao));
        console.log("NEXT_PUBLIC_BROKER_CONTRACT_ADDRESS=\"%s\"", address(broker));
        console.log("NEXT_PUBLIC_NFT_CONTRACT_ADDRESS=\"%s\"", address(nft));
        console.log("ORACLE_CONTRACT_ADDRESS=\"%s\"", address(oracle));
        console.log("=================================================");
        console.log("Copy the variables above directly into your frontend .env file.");

        // Optional log checks (assumes getPrice method exists)
        console.log("BTC price:", oracle.getPrice(0));
        console.log("LINK price:", oracle.getPrice(1));
        console.log("ETH price:", oracle.getPrice(2));
    }
}