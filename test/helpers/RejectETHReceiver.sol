// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract RejectETHReceiver {

    receive() external payable {
        revert("Reject ETH");
    }
}