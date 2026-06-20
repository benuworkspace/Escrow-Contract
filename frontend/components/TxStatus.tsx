"use client";

import { shortHash } from "@/lib/utils";
import { CheckCircle, Clock, AlertCircle, Loader2 } from "lucide-react";

interface TxStatusProps {
  hash?: `0x${string}`;
  isPending: boolean;
  isConfirming: boolean;
  isSuccess: boolean;
  error?: Error | null;
  successMessage?: string;
}

export default function TxStatus({
  hash,
  isPending,
  isConfirming,
  isSuccess,
  error,
  successMessage = "Transaction confirmed!",
}: TxStatusProps) {
  if (!hash && !isPending && !error) return null;

  return (
    <div className="mt-3 space-y-2">

      {isPending && (
        <div className="flex items-center gap-2 text-yellow-400 text-sm">
          <Loader2 className="w-4 h-4 animate-spin" />
          <span>Waiting for wallet confirmation...</span>
        </div>
      )}

      {isConfirming && hash && (
        <div className="flex items-center gap-2 text-blue-400 text-sm">
          <Clock className="w-4 h-4 animate-pulse" />
          <span>Confirming on-chain... </span>
          <a
            href={`https://sepolia.etherscan.io/tx/${hash}`}
            target="_blank"
            rel="noopener noreferrer"
            className="underline hover:text-blue-300"
          >
            {shortHash(hash)}
          </a>
        </div>
      )}

      {isSuccess && (
        <div className="flex items-center gap-2 text-green-400 text-sm">
          <CheckCircle className="w-4 h-4" />
          <span>{successMessage}</span>
        </div>
      )}

      {error && (
        <div className="flex items-start gap-2 text-red-400 text-sm">
          <AlertCircle className="w-4 h-4 mt-0.5 shrink-0" />
          <span>
            {error.message.includes("User rejected")
              ? "Transaction rejected by user."
              : error.message.length > 100
              ? error.message.slice(0, 100) + "..."
              : error.message}
          </span>
        </div>
      )}

    </div>
  );
}