"use client";

import { useState } from "react";
import { openContractCall, showConnect } from "@stacks/connect";
import { STACKS_MAINNET } from "@stacks/network";
import { AnchorMode, PostConditionMode, uintCV } from "@stacks/transactions";

const CONTRACT_ADDRESS = "SP3E0DQAHTXJHH5YT9TZCSBW013YXZB25QFDVXXWY";
const CONTRACT_NAME = "lending";

export default function Lending() {
  const [address, setAddress] = useState<string | null>(null);
  const [txId, setTxId] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [amount, setAmount] = useState("");
  const [interest, setInterest] = useState("10");
  const [duration, setDuration] = useState("144");
  const [loanId, setLoanId] = useState("");

  const connectWallet = () => {
    showConnect({
      appDetails: { name: "Stacks Lending", icon: "/logo.png" },
      onFinish: () => {
        const userData = JSON.parse(localStorage.getItem("blockstack-session") || "{}");
        setAddress(userData?.userData?.profile?.stxAddress?.mainnet || null);
      },
      userSession: undefined,
    });
  };

  const requestLoan = async () => {
    if (!amount) return;
    setLoading(true);
    try {
      await openContractCall({
        network: STACKS_MAINNET,
        anchorMode: AnchorMode.Any,
        contractAddress: CONTRACT_ADDRESS,
        contractName: CONTRACT_NAME,
        functionName: "request-loan",
        functionArgs: [
          uintCV(Math.floor(Number(amount) * 1000000)),
          uintCV(parseInt(interest)),
          uintCV(parseInt(duration))
        ],
        postConditionMode: PostConditionMode.Allow,
        onFinish: (data) => {
          setTxId(data.txId);
          setLoading(false);
        },
        onCancel: () => setLoading(false),
      });
    } catch (error) {
      console.error(error);
      setLoading(false);
    }
  };

  const fundLoan = async () => {
    if (!loanId) return;
    setLoading(true);
    try {
      await openContractCall({
        network: STACKS_MAINNET,
        anchorMode: AnchorMode.Any,
        contractAddress: CONTRACT_ADDRESS,
        contractName: CONTRACT_NAME,
        functionName: "fund-loan",
        functionArgs: [uintCV(parseInt(loanId))],
        postConditionMode: PostConditionMode.Allow,
        onFinish: (data) => {
          setTxId(data.txId);
          setLoading(false);
        },
        onCancel: () => setLoading(false),
      });
    } catch (error) {
      console.error(error);
      setLoading(false);
    }
  };

  const repayLoan = async () => {
    if (!loanId) return;
    setLoading(true);
    try {
      await openContractCall({
        network: STACKS_MAINNET,
        anchorMode: AnchorMode.Any,
        contractAddress: CONTRACT_ADDRESS,
        contractName: CONTRACT_NAME,
        functionName: "repay-loan",
        functionArgs: [uintCV(parseInt(loanId))],
        postConditionMode: PostConditionMode.Allow,
        onFinish: (data) => {
          setTxId(data.txId);
          setLoading(false);
        },
        onCancel: () => setLoading(false),
      });
    } catch (error) {
      console.error(error);
      setLoading(false);
    }
  };

  return (
    <main className="min-h-screen bg-gradient-to-br from-indigo-900 to-purple-900 text-white p-8">
      <div className="max-w-xl mx-auto">
        <h1 className="text-4xl font-bold mb-2 text-center">🏦 P2P Lending</h1>
        <p className="text-center text-gray-300 mb-8">Borrow and lend STX peer-to-peer</p>

        {!address ? (
          <button onClick={connectWallet} className="w-full bg-indigo-500 hover:bg-indigo-600 py-3 rounded-lg font-semibold">
            Connect Wallet
          </button>
        ) : (
          <div className="space-y-6">
            <div className="bg-white/10 p-4 rounded-lg">
              <p className="font-mono text-sm">{address.slice(0, 12)}...{address.slice(-6)}</p>
            </div>

            <div className="bg-white/10 p-6 rounded-lg space-y-4">
              <h2 className="text-xl font-bold">Request Loan</h2>
              <input type="number" value={amount} onChange={(e) => setAmount(e.target.value)} placeholder="Amount (STX)" className="w-full bg-white/10 border border-white/20 rounded px-4 py-2" />
              <div className="grid grid-cols-2 gap-4">
                <input type="number" value={interest} onChange={(e) => setInterest(e.target.value)} placeholder="Interest %" className="bg-white/10 border border-white/20 rounded px-4 py-2" />
                <input type="number" value={duration} onChange={(e) => setDuration(e.target.value)} placeholder="Duration (blocks)" className="bg-white/10 border border-white/20 rounded px-4 py-2" />
              </div>
              <button onClick={requestLoan} disabled={loading} className="w-full bg-blue-600 hover:bg-blue-700 py-3 rounded-lg disabled:opacity-50">
                {loading ? "Requesting..." : "Request Loan"}
              </button>
            </div>

            <div className="bg-white/10 p-6 rounded-lg space-y-4">
              <h2 className="text-xl font-bold">Fund / Repay Loan</h2>
              <input type="number" value={loanId} onChange={(e) => setLoanId(e.target.value)} placeholder="Loan ID" className="w-full bg-white/10 border border-white/20 rounded px-4 py-2" />
              <div className="grid grid-cols-2 gap-4">
                <button onClick={fundLoan} disabled={loading} className="bg-green-600 hover:bg-green-700 py-3 rounded-lg disabled:opacity-50">Fund</button>
                <button onClick={repayLoan} disabled={loading} className="bg-purple-600 hover:bg-purple-700 py-3 rounded-lg disabled:opacity-50">Repay</button>
              </div>
            </div>

            {txId && (
              <div className="bg-green-500/20 border border-green-500 p-4 rounded-lg">
                <a href={`https://explorer.hiro.so/txid/${txId}?chain=mainnet`} target="_blank" className="text-green-300 underline break-all">View TX</a>
              </div>
            )}
          </div>
        )}
      </div>
    </main>
  );
}
