"use client";

import { useEffect, useState } from "react";
import { ethers } from "ethers";
import { fetchAllProposals, type Proposal, getPriceForStock, depositBroker, getBrokerDeposit, getRequiredBrokerDeposit } from "../bc/daoContract";
import { isCurrentUserBroker, brokerExecuteOrder } from "../bc/brokerContract";

export default function BrokerPage() {
  const [proposals, setProposals] = useState<Proposal[]>([]);
  const [isBroker, setIsBroker] = useState<boolean | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [executingId, setExecutingId] = useState<number | null>(null);
  const [depositAmount, setDepositAmount] = useState<string>("");
  const [depositing, setDepositing] = useState<boolean>(false);
  const [statusMessage, setStatusMessage] = useState<string>("");
  const [errorMessage, setErrorMessage] = useState<string>("");
  const [currentBrokerDeposit, setCurrentBrokerDeposit] = useState<string>("0");
  const [requiredBrokerDeposit, setRequiredBrokerDeposit] = useState<string>("0");
  
  // cached oracle prices per stock
  const [oraclePrices, setOraclePrices] = useState<Record<number, string>>({});

  const loadBrokerData = async () => {
    setLoading(true);
    try {
      const brokerCheck = await isCurrentUserBroker();
      setIsBroker(brokerCheck);

      if (brokerCheck) {
        const allProposals = await fetchAllProposals();
        const currentTimestamp = Math.floor(Date.now() / 1000); 
        const pendingOrders = allProposals.filter((p) => {
          const yesVotesWei = ethers.parseEther(p.yesVotes);
          const noVotesWei = ethers.parseEther(p.noVotes);

          return (
            !p.executed && 
            currentTimestamp >= Number(p.endTime) && 
            yesVotesWei > noVotesWei
          );
        });

        setProposals(pendingOrders);
        // fetch oracle prices for relevant stocks
        try {
          const stocks = Array.from(new Set(pendingOrders.flatMap(p => [p.toBuy, p.toSell]).filter(s => s < 3)));
          const prices: Record<number, string> = {};
          for (const s of stocks) {
            try {
              prices[s] = await getPriceForStock(s);
            } catch (err) {
              console.warn("Failed to fetch price for stock", s, err);
              prices[s] = "0";
            }
          }
          setOraclePrices(prices);
        } catch (err) {
          console.warn("Failed to fetch oracle prices", err);
        }
          // fetch broker deposit info for connected broker
          try {
            const [cur, req] = await Promise.all([getBrokerDeposit(), getRequiredBrokerDeposit()]);
            setCurrentBrokerDeposit(cur);
            setRequiredBrokerDeposit(req);
          } catch (err) {
            console.warn("Failed to fetch broker deposit info", err);
          }
      }
    } catch (error) {
      console.error("Failed to load broker data", error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void loadBrokerData();
      if (typeof window !== "undefined" && (window as any).ethereum) {
      const handleAccountsChanged = () => {
        void loadBrokerData();
      };
      (window as any).ethereum.on("accountsChanged", handleAccountsChanged);
      return () => {
        (window as any).ethereum.removeListener("accountsChanged", handleAccountsChanged);
      };
    }
  }, []);

  

  const handleExecuteOrder = async (proposal: Proposal) => {
    setStatusMessage("");
    setErrorMessage("");

    if (
      requiredBrokerDeposit !== "N/A" &&
      Number(currentBrokerDeposit) < Number(requiredBrokerDeposit)
    ) {
      setErrorMessage(
        `Broker deposit too low. Required: ${requiredBrokerDeposit} ETH, current: ${currentBrokerDeposit} ETH`,
      );
      return;
    }
    console.log(proposal.executed);

    setExecutingId(proposal.id);
    await loadBrokerData();
    try {
      const isBuy = proposal.label !== null;
      const assetId = isBuy ? proposal.toBuy : proposal.toSell;
      const msg = await brokerExecuteOrder(proposal.id, assetId, isBuy);
      setStatusMessage(msg);
      await loadBrokerData();
    } catch (error) {
      console.error("Execution failed:", error);
      setErrorMessage(error instanceof Error ? error.message : "Execution failed");
    } finally {
      setExecutingId(null);
    }
  };

  const handleDeposit = async () => {
    setStatusMessage("");
    setErrorMessage("");
    if (!depositAmount || Number(depositAmount) <= 0) {
      setErrorMessage("Enter a deposit amount > 0 wei");
      return;
    }
    setDepositing(true);
    try {
      const res = await depositBroker(depositAmount);
      setStatusMessage(res);
      setDepositAmount("");
      await loadBrokerData();
    } catch (err) {
      console.error(err);
      setErrorMessage(err instanceof Error ? err.message : "Deposit failed");
    } finally {
      setDepositing(false);
    }
  };

  if (loading) return <div style={{ padding: "2rem", fontFamily: "sans-serif" }}>Loading Broker Panel...</div>;

  if (isBroker === false) {
    return (
      <div style={{ padding: "3rem", color: "red", textAlign: "center", fontFamily: "sans-serif" }}>
        <h2>Access Denied</h2>
        <p>Your currently connected wallet is not registered as the official Broker.</p>
        <p style={{ fontSize: "0.85rem", color: "#666", marginTop: "1.5rem" }}>Switch account in MetaMask to the authorized Broker address to process trades.</p>
      </div>
    );
  }

  return (
    <div style={{ width: "100%", maxWidth: "1000px", margin: "0 auto", padding: "2rem", fontFamily: "sans-serif" }}>
      <header style={{ borderBottom: "1px solid #ccc", paddingBottom: "1rem", marginBottom: "2rem" }}>
        <h1 style={{ margin: "0 0 0.5rem 0" }}>Broker Dashboard</h1>
      </header>

      <section>
        <div style={{ height: "3rem", marginBottom: "1rem", display: "flex", alignItems: "center", gap: "0.5rem", overflow: "auto" }}>
          {statusMessage && (
            <p style={{ color: "green", margin: 0, fontWeight: "bold" }}>{statusMessage}</p>
          )}
          {errorMessage && (
            <p style={{ color: "red", margin: 0, fontWeight: "bold" }}>{errorMessage}</p>
          )}
        </div>
        <div style={{ marginBottom: "1rem", display: "flex", gap: "1rem", alignItems: "center" }}>
          <div style={{ fontSize: "0.95rem", color: "#333" }}>
            <strong>Your Deposit:</strong> {currentBrokerDeposit} ETH
          </div>
          <div style={{ fontSize: "0.95rem", color: "#333" }}>
            <strong>Required:</strong>{' '}
            {requiredBrokerDeposit === "N/A" ? (
              <span style={{ color: "#c43", fontStyle: "italic" }}>N/A — update/redeploy DAO</span>
            ) : (
              <span>{requiredBrokerDeposit} ETH</span>
            )}
          </div>
        </div>
        {isBroker && (
          <div style={{ marginBottom: "1.5rem", display: "flex", gap: "0.5rem", alignItems: "center" }}>
            <input
              type="text"
              placeholder="Deposit amount (wei)"
              value={depositAmount}
              onChange={(e) => setDepositAmount(e.target.value)}
              style={{ padding: "0.5rem", border: "1px solid #ccc", borderRadius: "4px", width: "220px" }}
            />
            <button
              onClick={() => void handleDeposit()}
              disabled={depositing}
              style={{ padding: "0.4rem 0.8rem", background: "#f0f0f0", border: "1px solid #ccc", borderRadius: "4px", cursor: "pointer", fontSize: "0.85rem" }}
            >
              {depositing ? "Pending..." : "Deposit"}
            </button>
          </div>
        )}
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1.5rem" }}>
          <h2 style={{ margin: 0 }}>Orders Queue From DAO</h2>
          <button 
            onClick={() => void loadBrokerData()} 
            style={{ padding: "0.4rem 0.8rem", background: "#f0f0f0", border: "1px solid #ccc", borderRadius: "4px", cursor: "pointer", fontSize: "0.85rem" }}
          >
            Refresh Queue
          </button>
        </div>
        
        {proposals.length === 0 ? (
          <div style={{ padding: "3rem", textAlign: "center", background: "#f9f9f9", borderRadius: "8px", border: "1px dashed #ccc" }}>
            <p style={{ color: "#666", margin: 0, fontStyle: "italic" }}>No pending orders from the DAO.</p>
            <p style={{ color: "#999", fontSize: "0.8rem", marginTop: "0.5rem" }}>Orders will appear here automatically once DAO voting ends successfully.</p>
          </div>
        ) : (
          <div style={{ display: "grid", gap: "1.5rem" }}>
            {proposals.map((proposal) => {
              const isBuy = proposal.label !== null;
              return (
                <div key={proposal.id} style={{ border: "1px solid #ddd", borderRadius: "8px", padding: "1.5rem", background: "#fdfdfd", boxShadow: "0 2px 4px rgba(0,0,0,0.05)" }}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                    <div>
                      <span style={{ background: isBuy ? "#0b66ff" : "#d63333", color: "white", padding: "0.25rem 0.5rem", borderRadius: "4px", fontSize: "0.8rem", fontWeight: "bold" }}>
                        {isBuy ? "BUY ORDER" : "SELL ORDER"}
                      </span>
                      <h3 style={{ margin: "0.5rem 0 0.25rem 0" }}>Proposal #{proposal.id}: {isBuy ? proposal.label : proposal.sellLabel}</h3>
                      <p style={{ margin: 0, color: "#555", fontSize: "0.95rem" }}>
                        <strong>Volume:</strong> {isBuy ? `${proposal.buyAmount} ETH` : `${proposal.sellAmount} Units`}
                      </p>
                    </div>

                    <div style={{ width: "260px", textAlign: "right" }}>
                      {isBuy ? (
                        /* BUY ORDER VIEW */
                        <>
                          <div style={{ fontSize: "0.85rem", color: "#666", marginBottom: "0.35rem" }}>
                            Unit price (Oracle)
                          </div>
                          <div style={{ fontWeight: 700, marginBottom: "0.6rem" }}>
                            {Number(oraclePrices[proposal.toBuy]).toFixed(4) ?? "-"} ETH
                          </div>

                          <div style={{ fontSize: "0.85rem", color: "#666", marginBottom: "0.35rem" }}>
                            Estimated Stock Units
                          </div>
                          <div style={{ fontWeight: 700, marginBottom: "0.6rem", color: "#00875a" }}>
                            {(() => {
                              const price = oraclePrices[proposal.toBuy];
                              if (!price || Number(price) === 0) return "-";
                              try {
                                const unitsGained = Number(proposal.buyAmount) / Number(price);
                                return `${unitsGained.toFixed(4)} Units`;
                              } catch { return "-"; }
                            })()}
                          </div>

                          <div style={{ fontSize: "0.85rem", color: "#666", marginBottom: "0.35rem" }}>
                            Total Outlay (Pay)
                          </div>
                          <div style={{ fontWeight: 700, marginBottom: "0.6rem" }}>
                            {proposal.buyAmount} ETH
                          </div>
                        </>
                      ) : (
                        /* SELL ORDER VIEW */
                        <>
                          <div style={{ fontSize: "0.85rem", color: "#666", marginBottom: "0.35rem" }}>
                            Unit price (Oracle)
                          </div>
                          <div style={{ fontWeight: 700, marginBottom: "0.6rem" }}>
                            {Number(oraclePrices[proposal.toSell]).toFixed(4) ?? "-"} ETH
                          </div>

                          <div style={{ fontSize: "0.85rem", color: "#666", marginBottom: "0.35rem" }}>
                            Volume To Liquidate
                          </div>
                          <div style={{ fontWeight: 700, marginBottom: "0.6rem", color: "#de350b" }}>
                            {proposal.sellAmount} Units
                          </div>

                          <div style={{ fontSize: "0.85rem", color: "#666", marginBottom: "0.35rem" }}>
                            Expected ETH Yield
                          </div>
                          <div style={{ fontWeight: 700, marginBottom: "0.6rem" }}>
                            {(() => {
                              const price = oraclePrices[proposal.toSell];
                              if (!price || Number(price) === 0) return "-";
                              try {
                                const totalEthGained = Number(price) * Number(proposal.sellAmount);
                                return `${totalEthGained.toFixed(4)} ETH`;
                              } catch { return "-"; }
                            })() ?? "-"}
                          </div>
                        </>
                      )}

                      <button
                        disabled={executingId === proposal.id || proposal.executed}
                        onClick={() => void handleExecuteOrder(proposal)}
                        style={{
                          padding: "0.6rem",
                          background: executingId === proposal.id ? "#cccccc" : "#f0f0f0",
                          color: "#111",
                          border: "1px solid #ccc",
                          borderRadius: "4px",
                          fontWeight: "600",
                          cursor: executingId === proposal.id ? "not-allowed" : "pointer",
                          transition: "background 0.2s"
                        }}
                      >
                        {executingId === proposal.id 
                          ? "Processing..." 
                          : proposal.executed 
                            ? "Executed ✓" 
                            : "Execute Order"
                        }
                      </button>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </section>
    </div>
  );
}