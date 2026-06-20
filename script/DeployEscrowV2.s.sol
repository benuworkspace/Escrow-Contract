// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {EscrowV2} from "../src/EscrowV2.sol";

contract DeployEscrowV2 is Script {

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=============================================================================");
        console.log("                       DEPLOYING ESCROWV2 TO SEPOLIA                         ");
        console.log("=============================================================================");
        console.log("Deployer        :", deployer);
        console.log("Deployer balance:",
            deployer.balance / 1e18, "ETH"
        );
        console.log("=============================================================================");

        vm.startBroadcast(deployerPrivateKey);

        EscrowV2 escrow = new EscrowV2();

        vm.stopBroadcast();

        console.log("=============================================================================");
        console.log("                           DEPLOYMENT SUCCESSFUL                             ");
        console.log("=============================================================================");
        console.log("EscrowV2 address:", address(escrow));
        console.log("Block number    :", block.number);
        console.log("=============================================================================");
        console.log("");
        console.log("Next steps:");
        console.log("1. Verify on Etherscan:");
        console.log("   forge verify-contract", address(escrow),
            "src/EscrowV2.sol:EscrowV2 --chain sepolia"
        );
        console.log("2. Update .env NEXT_PUBLIC_ESCROW_CONTRACT_ADDRESS");
        console.log("3. Update frontend and redeploy to Vercel");
        console.log("=============================================================================");
    }
}