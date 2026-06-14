import { NextResponse } from "next/server";
import YahooFinance from "yahoo-finance2";

const yahooFinance = new YahooFinance();

// Fetch current quote for a stock symbol
async function fetchStockQuote(symbol: string) {
  try {
    const data = await yahooFinance.quote(symbol);
    return {
      symbol: data.symbol || symbol,
      price: data.regularMarketPrice || 0,
      change24h: data.regularMarketChangePercent || 0,
      timestamp: Math.floor(Date.now() / 1000),
    };
  } catch (error) {
    console.error(`Error fetching quote for ${symbol}:`, error);
    return {
      symbol,
      price: 0,
      change24h: 0,
      timestamp: Math.floor(Date.now() / 1000),
    };
  }
}

// Fetch historical price data for charting
async function fetchStockHistory(
  symbol: string,
  days: number = 30,
): Promise<Array<{ timestamp: number; price: number }>> {
  try {
    const queryOptions = {
      period1: new Date(Date.now() - days * 24 * 60 * 60 * 1000),
      period2: new Date(),
      interval: "1d" as const,
    };

    const result = await yahooFinance.historical(symbol, queryOptions);

    return result.map((item: any) => ({
      timestamp: Math.floor(item.date.getTime() / 1000),
      price: item.close || item.adjClose || 0,
    }));
  } catch (error) {
    console.error(`Error fetching history for ${symbol}:`, error);
    return [];
  }
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const action = searchParams.get("action");
  const symbol = searchParams.get("symbol");
  const days = searchParams.get("days") || "30";

  try {
    if (action === "price" && symbol) {
      const priceData = await fetchStockQuote(symbol);
      return NextResponse.json(priceData);
    }

    if (action === "history" && symbol) {
      const history = await fetchStockHistory(symbol, parseInt(days));
      return NextResponse.json(history);
    }

    if (action === "all") {
      const [btc, link, eth] = await Promise.all([
        fetchStockQuote("BTC-USD"),
        fetchStockQuote("LINK-USD"),
        fetchStockQuote("ETH-USD"),
      ]);
      return NextResponse.json([btc, link, eth]);
    }

    return NextResponse.json(
      { error: "Invalid action or missing parameters" },
      { status: 400 },
    );
  } catch (error) {
    console.error("API error:", error);
    return NextResponse.json(
      { error: "Failed to fetch stock data" },
      { status: 500 },
    );
  }
}
