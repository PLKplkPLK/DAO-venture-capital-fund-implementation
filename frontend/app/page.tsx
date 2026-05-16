"use client";
import { SyntheticEvent, useState } from "react";

import { depositToDao, withdrawFromDao } from "./bc/daoContract";
import Balance from "./components/balance";

export default function Home() {
  const [depositAmount, setDepositAmount] = useState("");
  const [withdrawAmount, setWithdrawAmount] = useState("");
  const [statusMessage, setStatusMessage] = useState("");
  const [errorMessage, setErrorMessage] = useState("");

  const handleDeposit = async (e: SyntheticEvent<HTMLFormElement>) => {
    e.preventDefault();
    setStatusMessage("");
    setErrorMessage("");

    try {
      const status = await depositToDao(depositAmount);
      setStatusMessage(status);
      setDepositAmount("");
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : "Deposit failed",
      );
    }
  };

  const handleWithdraw = async (e: SyntheticEvent<HTMLFormElement>) => {
    e.preventDefault();
    setStatusMessage("");
    setErrorMessage("");

    try {
      const status = await withdrawFromDao(withdrawAmount);
      setStatusMessage(status);
      setWithdrawAmount("");
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : "Withdraw failed",
      );
    }
  };

  return (
    <div
      style={{
        maxWidth: "800px",
        margin: "0 auto",
        padding: "2rem",
        fontFamily: "sans-serif",
      }}
    >
      <header
        style={{
          borderBottom: "1px solid #ccc",
          paddingBottom: "1rem",
          marginBottom: "2rem",
        }}
      >
        <h1>HF DAO</h1>
        <Balance></Balance>
      </header>

      <div style={{ display: "flex", gap: "2rem", marginBottom: "2rem" }}>
        {/* Deposit Section */}
        <section
          style={{
            flex: 1,
            padding: "1rem",
            border: "1px solid #eee",
            borderRadius: "8px",
          }}
        >
          <h2>Deposit ETH</h2>
          <form onSubmit={handleDeposit}>
            <input
              type="number"
              placeholder="Amount in ETH"
              value={depositAmount}
              onChange={(e) => setDepositAmount(e.target.value)}
              style={{
                padding: "0.5rem",
                width: "100%",
                marginBottom: "1rem",
                marginTop: "1rem",
                border: "solid #ddd 1px",
                borderRadius: "5px",
              }}
            />
            <button
              type="submit"
              style={{
                padding: "0.5rem 1rem",
                width: "100%",
                cursor: "pointer",
                border: "solid #ddd 1px",
                borderRadius: "5px",
              }}
            >
              Deposit & Get HF Tokens
            </button>
          </form>
        </section>

        {/* Withdraw Section */}
        <section
          style={{
            flex: 1,
            padding: "1rem",
            border: "1px solid #eee",
            borderRadius: "8px",
          }}
        >
          <h2>Withdraw ETH</h2>
          <form onSubmit={handleWithdraw}>
            <input
              type="number"
              placeholder="Amount in DAO"
              value={withdrawAmount}
              onChange={(e) => setWithdrawAmount(e.target.value)}
              style={{
                padding: "0.5rem",
                width: "100%",
                marginTop: "1rem",
                marginBottom: "1rem",
                border: "solid #ddd 1px",
                borderRadius: "5px",
              }}
            />
            <button
              type="submit"
              style={{
                padding: "0.5rem 1rem",
                width: "100%",
                cursor: "pointer",
                border: "solid #ddd 1px",
                borderRadius: "5px",
              }}
            >
              Burn DAO & Withdraw ETH
            </button>
          </form>
        </section>
      </div>

      {/* Voting Section Scaffold */}
      <section
        style={{ padding: "1rem", background: "#f9f9f9", borderRadius: "8px" }}
      >
        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
          }}
        >
          <h2>Active Proposals</h2>
          <button style={{ padding: "0.5rem 1rem", cursor: "pointer" }}>
            + Create Proposal
          </button>
        </div>
        <p style={{ color: "#666" }}>
          No active proposals yet. Deposit ETH to gain voting power!
        </p>
        {/* TODO map through proposals */}
      </section>
    </div>
  );
}
