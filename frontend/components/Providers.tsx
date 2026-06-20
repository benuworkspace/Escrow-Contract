"use client";

import { useState } from "react";

import { WagmiProvider } from "wagmi";
import { RainbowKitProvider } from "@rainbow-me/rainbowkit";

import {
  QueryClient,
  QueryClientProvider,
} from "@tanstack/react-query";

import { config } from "@/lib/wagmi";


export default function Providers({
  children,
}: {
  children: React.ReactNode;
}) {

  const [queryClient] = useState(
    () => new QueryClient()
  );


  return (
    <WagmiProvider config={config}>

      <QueryClientProvider client={queryClient}>

        <RainbowKitProvider>

          {children}

        </RainbowKitProvider>

      </QueryClientProvider>

    </WagmiProvider>
  );
}