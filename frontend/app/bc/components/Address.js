import React, { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { getProvider } from "../utils";

function Address() {
  const { id } = useParams(); // Ethereum address
  const [balance, setBalance] = useState(null);
  const [transactions, setTransactions] = useState([]);

  useEffect(() => {
    const fetchAddressData = async () => {
      const provider = getProvider();
      const balance = await provider.getBalance(id);
      setBalance(balance.toString());

      // Optional: fetch last 10 transactions from local node (if you track them)
      const latestBlockNumber = await provider.getBlockNumber();
      const txs = [];
      for (let i = 0; i < 100 && txs.length < 10; i++) {
        const block = await provider.getBlockWithTransactions(
          latestBlockNumber - i,
        );
        block.transactions.forEach((tx) => {
          if (tx.from === id || tx.to === id) txs.push(tx);
        });
      }
      setTransactions(txs.slice(0, 10));
    };

    fetchAddressData();
  }, [id]);

  if (!balance) return <p>Loading address data...</p>;

  return (
    <div>
      <h1>Address Details</h1>
      <p>
        <strong>Address:</strong> {id}
      </p>
      <p>
        <strong>Balance:</strong> {balance} GO
      </p>

      <h2>Recent Transactions</h2>
      <ul>
        {transactions.map((tx) => (
          <li key={tx.hash}>
            {tx.hash} - {tx.from} → {tx.to} ({tx.value.toString()} wei)
          </li>
        ))}
      </ul>
    </div>
  );
}
export default Address;
