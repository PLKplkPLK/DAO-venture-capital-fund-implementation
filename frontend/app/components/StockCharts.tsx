"use client";

import { useEffect, useState } from "react";
import {
  getStockPriceHistory,
  getStockPrice,
  StockPrice,
  PriceHistory,
} from "../bc/priceOracle";

const STOCK_LABELS = ["BTC", "LINK", "ETH"];
const COLORS = ["#0b66ff", "#d63333", "#00a854"];

// Simple SVG Line Chart Component
function SimpleLineChart({
  data,
  color,
  height = 150,
}: {
  data: PriceHistory;
  color: string;
  height?: number;
}) {
  if (!data || data.length < 2) {
    return <div style={{ textAlign: "center", color: "#999" }}>No data</div>;
  }

  const prices = data.map((d) => d.price);
  const minPrice = Math.min(...prices);
  const maxPrice = Math.max(...prices);
  const priceRange = maxPrice - minPrice || 1;

  const width = 300;
  const padding = 10;
  const graphWidth = width - padding * 2;
  const graphHeight = height - padding * 2;

  const points = data
    .map((d, i) => {
      const x = padding + (i / (data.length - 1)) * graphWidth;
      const y =
        padding +
        graphHeight -
        ((d.price - minPrice) / priceRange) * graphHeight;
      return `${x},${y}`;
    })
    .join(" ");

  return (
    <svg
      width={width}
      height={height}
      style={{ border: "1px solid #ddd", borderRadius: "4px" }}
    >
      <polyline
        points={points}
        fill="none"
        stroke={color}
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <text
        x={padding}
        y={height - 2}
        fontSize="10"
        fill="#999"
        fontFamily="monospace"
      >
        ${minPrice.toFixed(0)}
      </text>
      <text
        x={width - 50}
        y={height - 2}
        fontSize="10"
        fill="#999"
        fontFamily="monospace"
      >
        ${maxPrice.toFixed(0)}
      </text>
    </svg>
  );
}

export default function StockCharts() {
  const [mounted, setMounted] = useState(false);
  const [prices, setPrices] = useState<StockPrice[]>([]);
  const [history, setHistory] = useState<PriceHistory[]>([[], [], []]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string>("");

  useEffect(() => {
    setMounted(true);
    const fetchData = async () => {
      try {
        setError("");
        const [btc, link, sol] = await Promise.all([
          getStockPrice(0),
          getStockPrice(1),
          getStockPrice(2),
        ]);
        setPrices([btc, link, sol]);

        const [hist0, hist1, hist2] = await Promise.all([
          getStockPriceHistory(0, 30),
          getStockPriceHistory(1, 30),
          getStockPriceHistory(2, 30),
        ]);
        setHistory([hist0, hist1, hist2]);
      } catch (err) {
        console.error("Error fetching prices:", err);
        setError(err instanceof Error ? err.message : "Failed to fetch prices");
      } finally {
        setLoading(false);
      }
    };

    fetchData();
    const interval = setInterval(fetchData, 60000); // Update every minute

    return () => clearInterval(interval);
  }, []);

  if (!mounted) {
    return null;
  }

  if (loading) {
    return (
      <section
        style={{
          padding: "1rem",
          background: "#f9f9f9",
          borderRadius: "8px",
          marginBottom: "2rem",
        }}
      >
        <h2>Market Prices & Charts</h2>
        <div style={{ padding: "1rem", color: "#666" }}>Loading prices...</div>
      </section>
    );
  }

  if (error) {
    return (
      <section
        style={{
          padding: "1rem",
          background: "#f9f9f9",
          borderRadius: "8px",
          marginBottom: "2rem",
        }}
      >
        <h2>Market Prices & Charts</h2>
        <div style={{ padding: "1rem", color: "#d63333" }}>Error: {error}</div>
      </section>
    );
  }

  return (
    <section
      style={{
        padding: "1rem",
        background: "#f9f9f9",
        borderRadius: "8px",
        marginBottom: "2rem",
      }}
    >
      <h2>Market Prices & Charts</h2>
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(350px, 1fr))",
          gap: "2rem",
        }}
      >
        {prices.map((price, idx) => (
          <div
            key={price.symbol}
            style={{
              background: "white",
              padding: "1rem",
              borderRadius: "8px",
              border: "1px solid #ddd",
              boxShadow: "0 2px 4px rgba(0,0,0,0.05)",
            }}
          >
            <div
              style={{
                fontSize: "1.1rem",
                fontWeight: "bold",
                marginBottom: "0.5rem",
              }}
            >
              {STOCK_LABELS[idx]}
            </div>

            <div
              style={{
                display: "flex",
                alignItems: "baseline",
                marginBottom: "1rem",
                gap: "1rem",
              }}
            >
              <div style={{ fontSize: "2rem", fontWeight: "bold" }}>
                ${price.price.toFixed(2)}
              </div>
              <div
                style={{
                  color: price.change24h >= 0 ? "#00a854" : "#f5222d",
                  fontSize: "0.9rem",
                  fontWeight: "bold",
                }}
              >
                {price.change24h >= 0 ? "+" : ""}
                {price.change24h.toFixed(2)}%
              </div>
            </div>

            <div style={{ marginTop: "1rem" }}>
              <div
                style={{
                  fontSize: "0.8rem",
                  color: "#666",
                  marginBottom: "0.5rem",
                }}
              >
                30-Day Chart
              </div>
              {history[idx] && history[idx].length > 0 ? (
                <SimpleLineChart data={history[idx]} color={COLORS[idx]} />
              ) : (
                <div
                  style={{
                    textAlign: "center",
                    color: "#999",
                    padding: "1rem",
                  }}
                >
                  No chart data
                </div>
              )}
            </div>
          </div>
        ))}
      </div>
      <div
        style={{
          fontSize: "0.75rem",
          color: "#999",
          marginTop: "1rem",
        }}
      >
        Real-time prices from Yahoo Finance API. Updated every minute.
      </div>
    </section>
  );
}
