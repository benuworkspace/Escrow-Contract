"use client";

import { useAccount } from "wagmi";
import { formatETH, shortAddress, formatDate,
         formatCountdown, formatFeeRate } from "@/lib/utils";
import {
  useConfirmDelivery,
  useRaiseDispute,
  useTimelockRelease,
  useResolveDispute,
  useTimelockExpired,
  useTimeUntilRelease,
} from "@/hooks/useEscrow";
import StatusBadge from "./StatusBadge";
import TxStatus from "./TxStatus";
import {
  Clock, User, Shield, AlertTriangle,
  CheckCircle, RotateCcw, Zap, ExternalLink
} from "lucide-react";

interface EscrowCardProps {
  escrowId: bigint;
  data: {
    depositor: `0x${string}`;
    beneficiary: `0x${string}`;
    arbiter: `0x${string}`;
    token: `0x${string}`;
    amount: bigint;
    createdAt: bigint;
    timelockDuration: bigint;
    arbiterFeeRate: bigint;
    state: number;
    disputeRaisedBy: `0x${string}`;
    disputeRaisedAt: bigint;
  };
  onRefresh?: () => void;
}

export default function EscrowCard({
  escrowId,
  data,
  onRefresh,
}: EscrowCardProps) {
  const { address } = useAccount();

  const { data: isExpired } = useTimelockExpired(escrowId);
  const { data: timeLeft } = useTimeUntilRelease(escrowId);

  const confirmDelivery = useConfirmDelivery();
  const raiseDispute = useRaiseDispute();
  const timelockRelease = useTimelockRelease();
  const resolveDispute = useResolveDispute();

  const isDepositor = address?.toLowerCase() ===
    data.depositor.toLowerCase();
  const isBeneficiary = address?.toLowerCase() ===
    data.beneficiary.toLowerCase();
  const isArbiter = address?.toLowerCase() ===
    data.arbiter.toLowerCase();
  const isParty = isDepositor || isBeneficiary;

  const isAwaiting = data.state === 0;
  const isInDispute = data.state === 3;
  const isFinished = data.state === 1 || data.state === 2;

  // Handle success refresh
  const handleSuccess = (hook: { isSuccess: boolean }) => {
    if (hook.isSuccess && onRefresh) {
      setTimeout(onRefresh, 2000);
    }
  };

  handleSuccess(confirmDelivery);
  handleSuccess(raiseDispute);
  handleSuccess(timelockRelease);
  handleSuccess(resolveDispute);

  return (
    <div className="bg-gray-900 border border-gray-800 rounded-xl p-5
      hover:border-gray-700 transition-colors">

      {/* Header */}
      <div className="flex items-start justify-between mb-4">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <span className="text-gray-500 text-xs font-mono">
              #{escrowId.toString()}
            </span>
            <StatusBadge state={data.state} />
          </div>
          <div className="text-white font-semibold text-xl">
            {formatETH(data.amount)}
          </div>
        </div>

        {/* Etherscan link */}
        <a
          href={`https://sepolia.etherscan.io/address/${
            process.env.NEXT_PUBLIC_ESCROW_CONTRACT_ADDRESS
          }`}
          target="_blank"
          rel="noopener noreferrer"
          className="text-gray-600 hover:text-gray-400 transition-colors"
        >
          <ExternalLink className="w-4 h-4" />
        </a>
      </div>

      {/* Parties */}
      <div className="space-y-2 mb-4">
        <div className="flex items-center justify-between text-sm">
          <div className="flex items-center gap-1.5 text-gray-500">
            <User className="w-3.5 h-3.5" />
            <span>Depositor</span>
          </div>
          <span className={`font-mono text-xs ${
            isDepositor ? "text-blue-400" : "text-gray-400"
          }`}>
            {shortAddress(data.depositor)}
            {isDepositor && (
              <span className="ml-1 text-blue-600">(you)</span>
            )}
          </span>
        </div>

        <div className="flex items-center justify-between text-sm">
          <div className="flex items-center gap-1.5 text-gray-500">
            <User className="w-3.5 h-3.5" />
            <span>Beneficiary</span>
          </div>
          <span className={`font-mono text-xs ${
            isBeneficiary ? "text-green-400" : "text-gray-400"
          }`}>
            {shortAddress(data.beneficiary)}
            {isBeneficiary && (
              <span className="ml-1 text-green-600">(you)</span>
            )}
          </span>
        </div>

        <div className="flex items-center justify-between text-sm">
          <div className="flex items-center gap-1.5 text-gray-500">
            <Shield className="w-3.5 h-3.5" />
            <span>Arbiter</span>
          </div>
          <span className={`font-mono text-xs ${
            isArbiter ? "text-purple-400" : "text-gray-400"
          }`}>
            {shortAddress(data.arbiter)}
            {isArbiter && (
              <span className="ml-1 text-purple-600">(you)</span>
            )}
          </span>
        </div>
      </div>

      {/* Timelock Info */}
      {isAwaiting && (
        <div className={`
          flex items-center gap-2 text-xs px-3 py-2 rounded-lg mb-4
          ${isExpired
            ? "bg-green-900/30 text-green-400 border border-green-800"
            : "bg-gray-800 text-gray-400"
          }
        `}>
          <Clock className="w-3.5 h-3.5 shrink-0" />
          <span>
            {isExpired
              ? "Timelock expired — ready for release"
              : timeLeft
              ? formatCountdown(timeLeft)
              : "Loading..."}
          </span>
        </div>
      )}

      {/* Dispute Info */}
      {isInDispute && data.disputeRaisedBy !==
        "0x0000000000000000000000000000000000000000" && (
        <div className="flex items-center gap-2 text-xs px-3 py-2
          rounded-lg mb-4 bg-red-900/30 text-red-400 border border-red-800">
          <AlertTriangle className="w-3.5 h-3.5 shrink-0" />
          <span>
            Dispute raised by {shortAddress(data.disputeRaisedBy)} on{" "}
            {formatDate(data.disputeRaisedAt)}
          </span>
        </div>
      )}

      {/* Fee info */}
      {data.arbiterFeeRate > 0n && (
        <div className="text-xs text-gray-600 mb-4">
          Arbiter fee: {formatFeeRate(data.arbiterFeeRate)} if disputed
        </div>
      )}

      {/* Actions */}
      {!isFinished && (
        <div className="space-y-2 pt-4 border-t border-gray-800">

          {/* Depositor actions */}
          {isDepositor && isAwaiting && (
            <button
              onClick={() => confirmDelivery.confirmDelivery(escrowId)}
              disabled={confirmDelivery.isPending ||
                confirmDelivery.isConfirming}
              className="w-full flex items-center justify-center gap-2
                py-2 rounded-lg bg-green-700 hover:bg-green-600
                text-white text-sm font-medium transition-colors
                disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <CheckCircle className="w-4 h-4" />
              Confirm Delivery
            </button>
          )}

          {/* Party actions — raise dispute */}
          {isParty && isAwaiting && !isExpired && (
            <button
              onClick={() => raiseDispute.raiseDispute(escrowId)}
              disabled={raiseDispute.isPending ||
                raiseDispute.isConfirming}
              className="w-full flex items-center justify-center gap-2
                py-2 rounded-lg bg-red-900 hover:bg-red-800
                text-red-300 text-sm font-medium transition-colors
                disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <AlertTriangle className="w-4 h-4" />
              Raise Dispute
            </button>
          )}

          {/* Timelock release — anyone */}
          {isAwaiting && isExpired && (
            <button
              onClick={() => timelockRelease.timelockRelease(escrowId)}
              disabled={timelockRelease.isPending ||
                timelockRelease.isConfirming}
              className="w-full flex items-center justify-center gap-2
                py-2 rounded-lg bg-blue-700 hover:bg-blue-600
                text-white text-sm font-medium transition-colors
                disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <Zap className="w-4 h-4" />
              Release Funds (Timelock Expired)
            </button>
          )}

          {/* Arbiter actions */}
          {isArbiter && isInDispute && (
            <div className="space-y-2">
              <p className="text-xs text-gray-500 text-center">
                Resolve dispute as arbiter:
              </p>
              <div className="grid grid-cols-2 gap-2">
                <button
                  onClick={() =>
                    resolveDispute.resolveDispute(escrowId, true)
                  }
                  disabled={resolveDispute.isPending ||
                    resolveDispute.isConfirming}
                  className="flex items-center justify-center gap-1.5
                    py-2 rounded-lg bg-green-800 hover:bg-green-700
                    text-green-300 text-xs font-medium transition-colors
                    disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <CheckCircle className="w-3.5 h-3.5" />
                  Release to Seller
                </button>
                <button
                  onClick={() =>
                    resolveDispute.resolveDispute(escrowId, false)
                  }
                  disabled={resolveDispute.isPending ||
                    resolveDispute.isConfirming}
                  className="flex items-center justify-center gap-1.5
                    py-2 rounded-lg bg-gray-700 hover:bg-gray-600
                    text-gray-300 text-xs font-medium transition-colors
                    disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <RotateCcw className="w-3.5 h-3.5" />
                  Refund Buyer
                </button>
              </div>
            </div>
          )}

          {/* TX Status untuk semua actions */}
          <TxStatus
            hash={confirmDelivery.hash ||
              raiseDispute.hash ||
              timelockRelease.hash ||
              resolveDispute.hash}
            isPending={confirmDelivery.isPending ||
              raiseDispute.isPending ||
              timelockRelease.isPending ||
              resolveDispute.isPending}
            isConfirming={confirmDelivery.isConfirming ||
              raiseDispute.isConfirming ||
              timelockRelease.isConfirming ||
              resolveDispute.isConfirming}
            isSuccess={confirmDelivery.isSuccess ||
              raiseDispute.isSuccess ||
              timelockRelease.isSuccess ||
              resolveDispute.isSuccess}
            error={confirmDelivery.error ||
              raiseDispute.error ||
              timelockRelease.error ||
              resolveDispute.error}
          />
        </div>
      )}

      {/* Completed state */}
      {isFinished && (
        <div className="pt-4 border-t border-gray-800">
          <div className="text-xs text-gray-600 text-center">
            {data.state === 1
              ? "✅ Funds released to beneficiary"
              : "↩️ Funds refunded to depositor"}
          </div>
        </div>
      )}
    </div>
  );
}