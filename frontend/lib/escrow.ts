export const ESCROW_ADDRESS =
  process.env.NEXT_PUBLIC_ESCROW_CONTRACT_ADDRESS as `0x${string}`;

export const ESCROW_ABI = [
  // createEscrow
  {
    name: "createEscrow",
    type: "function",
    stateMutability: "payable",
    inputs: [
      { name: "beneficiary", type: "address" },
      { name: "arbiter", type: "address" },
      { name: "token", type: "address" },
      { name: "amount", type: "uint256" },
      { name: "timelockDuration", type: "uint256" },
      { name: "arbiterFeeRate", type: "uint256" },
    ],
    outputs: [{ name: "escrowId", type: "uint256" }],
  },
  // confirmDelivery
  {
    name: "confirmDelivery",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [{ name: "escrowId", type: "uint256" }],
    outputs: [],
  },
  // timelockRelease
  {
    name: "timelockRelease",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [{ name: "escrowId", type: "uint256" }],
    outputs: [],
  },
  // raiseDispute
  {
    name: "raiseDispute",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [{ name: "escrowId", type: "uint256" }],
    outputs: [],
  },
  // resolveDispute
  {
    name: "resolveDispute",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "escrowId", type: "uint256" },
      { name: "releaseTobeneficiary", type: "bool" },
    ],
    outputs: [],
  },
  // getEscrow
  {
    name: "getEscrow",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "escrowId", type: "uint256" }],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "depositor", type: "address" },
          { name: "beneficiary", type: "address" },
          { name: "arbiter", type: "address" },
          { name: "token", type: "address" },
          { name: "amount", type: "uint256" },
          { name: "createdAt", type: "uint256" },
          { name: "timelockDuration", type: "uint256" },
          { name: "arbiterFeeRate", type: "uint256" },
          { name: "state", type: "uint8" },
          { name: "disputeRaisedBy", type: "address" },
          { name: "disputeRaisedAt", type: "uint256" },
        ],
      },
    ],
  },
  // isTimelockExpired
  {
    name: "isTimelockExpired",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "escrowId", type: "uint256" }],
    outputs: [{ name: "", type: "bool" }],
  },
  // timeUntilRelease
  {
    name: "timeUntilRelease",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "escrowId", type: "uint256" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  // escrowCount
  {
    name: "escrowCount",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
  // calculateArbiterFee
  {
    name: "calculateArbiterFee",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "escrowId", type: "uint256" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  // getDisputeInfo
  {
    name: "getDisputeInfo",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "escrowId", type: "uint256" }],
    outputs: [
      { name: "raisedBy", type: "address" },
      { name: "raisedAt", type: "uint256" },
      { name: "isActive", type: "bool" },
    ],
  },
  // Events
  {
    name: "EscrowCreated",
    type: "event",
    inputs: [
      { name: "escrowId", type: "uint256", indexed: true },
      { name: "depositor", type: "address", indexed: true },
      { name: "beneficiary", type: "address", indexed: true },
      { name: "arbiter", type: "address", indexed: false },
      { name: "token", type: "address", indexed: false },
      { name: "amount", type: "uint256", indexed: false },
      { name: "timelockDuration", type: "uint256", indexed: false },
      { name: "arbiterFeeRate", type: "uint256", indexed: false },
    ],
  },
  {
    name: "FundsReleased",
    type: "event",
    inputs: [
      { name: "escrowId", type: "uint256", indexed: true },
      { name: "beneficiary", type: "address", indexed: true },
      { name: "amount", type: "uint256", indexed: false },
    ],
  },
  {
    name: "DisputeRaised",
    type: "event",
    inputs: [
      { name: "escrowId", type: "uint256", indexed: true },
      { name: "raisedBy", type: "address", indexed: true },
    ],
  },
] as const;

// Helper: state enum ke string
export const ESCROW_STATES = [
  "Awaiting Delivery",
  "Complete",
  "Refunded",
  "In Dispute",
] as const;

export type EscrowState = (typeof ESCROW_STATES)[number];

// Helper: format timelock duration ke opsi yang user-friendly
export const TIMELOCK_OPTIONS = [
  { label: "1 Day", value: 86400 },
  { label: "3 Days", value: 259200 },
  { label: "7 Days", value: 604800 },
  { label: "14 Days", value: 1209600 },
  { label: "30 Days", value: 2592000 },
] as const;