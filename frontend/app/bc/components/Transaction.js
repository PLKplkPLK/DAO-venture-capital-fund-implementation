import React, { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { getProvider } from "../utils";

function Transaction() {
  const { id } = useParams(); // transaction hash
  const [tx, setTx] = useState(null);

  useEffect(() => {
    const fetchTransaction = async () => {
      const provider = getProvider();
      const transaction = await provider.getTransaction(id);
      setTx(transaction);
    };
    fetchTransaction();
  }, [id]);

  if (!tx) return <p>Loading transaction...</p>;

  return (
    <div>
      <h1>Transaction Details</h1>
      <ul>
        <li>
          <strong>Hash:</strong> {tx.hash}
        </li>
        <li>
          <strong>Block Number:</strong> {tx.blockNumber}
        </li>
        <li>
          <strong>From:</strong> {tx.from}
        </li>
        <li>
          <strong>To:</strong> {tx.to}
        </li>
        <li>
          <strong>Value:</strong> {tx.value.toString()} wei
        </li>
        <li>
          <strong>Gas Price:</strong> {tx.gasPrice.toString()} wei
        </li>
        <li>
          <strong>Nonce:</strong> {tx.nonce}
        </li>
      </ul>
    </div>
  );
}
export default Transaction;
