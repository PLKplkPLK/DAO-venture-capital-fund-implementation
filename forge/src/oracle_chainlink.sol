// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPriceOracle {
    function getPrice(uint8 stock) external view returns (uint256);
}

enum Asset {
    BTC,
    LINK,
    SOL
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
    AggregatorV3Interface public solFeed;

    constructor(
        address _btc,
        address _link,
        address _sol
    ) {
        btcFeed = AggregatorV3Interface(_btc);
        linkFeed = AggregatorV3Interface(_link);
        solFeed = AggregatorV3Interface(_sol);
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
            return _readFeed(solFeed);
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

        // Chainlink returns 8 decimals
        // ERC20 uses 18 decimals
        return uint256(answer) * 1e10;
    }
}
