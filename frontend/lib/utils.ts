import { formatEther } from "viem";

// Format address jadi short form
export function shortAddress(address: string): string {
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

// Format ETH amount
export function formatETH(wei: bigint): string {
  return `${parseFloat(formatEther(wei)).toFixed(4)} ETH`;
}

// Format timestamp ke human readable
export function formatDate(timestamp: bigint): string {
  return new Date(Number(timestamp) * 1000).toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

// Format seconds ke countdown string
export function formatCountdown(seconds: bigint): string {
  const total = Number(seconds);
  if (total <= 0) return "Expired";

  const days = Math.floor(total / 86400);
  const hours = Math.floor((total % 86400) / 3600);
  const minutes = Math.floor((total % 3600) / 60);

  if (days > 0) return `${days}d ${hours}h remaining`;
  if (hours > 0) return `${hours}h ${minutes}m remaining`;
  return `${minutes}m remaining`;
}

// Format arbiter fee rate ke percentage
export function formatFeeRate(basisPoints: bigint): string {
  return `${(Number(basisPoints) / 100).toFixed(1)}%`;
}

// Truncate tx hash
export function shortHash(hash: string): string {
  return `${hash.slice(0, 10)}...${hash.slice(-8)}`;
}