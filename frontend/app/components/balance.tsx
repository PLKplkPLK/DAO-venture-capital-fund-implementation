"use client";

import { useEffect, useState } from "react";
import { getBalances, subscribeToTransferEvents } from "../bc/daoContract";

export default function Balance() {
  const [balance, setBalance] = useState<string>("0.00");
  const [fundTotal, setFundTotal] = useState<string>("0.00");
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string>("");

  const fetchBalances = async () => {
    try {
      setError("");
      const { userBalance, fundTotal } = await getBalances();

      setBalance(Number(userBalance).toFixed(2));
      setFundTotal(Number(fundTotal).toFixed(2));
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

    return () => {
      if (cleanupTransferListener) {
        cleanupTransferListener();
      }
    };
  }, []);

  if (loading) {
    return (
      <p>
        Your Balance: <strong>Loading...</strong> | Fund Total:{" "}
        <strong>Loading...</strong>
      </p>
    );
  }

  if (error) {
    return <p style={{ color: "#b91c1c" }}>Error: {error}</p>;
  }

  return (
    <p>
      Your Balance: <strong>{balance} ETH?</strong> | Fund Total:{" "}
      <strong>{fundTotal} ETH</strong>
    </p>
  );
}
