// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPriceOracle {
    function getPrice(uint8 stock) external view returns (uint256);
}

contract MockPriceOracle is IPriceOracle {
    // Mock prices with normal distribution
    // Stock 0: BTC - mean: 7500, sd: 75
    // Stock 1: LINK - mean: 25, sd: 0.25
    // Stock 2: SOL - mean: 300, sd: 3
    
    address public owner;

    event PriceUpdated(uint8 indexed stock, uint256 newPrice);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can update prices");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function getPrice(uint8 stock) external view override returns (uint256) {
        require(stock < 3, "Invalid stock ID");
        
        uint256 randomValue = _generateRandomNumber(stock);
        int256 normalizedValue = _boxMullerApproximation(randomValue);
        
        if (stock == 0) {
            return _calculatePrice(7500 * 1e18, 75 * 1e18, normalizedValue);
        } else if (stock == 1) {
            return _calculatePrice(25 * 1e18, 25 * 1e16, normalizedValue);
        } else {
            return _calculatePrice(300 * 1e18, 3 * 1e18, normalizedValue);
        }
    }

    function _generateRandomNumber(uint8 stock) private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.number,
            msg.sender,
            stock
        )));
    }

    function _boxMullerApproximation(uint256 seed) private pure returns (int256) {
        // Simplified Box-Muller approximation to get a normal distribution
        
        uint256 u1 = (seed % 1000000) + 1;
        uint256 u2 = ((seed / 1000000) % 1000000) + 1;
        
        int256 z = int256(u1) - 500000;
        z += int256(u2) - 500000;
        z = z / 2;
        
        return z;
    }

    function _calculatePrice(
        uint256 mean,
        uint256 sd,
        int256 zScore
    ) private pure returns (uint256) {
        int256 price = int256(mean) + (zScore * int256(sd)) / 1e18;
        
        if (price <= 0) {
            price = int256(mean) / 2;
        }
        
        return uint256(price);
    }
}
