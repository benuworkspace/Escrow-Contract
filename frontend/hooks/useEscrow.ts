"use client";

import { useReadContract, useWriteContract,
         useWaitForTransactionReceipt } from "wagmi";
import { parseEther } from "viem";
import { ESCROW_ADDRESS, ESCROW_ABI } from "@/lib/escrow";

// ── Read Hooks ──────────────────────────────────

export function useEscrowData(escrowId: bigint | undefined) {
  return useReadContract({
    address: ESCROW_ADDRESS,
    abi: ESCROW_ABI,
    functionName: "getEscrow",
    args: escrowId !== undefined ? [escrowId] : undefined,
    query: { enabled: escrowId !== undefined },
  });
}

export function useEscrowCount() {
  return useReadContract({
    address: ESCROW_ADDRESS,
    abi: ESCROW_ABI,
    functionName: "escrowCount",
  });
}

export function useTimelockExpired(escrowId: bigint | undefined) {
  return useReadContract({
    address: ESCROW_ADDRESS,
    abi: ESCROW_ABI,
    functionName: "isTimelockExpired",
    args: escrowId !== undefined ? [escrowId] : undefined,
    query: { enabled: escrowId !== undefined },
  });
}

export function useTimeUntilRelease(escrowId: bigint | undefined) {
  return useReadContract({
    address: ESCROW_ADDRESS,
    abi: ESCROW_ABI,
    functionName: "timeUntilRelease",
    args: escrowId !== undefined ? [escrowId] : undefined,
    query: { enabled: escrowId !== undefined },
  });
}

export function useArbiterFee(escrowId: bigint | undefined) {
  return useReadContract({
    address: ESCROW_ADDRESS,
    abi: ESCROW_ABI,
    functionName: "calculateArbiterFee",
    args: escrowId !== undefined ? [escrowId] : undefined,
    query: { enabled: escrowId !== undefined },
  });
}

// ── Write Hooks ─────────────────────────────────

export function useCreateEscrow() {
  const { writeContract, data: hash, isPending, error } =
    useWriteContract();

  const { isLoading: isConfirming, isSuccess } =
    useWaitForTransactionReceipt({ hash });

  const createEscrow = (
    beneficiary: `0x${string}`,
    arbiter: `0x${string}`,
    ethAmount: string,
    timelockDuration: number,
    arbiterFeeRate: number
  ) => {
    writeContract({
      address: ESCROW_ADDRESS,
      abi: ESCROW_ABI,
      functionName: "createEscrow",
      args: [
        beneficiary,
        arbiter,
        "0x0000000000000000000000000000000000000000", // ETH
        BigInt(0),
        BigInt(timelockDuration),
        BigInt(arbiterFeeRate),
      ],
      value: parseEther(ethAmount),
    });
  };

  return {
    createEscrow,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  };
}

export function useConfirmDelivery() {
  const { writeContract, data: hash, isPending, error } =
    useWriteContract();

  const { isLoading: isConfirming, isSuccess } =
    useWaitForTransactionReceipt({ hash });

  const confirmDelivery = (escrowId: bigint) => {
    writeContract({
      address: ESCROW_ADDRESS,
      abi: ESCROW_ABI,
      functionName: "confirmDelivery",
      args: [escrowId],
    });
  };

  return { confirmDelivery, hash, isPending, isConfirming, isSuccess, error };
}

export function useRaiseDispute() {
  const { writeContract, data: hash, isPending, error } =
    useWriteContract();

  const { isLoading: isConfirming, isSuccess } =
    useWaitForTransactionReceipt({ hash });

  const raiseDispute = (escrowId: bigint) => {
    writeContract({
      address: ESCROW_ADDRESS,
      abi: ESCROW_ABI,
      functionName: "raiseDispute",
      args: [escrowId],
    });
  };

  return { raiseDispute, hash, isPending, isConfirming, isSuccess, error };
}

export function useTimelockRelease() {
  const { writeContract, data: hash, isPending, error } =
    useWriteContract();

  const { isLoading: isConfirming, isSuccess } =
    useWaitForTransactionReceipt({ hash });

  const timelockRelease = (escrowId: bigint) => {
    writeContract({
      address: ESCROW_ADDRESS,
      abi: ESCROW_ABI,
      functionName: "timelockRelease",
      args: [escrowId],
    });
  };

  return { timelockRelease, hash, isPending, isConfirming, isSuccess, error };
}

export function useResolveDispute() {
  const { writeContract, data: hash, isPending, error } =
    useWriteContract();

  const { isLoading: isConfirming, isSuccess } =
    useWaitForTransactionReceipt({ hash });

  const resolveDispute = (
    escrowId: bigint,
    releaseTobeneficiary: boolean
  ) => {
    writeContract({
      address: ESCROW_ADDRESS,
      abi: ESCROW_ABI,
      functionName: "resolveDispute",
      args: [escrowId, releaseTobeneficiary],
    });
  };

  return { resolveDispute, hash, isPending, isConfirming, isSuccess, error };
}