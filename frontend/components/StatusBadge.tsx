import { ESCROW_STATES } from "@/lib/escrow";
import clsx from "clsx";

interface StatusBadgeProps {
  state: number;
}

const STATE_STYLES = {
  0: "bg-yellow-900 text-yellow-300 border-yellow-700", // Awaiting
  1: "bg-green-900 text-green-300 border-green-700",    // Complete
  2: "bg-gray-800 text-gray-300 border-gray-600",       // Refunded
  3: "bg-red-900 text-red-300 border-red-700",          // In Dispute
} as const;

export default function StatusBadge({ state }: StatusBadgeProps) {
  return (
    <span className={clsx(
      "text-xs px-2 py-1 rounded-full border font-medium",
      STATE_STYLES[state as keyof typeof STATE_STYLES]
    )}>
      {ESCROW_STATES[state]}
    </span>
  );
}