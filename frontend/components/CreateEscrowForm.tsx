"use client";

import { useState } from "react";
import { useAccount } from "wagmi";
import { isAddress } from "viem";
import { useCreateEscrow } from "@/hooks/useEscrow";
import { TIMELOCK_OPTIONS } from "@/lib/escrow";
import TxStatus from "./TxStatus";
import { PlusCircle, Info } from "lucide-react";

export default function CreateEscrowForm({
  onSuccess,
}: {
  onSuccess?: () => void;
}) {
  const { isConnected } = useAccount();

  const [form, setForm] = useState({
    beneficiary: "",
    arbiter: "",
    ethAmount: "",
    timelockDuration: TIMELOCK_OPTIONS[2].value, // 7 days default
    arbiterFeeRate: 200, // 2% default
  });

  const [errors, setErrors] = useState<Record<string, string>>({});

  const {
    createEscrow,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  } = useCreateEscrow();

  // Validate form
  const validate = (): boolean => {
    const newErrors: Record<string, string> = {};

    if (!isAddress(form.beneficiary)) {
      newErrors.beneficiary = "Invalid Ethereum address";
    }
    if (!isAddress(form.arbiter)) {
      newErrors.arbiter = "Invalid Ethereum address";
    }
    if (form.beneficiary === form.arbiter) {
      newErrors.arbiter = "Arbiter cannot be same as beneficiary";
    }
    if (!form.ethAmount || parseFloat(form.ethAmount) <= 0) {
      newErrors.ethAmount = "Amount must be greater than 0";
    }
    if (parseFloat(form.ethAmount) < 0.001) {
      newErrors.ethAmount = "Minimum amount is 0.001 ETH";
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = () => {
    if (!validate()) return;

    createEscrow(
      form.beneficiary as `0x${string}`,
      form.arbiter as `0x${string}`,
      form.ethAmount,
      form.timelockDuration,
      form.arbiterFeeRate
    );
  };

  // Call onSuccess after confirmed
  if (isSuccess && onSuccess) {
    setTimeout(onSuccess, 2000);
  }

  if (!isConnected) {
    return (
      <div className="text-center py-8 text-gray-500">
        Connect your wallet to create an escrow
      </div>
    );
  }

  return (
    <div className="bg-gray-900 border border-gray-800 rounded-xl p-6">
      <h2 className="text-white font-semibold text-lg mb-6 flex items-center gap-2">
        <PlusCircle className="w-5 h-5 text-blue-400" />
        Create New Escrow
      </h2>

      <div className="space-y-4">

        {/* Beneficiary */}
        <div>
          <label className="block text-sm text-gray-400 mb-1">
            Beneficiary Address
            <span className="text-gray-600 ml-1">(seller / freelancer)</span>
          </label>
          <input
            type="text"
            placeholder="0x..."
            value={form.beneficiary}
            onChange={(e) =>
              setForm({ ...form, beneficiary: e.target.value })
            }
            className={`
              w-full bg-gray-800 border rounded-lg px-4 py-2.5
              text-white placeholder-gray-600 text-sm
              focus:outline-none focus:ring-1 focus:ring-blue-500
              ${errors.beneficiary
                ? "border-red-500"
                : "border-gray-700"
              }
            `}
          />
          {errors.beneficiary && (
            <p className="text-red-400 text-xs mt-1">{errors.beneficiary}</p>
          )}
        </div>

        {/* Arbiter */}
        <div>
          <label className="block text-sm text-gray-400 mb-1">
            Arbiter Address
            <span className="text-gray-600 ml-1">(trusted third party)</span>
          </label>
          <input
            type="text"
            placeholder="0x..."
            value={form.arbiter}
            onChange={(e) =>
              setForm({ ...form, arbiter: e.target.value })
            }
            className={`
              w-full bg-gray-800 border rounded-lg px-4 py-2.5
              text-white placeholder-gray-600 text-sm
              focus:outline-none focus:ring-1 focus:ring-blue-500
              ${errors.arbiter
                ? "border-red-500"
                : "border-gray-700"
              }
            `}
          />
          {errors.arbiter && (
            <p className="text-red-400 text-xs mt-1">{errors.arbiter}</p>
          )}
        </div>

        {/* ETH Amount */}
        <div>
          <label className="block text-sm text-gray-400 mb-1">
            Amount (ETH)
          </label>
          <div className="relative">
            <input
              type="number"
              step="0.001"
              min="0.001"
              placeholder="0.00"
              value={form.ethAmount}
              onChange={(e) =>
                setForm({ ...form, ethAmount: e.target.value })
              }
              className={`
                w-full bg-gray-800 border rounded-lg px-4 py-2.5
                text-white placeholder-gray-600 text-sm pr-16
                focus:outline-none focus:ring-1 focus:ring-blue-500
                ${errors.ethAmount
                  ? "border-red-500"
                  : "border-gray-700"
                }
              `}
            />
            <span className="absolute right-4 top-1/2 -translate-y-1/2
              text-gray-500 text-sm font-medium">
              ETH
            </span>
          </div>
          {errors.ethAmount && (
            <p className="text-red-400 text-xs mt-1">{errors.ethAmount}</p>
          )}
        </div>

        {/* Timelock Duration */}
        <div>
          <label className="block text-sm text-gray-400 mb-1">
            Timelock Duration
          </label>
          <select
            value={form.timelockDuration}
            onChange={(e) =>
              setForm({
                ...form,
                timelockDuration: Number(e.target.value),
              })
            }
            className="w-full bg-gray-800 border border-gray-700
              rounded-lg px-4 py-2.5 text-white text-sm
              focus:outline-none focus:ring-1 focus:ring-blue-500"
          >
            {TIMELOCK_OPTIONS.map((opt) => (
              <option key={opt.value} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>
        </div>

        {/* Arbiter Fee Rate */}
        <div>
          <label className="block text-sm text-gray-400 mb-1">
            Arbiter Fee Rate
            <span className="text-gray-600 ml-1">
              ({(form.arbiterFeeRate / 100).toFixed(1)}%)
            </span>
          </label>
          <input
            type="range"
            min="0"
            max="1000"
            step="50"
            value={form.arbiterFeeRate}
            onChange={(e) =>
              setForm({
                ...form,
                arbiterFeeRate: Number(e.target.value),
              })
            }
            className="w-full accent-blue-500"
          />
          <div className="flex justify-between text-xs text-gray-600 mt-1">
            <span>0%</span>
            <span>5%</span>
            <span>10%</span>
          </div>
        </div>

        {/* Info Box */}
        <div className="flex gap-2 bg-gray-800 rounded-lg p-3 text-xs
          text-gray-400">
          <Info className="w-4 h-4 shrink-0 mt-0.5 text-blue-400" />
          <div>
            After the timelock expires, funds are automatically
            released to the beneficiary if no dispute is raised.
            Arbiter fee only applies if a dispute is resolved.
          </div>
        </div>

        {/* Submit */}
        <button
          onClick={handleSubmit}
          disabled={isPending || isConfirming}
          className={`
            w-full py-3 rounded-lg font-medium text-sm transition-all
            ${isPending || isConfirming
              ? "bg-gray-700 text-gray-500 cursor-not-allowed"
              : "bg-blue-600 hover:bg-blue-500 text-white cursor-pointer"
            }
          `}
        >
          {isPending
            ? "Confirm in Wallet..."
            : isConfirming
            ? "Creating Escrow..."
            : "Create Escrow"}
        </button>

        <TxStatus
          hash={hash}
          isPending={isPending}
          isConfirming={isConfirming}
          isSuccess={isSuccess}
          error={error}
          successMessage="Escrow created successfully!"
        />
      </div>
    </div>
  );
}