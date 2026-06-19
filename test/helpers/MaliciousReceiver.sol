// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../../src/EscrowV2.sol";

/**
 * @title MaliciousReceiver
 * @author Absalom Benu | Bukit Digital Nusantara
 * @dev Contract untuk test reentrancy attack pada EscrowV2
 *      Simulasi arbiter atau beneficiary yang mencoba re-enter
 */
contract MaliciousReceiver {
    EscrowV2 public target;
    uint256 public targetEscrowId;
    uint256 public attackCount;
    bool public attackEnabled;

    event AttackAttempted(uint256 count, bool success);

    constructor(address _target) {
        target = EscrowV2(_target);
    }

    function enableAttack(uint256 escrowId) external {
        targetEscrowId = escrowId;
        attackEnabled = true;
    }

    // Dipanggil otomatis saat menerima ETH
    receive() external payable {
        if (attackEnabled && attackCount < 3) {
            attackCount++;
            // Coba re-enter resolveDispute
            try target.resolveDispute(targetEscrowId, true) {
                emit AttackAttempted(attackCount, true);
            } catch {
                emit AttackAttempted(attackCount, false);
            }
        }
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}