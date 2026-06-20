"use client";

import { useState, useCallback } from "react";
import { useAccount } from "wagmi";
import { useEscrowCount, useEscrowData } from "@/hooks/useEscrow";
import Navbar from "@/components/Navbar";
import CreateEscrowForm from "@/components/CreateEscrowForm";
import EscrowCard from "@/components/EscrowCard";
import { Shield, PlusCircle, List } from "lucide-react";

// Component untuk load single escrow
function EscrowItem({
  escrowId,
  onRefresh,
}: {
  escrowId: bigint;
  onRefresh: () => void;
}) {
  const { data, isLoading } = useEscrowData(escrowId);

  if (isLoading) {
    return (
      <div className="bg-gray-900 border border-gray-800 rounded-xl
        p-5 animate-pulse">
        <div className="h-4 bg-gray-800 rounded w-1/3 mb-3" />
        <div className="h-8 bg-gray-800 rounded w-1/2 mb-4" />
        <div className="space-y-2">
          <div className="h-3 bg-gray-800 rounded" />
          <div className="h-3 bg-gray-800 rounded" />
          <div className="h-3 bg-gray-800 rounded" />
        </div>
      </div>
    );
  }

  if (!data) return null;

  return (
    <EscrowCard
      escrowId={escrowId}
      data={data}
      onRefresh={onRefresh}
    />
  );
}

export default function Home() {
  const { isConnected } = useAccount();
  const [activeTab, setActiveTab] = useState<"dashboard" | "create">(
    "dashboard"
  );
  const [refreshKey, setRefreshKey] = useState(0);

  const { data: escrowCount, refetch } = useEscrowCount();

  const handleRefresh = useCallback(() => {
    setRefreshKey((k) => k + 1);
    refetch();
  }, [refetch]);

  // Generate array of escrow IDs
  const escrowIds = escrowCount
    ? Array.from(
        { length: Number(escrowCount) },
        (_, i) => BigInt(Number(escrowCount) - 1 - i) // newest first
      )
    : [];

  return (
    <div className="min-h-screen bg-gray-950">
      <Navbar />

      <main className="max-w-6xl mx-auto px-6 py-8">

        {/* Hero */}
        <div className="text-center mb-10">
          <div className="flex items-center justify-center gap-3 mb-3">
            <Shield className="w-8 h-8 text-blue-400" />
            <h1 className="text-3xl font-bold text-white">
              Escrow Protocol
            </h1>
          </div>
          <p className="text-gray-500 max-w-md mx-auto text-sm">
            Trustless escrow with timelock, dispute resolution,
            and arbiter fee mechanism. Built on Ethereum Sepolia.
          </p>
        </div>

        {!isConnected ? (
          // Not connected state
          <div className="text-center py-20">
            <Shield className="w-12 h-12 text-gray-700 mx-auto mb-4" />
            <p className="text-gray-500 mb-2">
              Connect your wallet to get started
            </p>
            <p className="text-gray-700 text-sm">
              Supports MetaMask, WalletConnect, and more
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">

            {/* Left: Create Form (always visible on desktop) */}
            <div className="lg:col-span-1">

              {/* Mobile tabs */}
              <div className="flex lg:hidden mb-4 bg-gray-900
                rounded-lg p-1 border border-gray-800">
                <button
                  onClick={() => setActiveTab("dashboard")}
                  className={`flex-1 py-2 rounded-md text-sm
                    font-medium transition-colors flex items-center
                    justify-center gap-1.5
                    ${activeTab === "dashboard"
                      ? "bg-gray-800 text-white"
                      : "text-gray-500"
                    }`}
                >
                  <List className="w-4 h-4" />
                  Dashboard
                </button>
                <button
                  onClick={() => setActiveTab("create")}
                  className={`flex-1 py-2 rounded-md text-sm
                    font-medium transition-colors flex items-center
                    justify-center gap-1.5
                    ${activeTab === "create"
                      ? "bg-gray-800 text-white"
                      : "text-gray-500"
                    }`}
                >
                  <PlusCircle className="w-4 h-4" />
                  Create
                </button>
              </div>

              <div className={
                activeTab === "create" ? "block" : "hidden lg:block"
              }>
                <CreateEscrowForm
                  onSuccess={handleRefresh}
                />
              </div>
            </div>

            {/* Right: Escrow List */}
            <div className={`lg:col-span-2 ${
              activeTab === "dashboard" ? "block" : "hidden lg:block"
            }`}>

              {/* Stats bar */}
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-white font-semibold flex items-center
                  gap-2">
                  <List className="w-4 h-4 text-gray-500" />
                  All Escrows
                  {escrowCount !== undefined && (
                    <span className="text-gray-600 text-sm font-normal">
                      ({escrowCount.toString()} total)
                    </span>
                  )}
                </h2>
                <button
                  onClick={handleRefresh}
                  className="text-xs text-gray-600 hover:text-gray-400
                    transition-colors"
                >
                  Refresh
                </button>
              </div>

              {/* Escrow grid */}
              {escrowIds.length === 0 ? (
                <div className="text-center py-16 border border-gray-800
                  rounded-xl">
                  <Shield className="w-10 h-10 text-gray-800 mx-auto mb-3" />
                  <p className="text-gray-600">No escrows yet</p>
                  <p className="text-gray-700 text-sm mt-1">
                    Create your first escrow to get started
                  </p>
                </div>
              ) : (
                <div
                  key={refreshKey}
                  className="grid grid-cols-1 md:grid-cols-2 gap-4"
                >
                  {escrowIds.map((id) => (
                    <EscrowItem
                      key={id.toString()}
                      escrowId={id}
                      onRefresh={handleRefresh}
                    />
                  ))}
                </div>
              )}
            </div>

          </div>
        )}
      </main>
    </div>
  );
}