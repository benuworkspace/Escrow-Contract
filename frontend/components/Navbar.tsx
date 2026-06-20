"use client";

import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useAccount } from "wagmi";
import { Shield } from "lucide-react";

export default function Navbar() {
  const { isConnected, chain } = useAccount();

  return (
    <nav className="border-b border-gray-800 bg-gray-950 px-6 py-4">
      <div className="max-w-6xl mx-auto flex items-center justify-between">

        {/* Logo */}
        <div className="flex items-center gap-2">
          <Shield className="w-6 h-6 text-blue-400" />
          <span className="text-white font-semibold text-lg">
            EscrowV2
          </span>
        </div>

        {/* Network indicator + Connect Button */}
        <div className="flex items-center gap-3">
          {isConnected && chain && (
            <span className={`
              text-xs px-2 py-1 rounded-full font-medium
              ${chain.id === 11155111
                ? "bg-purple-900 text-purple-300"
                : "bg-red-900 text-red-300"
              }
            `}>
              {chain.name}
            </span>
          )}
          <ConnectButton
            accountStatus="avatar"
            showBalance={false}
          />
        </div>

      </div>
    </nav>
  );
}