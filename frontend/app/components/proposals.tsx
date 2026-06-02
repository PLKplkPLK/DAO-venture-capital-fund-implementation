"use client";

import { useEffect, useState, SyntheticEvent } from "react";
import {
  createBuyProposal,
  createSellProposal,
  fetchAllProposals,
  voteOnProposal,
  executeProposal,
  STOCKS,
  type Proposal,
} from "../bc/daoContract";

export default function Proposals() {
  const [proposals, setProposals] = useState<Proposal[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [creating, setCreating] = useState<boolean>(false);
  const [votingProposal, setVotingProposal] = useState<number | null>(null);
  const [executingProposal, setExecutingProposal] = useState<number | null>(
    null,
  ); // <-- Added tracking state
  const [newToBuy, setNewToBuy] = useState<number>(0);
  const [newBuyAmount, setNewBuyAmount] = useState<string>("");
  const [newToSell, setNewToSell] = useState<number>(255); // 255 = none
  const [newSellAmount, setNewSellAmount] = useState<string>("");
  const [statusMessage, setStatusMessage] = useState<string>("");
  const [errorMessage, setErrorMessage] = useState<string>("");

  const loadProposals = async () => {
    setLoading(true);
    setErrorMessage("");
    try {
      const fetched = await fetchAllProposals();
      setProposals(fetched);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : "Failed to load proposals",
      );
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void loadProposals();
  }, []);

  const handleCreateBuyProposal = async (
    event: SyntheticEvent<HTMLFormElement>,
  ) => {
    event.preventDefault();
    setStatusMessage("");
    setErrorMessage("");
    setCreating(true);

    try {
      if (!newBuyAmount || Number(newBuyAmount) <= 0) {
        throw new Error("Buy amount must be greater than 0");
      }

      await createBuyProposal(newToBuy, newBuyAmount);

      setStatusMessage("Proposal created successfully.");
      setNewBuyAmount("");
      setNewSellAmount("");
      setNewToSell(255);
      await loadProposals();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : "Failed to create proposal",
      );
    } finally {
      setCreating(false);
    }
  };

  const handleCreateSellProposal = async (
    event: SyntheticEvent<HTMLFormElement>,
  ) => {
    event.preventDefault();
    setStatusMessage("");
    setErrorMessage("");
    setCreating(true);

    try {
      if (newToSell === 255) {
        throw new Error("Please select a stock to sell");
      }
      if (!newSellAmount || Number(newSellAmount) <= 0) {
        throw new Error("Sell amount must be greater than 0");
      }

      await createSellProposal(newToSell, newSellAmount);

      setStatusMessage("Proposal created successfully.");
      setNewBuyAmount("");
      setNewSellAmount("");
      setNewToSell(255);
      await loadProposals();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : "Failed to create proposal",
      );
    } finally {
      setCreating(false);
    }
  };

  const handleVote = async (proposalId: number, choice: number) => {
    setStatusMessage("");
    setErrorMessage("");
    setVotingProposal(proposalId);

    try {
      await voteOnProposal(proposalId, choice);
      setStatusMessage("Vote submitted.");
      await loadProposals();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : "Failed to submit vote",
      );
    } finally {
      setVotingProposal(null);
    }
  };

  // New handler function for execution
  const handleExecute = async (proposalId: number) => {
    setStatusMessage("");
    setErrorMessage("");
    setExecutingProposal(proposalId);

    try {
      await executeProposal(proposalId);
      setStatusMessage(`Proposal #${proposalId} executed successfully!`);
      await loadProposals();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : "Failed to execute proposal",
      );
    } finally {
      setExecutingProposal(null);
    }
  };

  const formatTimestamp = (timestamp: bigint) => {
    return new Date(Number(timestamp) * 1000).toLocaleString();
  };

  const nowSeconds = Math.floor(Date.now() / 1000);

  return (
    <section
      style={{ padding: "1rem", background: "#f9f9f9", borderRadius: "8px" }}
    >
      <h2>Active Proposals</h2>

      {/* Create Proposal Form */}
      <div style={{ display: "flex", gap: "2rem", marginBottom: "2rem" }}>
        {/* Create Buy Proposal Section */}
        <section
          style={{
            flex: 1,
            padding: "1rem",
            border: "1px solid #eee",
            borderRadius: "8px",
          }}
        >
          <h2>Create Buy Proposal</h2>
          <form
            onSubmit={handleCreateBuyProposal}
            style={{ display: "grid", gap: "1rem" }}
          >
            <div>
              <label
                style={{
                  display: "block",
                  marginBottom: "0.5rem",
                  fontWeight: "bold",
                }}
              >
                Stock to Buy
              </label>
              <select
                value={newToBuy}
                onChange={(e) => setNewToBuy(Number(e.target.value))}
                style={{
                  padding: "0.5rem",
                  borderRadius: "5px",
                  border: "1px solid #ddd",
                  width: "100%",
                }}
              >
                {STOCKS.map((stock) => (
                  <option key={stock.value} value={stock.value}>
                    {stock.label}
                  </option>
                ))}
              </select>

              <label
                style={{
                  display: "block",
                  marginBottom: "0.5rem",
                  fontWeight: "bold",
                  marginTop: "0.75rem",
                }}
              >
                ETH to Spend
              </label>
              <input
                type="number"
                placeholder="Amount in ETH"
                value={newBuyAmount}
                onChange={(e) => setNewBuyAmount(e.target.value)}
                step="0.01"
                min="0"
                style={{
                  padding: "0.5rem",
                  borderRadius: "5px",
                  border: "1px solid #ddd",
                  width: "100%",
                }}
              />
            </div>

            <button
              type="submit"
              disabled={creating}
              style={{
                padding: "0.75rem 1rem",
                cursor: creating ? "not-allowed" : "pointer",
                border: "solid #0b66ff 2px",
                borderRadius: "5px",
                background: "#0b66ff",
                color: "white",
                fontWeight: "bold",
              }}
            >
              {creating ? "Creating..." : "+ Create Buy Proposal"}
            </button>
          </form>
        </section>

        {/* Create Sell Proposal Section */}
        <section
          style={{
            flex: 1,
            padding: "1rem",
            border: "1px solid #eee",
            borderRadius: "8px",
          }}
        >
          <h2>Create Sell Proposal</h2>
          <form
            onSubmit={handleCreateSellProposal}
            style={{ display: "grid", gap: "1rem" }}
          >
            <div>
              <label
                style={{
                  display: "block",
                  marginBottom: "0.5rem",
                  fontWeight: "bold",
                }}
              >
                Stock to Sell
              </label>
              <select
                value={newToSell}
                onChange={(e) => setNewToSell(Number(e.target.value))}
                style={{
                  padding: "0.5rem",
                  borderRadius: "5px",
                  border: "1px solid #ddd",
                  width: "100%",
                }}
              >
                <option value={255}>None</option>
                {STOCKS.map((stock) => (
                  <option key={stock.value} value={stock.value}>
                    {stock.label}
                  </option>
                ))}
              </select>

              <label
                style={{
                  display: "block",
                  marginBottom: "0.5rem",
                  fontWeight: "bold",
                  marginTop: "0.75rem",
                }}
              >
                Amount to Sell
              </label>
              <input
                type="number"
                placeholder="Amount in units"
                value={newSellAmount}
                onChange={(e) => setNewSellAmount(e.target.value)}
                step="0.01"
                min="0"
                disabled={newToSell === 255}
                style={{
                  padding: "0.5rem",
                  borderRadius: "5px",
                  border: "1px solid #ddd",
                  width: "100%",
                  opacity: newToSell === 255 ? 0.5 : 1,
                }}
              />
            </div>

            <button
              type="submit"
              disabled={creating || newToSell === 255}
              style={{
                padding: "0.75rem 1rem",
                cursor:
                  creating || newToSell === 255 ? "not-allowed" : "pointer",
                border: "solid #d63333 2px",
                borderRadius: "5px",
                background: "#d63333",
                color: "white",
                fontWeight: "bold",
              }}
            >
              {creating ? "Creating..." : "+ Create Sell Proposal"}
            </button>
          </form>
        </section>
      </div>

      <div style={{ minHeight: "2rem", marginBottom: "1rem" }}>
        {statusMessage && (
          <p style={{ color: "green", margin: 0, fontWeight: "bold" }}>
            {statusMessage}
          </p>
        )}
        {errorMessage && (
          <p style={{ color: "red", margin: 0, fontWeight: "bold" }}>
            {errorMessage}
          </p>
        )}
      </div>

      {/* Proposals List */}
      {loading ? (
        <p style={{ color: "#666" }}>Loading proposals...</p>
      ) : proposals.length === 0 ? (
        <p style={{ color: "#666" }}>No proposals found.</p>
      ) : (
        <div style={{ display: "flex", gap: "2rem", marginBottom: "2rem" }}>
          {/* Buy Proposals Section */}
          <section
            style={{
              flex: 1,
              padding: "1rem",
              border: "1px solid #eee",
              borderRadius: "8px",
              background: "white",
            }}
          >
            <h3
              style={{ marginTop: 0, marginBottom: "1rem", color: "#0b66ff" }}
            >
              📈 Buy Proposals
            </h3>
            <div style={{ display: "grid", gap: "1rem" }}>
              {proposals
                .filter((p) => p.toSell === 255 || p.sellLabel === null)
                .map((proposal) => {
                  const ended = Number(proposal.endTime) <= nowSeconds;
                  const passed =
                    ended &&
                    Number(proposal.yesVotes) > Number(proposal.noVotes);
                  const failed =
                    ended &&
                    Number(proposal.yesVotes) <= Number(proposal.noVotes);

                  return (
                    <div
                      key={proposal.id}
                      style={{
                        border: "1px solid #ddd",
                        borderRadius: "8px",
                        padding: "1rem",
                        background: "#f9f9f9",
                      }}
                    >
                      <div
                        style={{
                          display: "flex",
                          justifyContent: "space-between",
                          flexWrap: "wrap",
                          gap: "0.5rem",
                          marginBottom: "1rem",
                        }}
                      >
                        <strong>Proposal #{proposal.id}</strong>
                        <span
                          style={{
                            fontWeight: "bold",
                            color: proposal.executed
                              ? "green"
                              : passed
                                ? "#0b66ff"
                                : failed
                                  ? "red"
                                  : "#f59e0b",
                          }}
                        >
                          {proposal.executed
                            ? "✓ Executed"
                            : passed
                              ? "Passed (Pending)"
                              : failed
                                ? "✗ Failed"
                                : "Active"}
                        </span>
                      </div>

                      <div
                        style={{
                          background: "#fff",
                          padding: "0.75rem",
                          borderRadius: "5px",
                          marginBottom: "1rem",
                          border: "1px solid #ddd",
                        }}
                      >
                        <div style={{ fontSize: "0.95rem" }}>
                          {proposal.label && (
                            <>
                              <div
                                style={{ color: "#666", fontSize: "0.85rem" }}
                              >
                                BUY
                              </div>
                              <div style={{ fontWeight: "bold" }}>
                                {proposal.label}
                              </div>
                              <div
                                style={{ color: "#888", fontSize: "0.85rem" }}
                              >
                                {proposal.buyAmount} ETH
                              </div>
                            </>
                          )}
                        </div>
                      </div>

                      {/* Votes */}
                      <div
                        style={{
                          display: "grid",
                          gridTemplateColumns: "1fr 1fr",
                          gap: "0.75rem",
                          marginBottom: "1rem",
                        }}
                      >
                        <div
                          style={{
                            background: "#eef4ff",
                            padding: "0.75rem",
                            borderRadius: "5px",
                          }}
                        >
                          <div
                            style={{ color: "#0b66ff", fontSize: "0.85rem" }}
                          >
                            Yes Votes
                          </div>
                          <div
                            style={{ fontWeight: "bold", fontSize: "1.2rem" }}
                          >
                            {proposal.yesVotes.toString()}
                          </div>
                        </div>
                        <div
                          style={{
                            background: "#fff0f0",
                            padding: "0.75rem",
                            borderRadius: "5px",
                          }}
                        >
                          <div
                            style={{ color: "#d63333", fontSize: "0.85rem" }}
                          >
                            No Votes
                          </div>
                          <div
                            style={{ fontWeight: "bold", fontSize: "1.2rem" }}
                          >
                            {proposal.noVotes.toString()}
                          </div>
                        </div>
                      </div>

                      <div
                        style={{
                          color: "#777",
                          fontSize: "0.85rem",
                          marginBottom: "1rem",
                        }}
                      >
                        Snapshot Block: {proposal.snapshotBlock.toString()}
                        <br />
                        Ends: {formatTimestamp(proposal.endTime)}
                      </div>

                      {/* Dynamic Action Buttons */}
                      <div style={{ display: "flex", gap: "0.5rem" }}>
                        {!ended ? (
                          <>
                            <button
                              disabled={votingProposal === proposal.id}
                              onClick={() => void handleVote(proposal.id, 1)}
                              style={{
                                padding: "0.5rem 0.75rem",
                                border: "1px solid #0b66ff",
                                borderRadius: "5px",
                                background: "#eef4ff",
                                cursor: "pointer",
                              }}
                            >
                              Vote Yes
                            </button>
                            <button
                              disabled={votingProposal === proposal.id}
                              onClick={() => void handleVote(proposal.id, 2)}
                              style={{
                                padding: "0.5rem 0.75rem",
                                border: "1px solid #d63333",
                                borderRadius: "5px",
                                background: "#fff0f0",
                                cursor: "pointer",
                              }}
                            >
                              Vote No
                            </button>
                          </>
                        ) : passed && !proposal.executed ? (
                          <button
                            disabled={executingProposal === proposal.id}
                            onClick={() => void handleExecute(proposal.id)}
                            style={{
                              padding: "0.6rem 1rem",
                              width: "100%",
                              border: "1px solid green",
                              borderRadius: "5px",
                              background: "#e6f4ea",
                              color: "green",
                              fontWeight: "bold",
                              cursor:
                                executingProposal === proposal.id
                                  ? "not-allowed"
                                  : "pointer",
                            }}
                          >
                            {executingProposal === proposal.id
                              ? "Executing..."
                              : "⚙ Execute Proposal"}
                          </button>
                        ) : null}
                      </div>
                    </div>
                  );
                })}
            </div>
          </section>

          {/* Sell Proposals Section */}
          <section
            style={{
              flex: 1,
              padding: "1rem",
              border: "1px solid #eee",
              borderRadius: "8px",
              background: "white",
            }}
          >
            <h3
              style={{ marginTop: 0, marginBottom: "1rem", color: "#d63333" }}
            >
              📉 Sell Proposals
            </h3>
            <div style={{ display: "grid", gap: "1rem" }}>
              {proposals
                .filter((p) => p.toSell < 3 && p.sellLabel !== null)
                .map((proposal) => {
                  const ended = Number(proposal.endTime) <= nowSeconds;
                  const passed =
                    ended &&
                    Number(proposal.yesVotes) > Number(proposal.noVotes);
                  const failed =
                    ended &&
                    Number(proposal.yesVotes) <= Number(proposal.noVotes);

                  return (
                    <div
                      key={proposal.id}
                      style={{
                        border: "1px solid #ddd",
                        borderRadius: "8px",
                        padding: "1rem",
                        background: "#f9f9f9",
                      }}
                    >
                      <div
                        style={{
                          display: "flex",
                          justifyContent: "space-between",
                          flexWrap: "wrap",
                          gap: "0.5rem",
                          marginBottom: "1rem",
                        }}
                      >
                        <strong>Proposal #{proposal.id}</strong>
                        <span
                          style={{
                            fontWeight: "bold",
                            color: proposal.executed
                              ? "green"
                              : passed
                                ? "#0b66ff"
                                : failed
                                  ? "red"
                                  : "#f59e0b",
                          }}
                        >
                          {proposal.executed
                            ? "✓ Executed"
                            : passed
                              ? "Passed (Pending)"
                              : failed
                                ? "✗ Failed"
                                : "Active"}
                        </span>
                      </div>

                      <div
                        style={{
                          background: "#fff",
                          padding: "0.75rem",
                          borderRadius: "5px",
                          marginBottom: "1rem",
                          border: "1px solid #ddd",
                        }}
                      >
                        <div style={{ display: "grid", gap: "0.75rem" }}>
                          {proposal.label && (
                            <div>
                              <div
                                style={{ color: "#666", fontSize: "0.85rem" }}
                              >
                                BUY
                              </div>
                              <div style={{ fontWeight: "bold" }}>
                                {proposal.label}
                              </div>
                              <div
                                style={{ color: "#888", fontSize: "0.85rem" }}
                              >
                                {proposal.buyAmount} ETH
                              </div>
                            </div>
                          )}
                          {proposal.sellLabel && (
                            <div>
                              <div
                                style={{ color: "#666", fontSize: "0.85rem" }}
                              >
                                SELL
                              </div>
                              <div style={{ fontWeight: "bold" }}>
                                {proposal.sellLabel}
                              </div>
                              <div
                                style={{ color: "#888", fontSize: "0.85rem" }}
                              >
                                {proposal.sellAmount} units
                              </div>
                            </div>
                          )}
                        </div>
                      </div>

                      {/* Votes */}
                      <div
                        style={{
                          display: "grid",
                          gridTemplateColumns: "1fr 1fr",
                          gap: "0.75rem",
                          marginBottom: "1rem",
                        }}
                      >
                        <div
                          style={{
                            background: "#eef4ff",
                            padding: "0.75rem",
                            borderRadius: "5px",
                          }}
                        >
                          <div
                            style={{ color: "#0b66ff", fontSize: "0.85rem" }}
                          >
                            Yes Votes
                          </div>
                          <div
                            style={{ fontWeight: "bold", fontSize: "1.2rem" }}
                          >
                            {proposal.yesVotes.toString()}
                          </div>
                        </div>
                        <div
                          style={{
                            background: "#fff0f0",
                            padding: "0.75rem",
                            borderRadius: "5px",
                          }}
                        >
                          <div
                            style={{ color: "#d63333", fontSize: "0.85rem" }}
                          >
                            No Votes
                          </div>
                          <div
                            style={{ fontWeight: "bold", fontSize: "1.2rem" }}
                          >
                            {proposal.noVotes.toString()}
                          </div>
                        </div>
                      </div>

                      <div
                        style={{
                          color: "#777",
                          fontSize: "0.85rem",
                          marginBottom: "1rem",
                        }}
                      >
                        Snapshot Block: {proposal.snapshotBlock.toString()}
                        <br />
                        Ends: {formatTimestamp(proposal.endTime)}
                      </div>

                      {/* Dynamic Action Buttons */}
                      <div style={{ display: "flex", gap: "0.5rem" }}>
                        {!ended ? (
                          <>
                            <button
                              disabled={votingProposal === proposal.id}
                              onClick={() => void handleVote(proposal.id, 1)}
                              style={{
                                padding: "0.5rem 0.75rem",
                                border: "1px solid #0b66ff",
                                borderRadius: "5px",
                                background: "#eef4ff",
                                cursor: "pointer",
                              }}
                            >
                              Vote Yes
                            </button>
                            <button
                              disabled={votingProposal === proposal.id}
                              onClick={() => void handleVote(proposal.id, 2)}
                              style={{
                                padding: "0.5rem 0.75rem",
                                border: "1px solid #d63333",
                                borderRadius: "5px",
                                background: "#fff0f0",
                                cursor: "pointer",
                              }}
                            >
                              Vote No
                            </button>
                          </>
                        ) : passed && !proposal.executed ? (
                          <button
                            disabled={executingProposal === proposal.id}
                            onClick={() => void handleExecute(proposal.id)}
                            style={{
                              padding: "0.6rem 1rem",
                              width: "100%",
                              border: "1px solid green",
                              borderRadius: "5px",
                              background: "#e6f4ea",
                              color: "green",
                              fontWeight: "bold",
                              cursor:
                                executingProposal === proposal.id
                                  ? "not-allowed"
                                  : "pointer",
                            }}
                          >
                            {executingProposal === proposal.id
                              ? "Executing..."
                              : "⚙ Execute Proposal"}
                          </button>
                        ) : null}
                      </div>
                    </div>
                  );
                })}
            </div>
          </section>
        </div>
      )}
    </section>
  );
}
