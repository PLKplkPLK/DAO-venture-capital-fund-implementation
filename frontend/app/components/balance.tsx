"use client";

import { useEffect, useState } from "react";
import {
  getBalances,
  subscribeToTransferEvents,
  getFundTotalValue,
  getPortfolioValue,
  getAllPortfolioStocks,
} from "../bc/daoContract";

export default function Balance() {
  const [balance, setBalance] = useState<string>("0.0");
  const [fundTotal, setFundTotal] = useState<string>("0");
  const [fundTotalValue, setFundTotalValue] = useState<string>("0.00");
  const [portfolioValue, setPortfolioValue] = useState<string>("0.00");
  const [portfolio, setPortfolio] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string>("");

  const fetchBalances = async () => {
    try {
      setError("");
      const { userBalance, fundTotalWei } = await getBalances();
      const totalValue = await getFundTotalValue();
      const pValue = await getPortfolioValue();
      const holdings = await getAllPortfolioStocks();

      // Full-precision token amount so tiny (wei-scale) balances are visible
      setBalance(userBalance);
      setFundTotal(fundTotalWei);
      setFundTotalValue(Number(totalValue).toFixed(2));
      setPortfolioValue(Number(pValue).toFixed(2));
      setPortfolio(holdings);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to fetch balance");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    let cleanupTransferListener: (() => void) | null = null;

    const setupEventListener = async () => {
      try {
        await fetchBalances();

        cleanupTransferListener = await subscribeToTransferEvents(async () => {
          await fetchBalances();
        });
      } catch (err) {
        console.error("Event listener setup failed:", err);
      }
    };

    setupEventListener();

    // Refresh when the user connects, unlocks, or switches accounts so the
    // share balance appears as soon as a wallet becomes available.
    const ethereum =
      typeof window !== "undefined" ? (window as any).ethereum : undefined;
    const handleAccountsChanged = () => {
      void fetchBalances();
    };
    ethereum?.on?.("accountsChanged", handleAccountsChanged);

    return () => {
      if (cleanupTransferListener) {
        cleanupTransferListener();
      }
      ethereum?.removeListener?.("accountsChanged", handleAccountsChanged);
    };
  }, []);

  if (loading) {
    return (
      <div>
        <p>
          Your Balance: <strong>Loading...</strong> | Fund Total:{" "}
          <strong>Loading...</strong>
        </p>
      </div>
    );
  }

  if (error) {
    return <p style={{ color: "#b91c1c" }}>Error: {error}</p>;
  }

  return (
    <div>
      <p style={{ marginBottom: "0.5rem" }}>
        Your Balance: <strong>{balance} HFT</strong> | Fund Total:{" "}
        <strong>{fundTotal} wei</strong>
      </p>
      <p style={{ marginBottom: "0.5rem", color: "#666", fontSize: "0.9rem" }}>
        Fund Value: <strong>${fundTotalValue}</strong> | Portfolio:{" "}
        <strong>${portfolioValue}</strong>
      </p>
      {Object.keys(portfolio).length > 0 && (
        <div
          style={{ fontSize: "0.85rem", color: "#777", marginTop: "0.5rem" }}
        >
          Holdings:
          {Object.entries(portfolio).map(([stock, amount]) => (
            <span key={stock} style={{ marginLeft: "1rem" }}>
              {stock}: {Number(amount).toFixed(2)} units
            </span>
          ))}
        </div>
      )}
    </div>
  );
}
