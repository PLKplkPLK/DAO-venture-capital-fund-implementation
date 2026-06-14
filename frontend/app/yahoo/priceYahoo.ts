// Fetches real market prices from Yahoo Finance API

export type StockPrice = {
  symbol: string;
  price: number;
  change24h: number;
  timestamp: number;
};

export type PriceHistory = {
  timestamp: number;
  price: number;
}[];

// Yahoo Finance symbols for the stocks
const STOCK_SYMBOLS = ["BTC-USD", "LINK-USD", "ETH-USD"];
const STOCK_LABELS = ["BTC", "LINK", "ETH"];

export async function getStockPrice(stockIndex: number): Promise<StockPrice> {
  try {
    const symbol = STOCK_SYMBOLS[stockIndex];
    const response = await fetch(
      `/api/stock-prices?action=price&symbol=${encodeURIComponent(symbol)}`,
      { cache: "no-store" },
    );

    if (!response.ok) {
      throw new Error(`API error: ${response.status}`);
    }

    const data: StockPrice = await response.json();
    return data;
  } catch (error) {
    console.error(`Error fetching stock price for index ${stockIndex}:`, error);
    return {
      symbol: STOCK_LABELS[stockIndex] || "UNKNOWN",
      price: 0,
      change24h: 0,
      timestamp: Math.floor(Date.now() / 1000),
    };
  }
}

// Fetch price history for charting
export async function getStockPriceHistory(
  stockIndex: number,
  days: number = 30,
): Promise<PriceHistory> {
  try {
    const symbol = STOCK_SYMBOLS[stockIndex];
    const response = await fetch(
      `/api/stock-prices?action=history&symbol=${encodeURIComponent(symbol)}&days=${days}`,
      { cache: "no-store" },
    );

    if (!response.ok) {
      throw new Error(`API error: ${response.status}`);
    }

    const history: PriceHistory = await response.json();
    return history;
  } catch (error) {
    console.error(
      `Error fetching price history for index ${stockIndex}:`,
      error,
    );
    return [];
  }
}

// Get all current prices at once
export async function getAllStockPrices(): Promise<StockPrice[]> {
  return Promise.all([getStockPrice(0), getStockPrice(1), getStockPrice(2)]);
}

// Format price for display
export function formatPrice(price: number, decimals: number = 2): string {
  return price.toFixed(decimals);
}

// Calculate total value in ETH (for portfolio valuation)
export function calculateETHValue(amount: number, priceInUSD: number): number {
  // Assuming 1 ETH = $3000 (you should fetch this from oracle)
  const ETH_TO_USD = 3000;
  const usdValue = amount * priceInUSD;
  return usdValue / ETH_TO_USD;
}
