// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPriceOracle {
    function getPrice(uint8 stock) external view returns (uint256);
}

enum Asset {
    BTC,
    LINK,
    ETH
}

interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (
            uint80,
            int256,
            uint256,
            uint256,
            uint80
        );
}

contract ChainlinkPriceOracle is IPriceOracle {

    AggregatorV3Interface public btcFeed;
    AggregatorV3Interface public linkFeed;
    AggregatorV3Interface public ethFeed;

    constructor(
        address _btc,
        address _link,
        address _eth
    ) {
        btcFeed = AggregatorV3Interface(_btc);
        linkFeed = AggregatorV3Interface(_link);
        ethFeed = AggregatorV3Interface(_eth);
    }

    function getPrice(
        uint8 stock
    )
        external
        view
        override
        returns (uint256)
    {
        if (stock == 0) {
            return _readFeed(btcFeed);
        }

        if (stock == 1) {
            return _readFeed(linkFeed);
        }

        if (stock == 2) {
            return _readFeed(ethFeed);
        }

        revert("Invalid asset");
    }

    function _readFeed(
        AggregatorV3Interface feed
    )
        internal
        view
        returns (uint256)
    {
        (, int256 answer,,,) =
            feed.latestRoundData();

        // Guard against a non-positive answer: casting a negative int256 to
        // uint256 would wrap to an enormous value and corrupt valuations.
        require(answer > 0, "Invalid feed price");

        // Chainlink returns 8 decimals
        // ERC20 uses 18 decimals
        return uint256(answer) * 1e10;
    }
}
