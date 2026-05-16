"use client";

import { useEffect, useState } from "react";
import {
  getUserAddress,
  getUserDaoBalance,
  getFundTotalBalance,
} from "../bc/daoContract";

export default function Balance() {
  const [balance, setBalance] = useState<string>("0.00");
  const [fundTotal, setFundTotal] = useState<string>("0.00");
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string>("");

  useEffect(() => {
    const fetchBalances = async () => {
      try {
        setLoading(true);
        setError("");

        // Get user's and fund's balance
        const userAddress = await getUserAddress();
        const userBalance = await getUserDaoBalance(userAddress);
        setBalance(Number(userBalance).toFixed(2));
        const fundEth = await getFundTotalBalance();
        setFundTotal(Number(fundEth).toFixed(2));
      } catch (err) {
        setError(
          err instanceof Error ? err.message : "Failed to fetch balance",
        );
      } finally {
        setLoading(false);
      }
    };

    fetchBalances();
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
