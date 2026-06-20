// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {EscrowV2} from "../src/EscrowV2.sol";
import {MaliciousReceiver} from "./helpers/MaliciousReceiver.sol";
import {RejectETHReceiver} from "./helpers/RejectETHReceiver.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract EscrowV2Test is Test {

    EscrowV2 public escrow;
    ERC20Mock public token;

    address public depositor = makeAddr("depositor");
    address public beneficiary = makeAddr("beneficiary");
    address public arbiter = makeAddr("arbiter");
    address public stranger = makeAddr("stranger");

    uint256 public constant ETH_AMOUNT = 1 ether;
    uint256 public constant TOKEN_AMOUNT = 1000e18;
    uint256 public constant TIMELOCK = 7 days;
    uint256 public constant ARBITER_FEE = 200; // 2%

    // ---------------------------------------------
    // SETUP
    // ---------------------------------------------

    function setUp() public {
        escrow = new EscrowV2();
        token = new ERC20Mock();

        vm.deal(depositor, 100 ether);
        token.mint(depositor, TOKEN_AMOUNT * 10);
    }

    // ---------------------------------------------
    // HELPER FUNCTIONS
    // ---------------------------------------------

    function _createETHEscrow() internal returns (uint256 escrowId) {
        vm.prank(depositor);
        escrowId = escrow.createEscrow{value: ETH_AMOUNT}(
            beneficiary,
            arbiter,
            address(0), // ETH
            0,
            TIMELOCK,
            ARBITER_FEE
        );
    }

    function _createTokenEscrow() internal returns (uint256 escrowId) {
        vm.startPrank(depositor);
        token.approve(address(escrow), TOKEN_AMOUNT);
        escrowId = escrow.createEscrow(
            beneficiary,
            arbiter,
            address(token),
            TOKEN_AMOUNT,
            TIMELOCK,
            ARBITER_FEE
        );
        vm.stopPrank();
    }

    // ---------------------------------------------
    // CREATE ESCROW TESTS
    // ---------------------------------------------

    function test_CreateETHEscrow_Success() public {
        uint256 escrowId = _createETHEscrow();

        EscrowV2.Escrow memory data = escrow.getEscrow(escrowId);

        assertEq(data.depositor, depositor);
        assertEq(data.beneficiary, beneficiary);
        assertEq(data.arbiter, arbiter);
        assertEq(data.token, address(0));
        assertEq(data.amount, ETH_AMOUNT);
        assertEq(data.timelockDuration, TIMELOCK);
        assertEq(data.arbiterFeeRate, ARBITER_FEE);
        assertEq(
            uint256(data.state),
            uint256(EscrowV2.EscrowState.AWAITING_DELIVERY)
        );
    }

    function test_CreateTokenEscrow_Success() public {
        uint256 escrowId = _createTokenEscrow();

        EscrowV2.Escrow memory data = escrow.getEscrow(escrowId);

        assertEq(data.token, address(token));
        assertEq(data.amount, TOKEN_AMOUNT);
    }

    function test_CreateEscrow_RevertIf_InvalidAddress() public {
        vm.prank(depositor);
        vm.expectRevert(EscrowV2.InvalidAddress.selector);
        escrow.createEscrow{value: ETH_AMOUNT}(
            address(0), // invalid beneficiary
            arbiter,
            address(0),
            0,
            TIMELOCK,
            ARBITER_FEE
        );
    }

    function test_CreateEscrow_RevertIf_TimelockTooShort() public {
        vm.prank(depositor);
        vm.expectRevert(EscrowV2.InvalidDuration.selector);
        escrow.createEscrow{value: ETH_AMOUNT}(
            beneficiary,
            arbiter,
            address(0),
            0,
            1 hours, // kurang dari MIN_TIMELOCK (1 day)
            ARBITER_FEE
        );
    }

    function test_CreateEscrow_RevertIf_FeeTooHigh() public {
        vm.prank(depositor);
        vm.expectRevert(EscrowV2.InvalidFeeRate.selector);
        escrow.createEscrow{value: ETH_AMOUNT}(
            beneficiary,
            arbiter,
            address(0),
            0,
            TIMELOCK,
            1001 // lebih dari MAX_ARBITER_FEE (1000)
        );
    }

    function test_CreateMultipleEscrows_IncrementId() public {
        uint256 id1 = _createETHEscrow();
        uint256 id2 = _createETHEscrow();
        uint256 id3 = _createETHEscrow();

        assertEq(id1, 0);
        assertEq(id2, 1);
        assertEq(id3, 2);
        assertEq(escrow.escrowCount(), 3);
    }

    function test_CreateEscrow_RevertIf_ZeroArbiter()
    public
    {
        vm.prank(depositor);

        vm.expectRevert(
            EscrowV2.InvalidAddress.selector
        );


        escrow.createEscrow{value: ETH_AMOUNT}(
            beneficiary,
            address(0),
            address(0),
            0,
            TIMELOCK,
            ARBITER_FEE
        );
    }

    // ---------------------------------------------
    // CONFIRM DELIVERY TESTS
    // ---------------------------------------------

    function test_ConfirmDelivery_ETH_Success() public {
        uint256 escrowId = _createETHEscrow();
        uint256 beneficiaryBefore = beneficiary.balance;

        vm.prank(depositor);
        escrow.confirmDelivery(escrowId);

        assertEq(beneficiary.balance, beneficiaryBefore + ETH_AMOUNT);
        assertEq(
            uint256(escrow.getEscrow(escrowId).state),
            uint256(EscrowV2.EscrowState.COMPLETE)
        );
    }

    function test_ConfirmDelivery_Token_Success() public {
        uint256 escrowId = _createTokenEscrow();
        uint256 beneficiaryBefore = token.balanceOf(beneficiary);

        vm.prank(depositor);
        escrow.confirmDelivery(escrowId);

        assertEq(
            token.balanceOf(beneficiary),
            beneficiaryBefore + TOKEN_AMOUNT
        );
    }

    // ---------------------------------------------
    // TIMELOCK TESTS
    // ---------------------------------------------

    function test_TimelockRelease_AfterExpiry() public {
        uint256 escrowId = _createETHEscrow();

        // Warp waktu ke setelah timelock
        vm.warp(block.timestamp + TIMELOCK + 1);

        assertTrue(escrow.isTimelockExpired(escrowId));
        assertEq(escrow.timeUntilRelease(escrowId), 0);

        uint256 beneficiaryBefore = beneficiary.balance;

        // Siapa pun bisa trigger
        vm.prank(stranger);
        escrow.timelockRelease(escrowId);

        assertEq(beneficiary.balance, beneficiaryBefore + ETH_AMOUNT);
    }

    function test_TimelockRelease_RevertIf_NotExpired() public {
        uint256 escrowId = _createETHEscrow();

        uint256 releaseTime = block.timestamp + TIMELOCK;

        vm.expectRevert(
            abi.encodeWithSelector(
                EscrowV2.TimelockNotExpired.selector,
                releaseTime,
                block.timestamp
            )
        );
        escrow.timelockRelease(escrowId);
    }

    function test_TimeUntilRelease_Decreases() public {
        uint256 escrowId = _createETHEscrow();

        uint256 initialTime = escrow.timeUntilRelease(escrowId);
        assertEq(initialTime, TIMELOCK);

        // Warp 1 day
        vm.warp(block.timestamp + 1 days);
        uint256 afterOneDay = escrow.timeUntilRelease(escrowId);
        assertEq(afterOneDay, TIMELOCK - 1 days);
    }

    function test_TimelockRelease_Token()
    public {
        uint256 escrowId =
            _createTokenEscrow();

        vm.warp(
            block.timestamp + TIMELOCK + 1
        );

        uint256 before =
            token.balanceOf(beneficiary);

        escrow.timelockRelease(escrowId);

        assertEq(
            token.balanceOf(beneficiary),
            before + TOKEN_AMOUNT
        );
    }

    // ---------------------------------------------
    // DISPUTE TESTS
    // ---------------------------------------------

    function test_RaiseDispute_BeforeTimelock() public {
        uint256 escrowId = _createETHEscrow();

        vm.prank(depositor);
        escrow.raiseDispute(escrowId);

        assertEq(
            uint256(escrow.getEscrow(escrowId).state),
            uint256(EscrowV2.EscrowState.IN_DISPUTE)
        );

        (address raisedBy, , bool isActive) =
            escrow.getDisputeInfo(escrowId);
        assertEq(raisedBy, depositor);
        assertTrue(isActive);
    }

    function test_RaiseDispute_RevertIf_AfterTimelock() public {
        uint256 escrowId = _createETHEscrow();

        // Warp ke setelah timelock
        vm.warp(block.timestamp + TIMELOCK + 1);

        vm.prank(depositor);
        vm.expectRevert(EscrowV2.TimelockExpired.selector);
        escrow.raiseDispute(escrowId);
    }

    function test_RaiseDispute_ByBeneficiary() public {
        uint256 escrowId = _createETHEscrow();

        vm.prank(beneficiary);
        escrow.raiseDispute(escrowId);

        (address raisedBy,,) = escrow.getDisputeInfo(escrowId);
        assertEq(raisedBy, beneficiary);
    }

    function test_RaiseDispute_RevertIf_NotParties() public {
        uint256 escrowId = _createETHEscrow();

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                EscrowV2.Unauthorized.selector,
                stranger
            )
        );
        escrow.raiseDispute(escrowId);
    }

    // ---------------------------------------------
    // RESOLVE DISPUTE TESTS
    // ---------------------------------------------

    function test_ResolveDispute_ReleaseToBeneficiary_WithFee() public {
        uint256 escrowId = _createETHEscrow();

        vm.prank(depositor);
        escrow.raiseDispute(escrowId);

        uint256 expectedFee = (ETH_AMOUNT * ARBITER_FEE) / 10_000;
        uint256 expectedAmount = ETH_AMOUNT - expectedFee;

        uint256 beneficiaryBefore = beneficiary.balance;
        uint256 arbiterBefore = arbiter.balance;

        vm.prank(arbiter);
        escrow.resolveDispute(escrowId, true);

        assertEq(
            beneficiary.balance,
            beneficiaryBefore + expectedAmount
        );
        assertEq(
            arbiter.balance,
            arbiterBefore + expectedFee
        );
        assertEq(
            uint256(escrow.getEscrow(escrowId).state),
            uint256(EscrowV2.EscrowState.COMPLETE)
        );
    }

    function test_ResolveDispute_RefundToDepositor_WithFee() public {
        uint256 escrowId = _createETHEscrow();

        vm.prank(beneficiary);
        escrow.raiseDispute(escrowId);

        uint256 expectedFee = (ETH_AMOUNT * ARBITER_FEE) / 10_000;
        uint256 expectedAmount = ETH_AMOUNT - expectedFee;

        uint256 depositorBefore = depositor.balance;
        uint256 arbiterBefore = arbiter.balance;

        vm.prank(arbiter);
        escrow.resolveDispute(escrowId, false);

        assertEq(
            depositor.balance,
            depositorBefore + expectedAmount
        );
        assertEq(
            arbiter.balance,
            arbiterBefore + expectedFee
        );
        assertEq(
            uint256(escrow.getEscrow(escrowId).state),
            uint256(EscrowV2.EscrowState.REFUNDED)
        );
    }

    function test_ResolveDispute_ZeroFee_NoFeeTransfer() public {
        // Buat escrow dengan zero arbiter fee
        vm.prank(depositor);
        uint256 escrowId = escrow.createEscrow{value: ETH_AMOUNT}(
            beneficiary,
            arbiter,
            address(0),
            0,
            TIMELOCK,
            0 // zero fee
        );

        vm.prank(depositor);
        escrow.raiseDispute(escrowId);

        uint256 arbiterBefore = arbiter.balance;

        vm.prank(arbiter);
        escrow.resolveDispute(escrowId, true);

        // Arbiter tidak dapat fee
        assertEq(arbiter.balance, arbiterBefore);
        // Beneficiary dapat full amount
        assertEq(beneficiary.balance, ETH_AMOUNT);
    }

    function test_ResolveDispute_Token_WithFee() public {
        uint256 escrowId = _createTokenEscrow();

        vm.prank(depositor);
        escrow.raiseDispute(escrowId);

        uint256 expectedFee = (TOKEN_AMOUNT * ARBITER_FEE) / 10_000;
        uint256 expectedAmount = TOKEN_AMOUNT - expectedFee;

        vm.prank(arbiter);
        escrow.resolveDispute(escrowId, true);

        assertEq(token.balanceOf(beneficiary), expectedAmount);
        assertEq(token.balanceOf(arbiter), expectedFee);
    }

    function test_ResolveDispute_RevertIf_NotArbiter()
    public {
        uint256 escrowId = _createETHEscrow();
        vm.prank(depositor);
        escrow.raiseDispute(escrowId);
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                EscrowV2.Unauthorized.selector,
                stranger
            )
        );

        escrow.resolveDispute(
            escrowId,
            true
        );
    }

    // ---------------------------------------------
    // SECURITY TESTS
    // ---------------------------------------------

    function test_Security_ReentrancyProtection() public {
        // Deploy malicious receiver sebagai arbiter
        MaliciousReceiver malicious = new MaliciousReceiver(
            address(escrow)
        );

        // Buat escrow dengan malicious arbiter
        vm.prank(depositor);
        uint256 escrowId = escrow.createEscrow{value: ETH_AMOUNT}(
            beneficiary,
            address(malicious), // malicious arbiter
            address(0),
            0,
            TIMELOCK,
            ARBITER_FEE
        );

        // Enable attack
        malicious.enableAttack(escrowId);

        // Raise dispute
        vm.prank(depositor);
        escrow.raiseDispute(escrowId);

        // Arbiter resolve — trigger reentrancy attempt
        vm.prank(address(malicious));
        escrow.resolveDispute(escrowId, true);

        // Verifikasi: attack count = 1 tapi semua attempts gagal
        // State sudah COMPLETE sebelum ETH transfer
        assertEq(malicious.attackCount(), 1);
        assertEq(
            uint256(escrow.getEscrow(escrowId).state),
            uint256(EscrowV2.EscrowState.COMPLETE)
        );
    }

    function test_Security_CannotDoubleResolve() public {
        uint256 escrowId = _createETHEscrow();

        vm.prank(depositor);
        escrow.raiseDispute(escrowId);

        vm.prank(arbiter);
        escrow.resolveDispute(escrowId, true);

        // Coba resolve lagi — harus revert
        vm.prank(arbiter);
        vm.expectRevert(
            abi.encodeWithSelector(
                EscrowV2.InvalidState.selector,
                EscrowV2.EscrowState.COMPLETE,
                EscrowV2.EscrowState.IN_DISPUTE
            )
        );
        escrow.resolveDispute(escrowId, false);
    }

    function test_Security_CannotReleaseAfterDispute() public {
        uint256 escrowId = _createETHEscrow();

        vm.prank(depositor);
        escrow.raiseDispute(escrowId);

        // Coba timelockRelease saat IN_DISPUTE
        vm.warp(block.timestamp + TIMELOCK + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                EscrowV2.InvalidState.selector,
                EscrowV2.EscrowState.IN_DISPUTE,
                EscrowV2.EscrowState.AWAITING_DELIVERY
            )
        );
        escrow.timelockRelease(escrowId);
    }

    function test_Security_TransferETH_RevertIf_ReceiverRejects()
    public
    {
        RejectETHReceiver receiver =
            new RejectETHReceiver();

        vm.prank(depositor);

        uint256 escrowId =
            escrow.createEscrow{value: ETH_AMOUNT}(
                address(receiver),
                arbiter,
                address(0),
                0,
                TIMELOCK,
                ARBITER_FEE
            );


        vm.prank(depositor);

        vm.expectRevert(
            EscrowV2.TransferFailed.selector
        );

        escrow.confirmDelivery(escrowId);
    }

    // ---------------------------------------------
    // FUZZ TESTS
    // ---------------------------------------------

    function testFuzz_ArbiterFee_Calculation(
        uint256 amount,
        uint256 feeRate
    ) public {
        amount = bound(amount, 1 ether, 100 ether);
        feeRate = bound(feeRate, 0, 1000); // 0–10%

        vm.deal(depositor, amount);

        vm.prank(depositor);
        uint256 escrowId = escrow.createEscrow{value: amount}(
            beneficiary,
            arbiter,
            address(0),
            0,
            TIMELOCK,
            feeRate
        );

        uint256 calculatedFee = escrow.calculateArbiterFee(escrowId);
        uint256 expectedFee = (amount * feeRate) / 10_000;

        assertEq(calculatedFee, expectedFee);
    }

    function testFuzz_TimelockDuration_Valid(
        uint256 duration
    ) public {
        duration = bound(duration, 1 days, 90 days);

        vm.prank(depositor);
        uint256 escrowId = escrow.createEscrow{value: ETH_AMOUNT}(
            beneficiary,
            arbiter,
            address(0),
            0,
            duration,
            ARBITER_FEE
        );

        assertEq(escrow.getEscrow(escrowId).timelockDuration, duration);
        assertEq(
            escrow.timeUntilRelease(escrowId),
            duration
        );
    }

    // ---------------------------------------------
    // INTEGRATION TESTS
    // ---------------------------------------------

    function test_Integration_HappyPath_ETH() public {
        // 1. Create escrow
        uint256 escrowId = _createETHEscrow();
        assertEq(address(escrow).balance, ETH_AMOUNT);

        // 2. Waktu berlalu (5 hari dari 7 hari)
        vm.warp(block.timestamp + 5 days);

        // 3. Depositor puas, konfirmasi delivery
        uint256 beneficiaryBefore = beneficiary.balance;
        vm.prank(depositor);
        escrow.confirmDelivery(escrowId);

        // 4. Verifikasi
        assertEq(beneficiary.balance, beneficiaryBefore + ETH_AMOUNT);
        assertEq(address(escrow).balance, 0);
        assertEq(
            uint256(escrow.getEscrow(escrowId).state),
            uint256(EscrowV2.EscrowState.COMPLETE)
        );
    }

    function test_Integration_DisputeWonByBeneficiary() public {
        // 1. Create escrow
        uint256 escrowId = _createETHEscrow();

        // 2. Seller deliver, tapi buyer tidak mau konfirmasi
        // 3. Seller raise dispute
        vm.prank(beneficiary);
        escrow.raiseDispute(escrowId);

        // 4. Arbiter review dan putuskan untuk seller
        uint256 expectedFee = (ETH_AMOUNT * ARBITER_FEE) / 10_000;
        uint256 expectedAmount = ETH_AMOUNT - expectedFee;

        vm.prank(arbiter);
        escrow.resolveDispute(escrowId, true);

        // 5. Verifikasi distribusi
        assertEq(beneficiary.balance, expectedAmount);
        assertEq(arbiter.balance, expectedFee);
        assertEq(address(escrow).balance, 0);
    }

    function test_Integration_AutoReleaseAfterTimelock() public {
        // 1. Create escrow
        uint256 escrowId = _createETHEscrow();

        // 2. Tidak ada dispute — waktu berlalu
        vm.warp(block.timestamp + TIMELOCK + 1);

        // 3. Bot/keeper trigger release
        uint256 beneficiaryBefore = beneficiary.balance;
        vm.prank(stranger); // siapa pun bisa trigger
        escrow.timelockRelease(escrowId);

        // 4. Verifikasi: beneficiary dapat full amount
        assertEq(beneficiary.balance, beneficiaryBefore + ETH_AMOUNT);
        assertEq(address(escrow).balance, 0);
    }

    function test_Integration_MultipleEscrows_Independent() public {
        // Buat tiga escrow berbeda
        uint256 id1 = _createETHEscrow();
        uint256 id2 = _createETHEscrow();
        uint256 id3 = _createETHEscrow();

        // Dispute di escrow pertama tidak pengaruhi yang lain
        vm.prank(depositor);
        escrow.raiseDispute(id1);

        // Escrow kedua bisa di-release normal
        vm.prank(depositor);
        escrow.confirmDelivery(id2);

        // Escrow ketiga auto-release
        vm.warp(block.timestamp + TIMELOCK + 1);
        escrow.timelockRelease(id3);

        // Verifikasi state masing-masing independent
        assertEq(
            uint256(escrow.getEscrow(id1).state),
            uint256(EscrowV2.EscrowState.IN_DISPUTE)
        );
        assertEq(
            uint256(escrow.getEscrow(id2).state),
            uint256(EscrowV2.EscrowState.COMPLETE)
        );
        assertEq(
            uint256(escrow.getEscrow(id3).state),
            uint256(EscrowV2.EscrowState.COMPLETE)
        );
    }

    // ---------------------------------------------
    // EDGE CASE TESTS
    // ---------------------------------------------

    function test_EdgeCase_ETHSentForTokenEscrow() public {
        // Kirim ETH saat buat ERC20 escrow - harus revert
        vm.startPrank(depositor);
        token.approve(address(escrow), TOKEN_AMOUNT);

        vm.expectRevert(EscrowV2.ETHNotAccepted.selector);
        escrow.createEscrow{value: 1 ether}( // ETH dikirim
            beneficiary,
            arbiter,
            address(token), // tapi token ERC20
            TOKEN_AMOUNT,
            TIMELOCK,
            ARBITER_FEE
        );
        vm.stopPrank();
    }

    function test_EdgeCase_InvalidEscrowId() public {
        // Akses escrow yang belum ada
        vm.expectRevert(
            abi.encodeWithSelector(
                EscrowV2.EscrowNotFound.selector,
                999
            )
        );
        escrow.getEscrow(999);
    }

    function test_InvalidEscrowId_Resolve() public {
        vm.prank(arbiter);

        vm.expectRevert(
            abi.encodeWithSelector(
                EscrowV2.EscrowNotFound.selector,
                999
            )
        );

        escrow.resolveDispute(
            999,
            true
        );
    }

    function test_InvalidEscrowId_Confirm() public {
        vm.prank(depositor);

        vm.expectRevert(
            abi.encodeWithSelector(
                EscrowV2.EscrowNotFound.selector,
                999
            )
        );

        escrow.confirmDelivery(999);
    }

    function test_EdgeCase_SameParty_ArbiterIsBeneficiary() public {
        vm.prank(depositor);
        vm.expectRevert(EscrowV2.SamePartyNotAllowed.selector);
        escrow.createEscrow{value: ETH_AMOUNT}(
            beneficiary,
            beneficiary, // arbiter sama dengan beneficiary
            address(0),
            0,
            TIMELOCK,
            ARBITER_FEE
        );
    }

    function test_EdgeCase_SameParty_DepositorIsBeneficiary() public {
        vm.prank(depositor);
        vm.expectRevert(EscrowV2.SamePartyNotAllowed.selector);
        escrow.createEscrow{value: ETH_AMOUNT}(
            depositor, // beneficiary sama dengan depositor
            arbiter,
            address(0),
            0,
            TIMELOCK,
            ARBITER_FEE
        );
    }

    function test_EdgeCase_TimelockExactBoundary() public {
        uint256 escrowId = _createETHEscrow();

        // Warp ke tepat saat timelock expired (boundary)
        uint256 releaseTime = block.timestamp + TIMELOCK;
        vm.warp(releaseTime);

        // Tepat di boundary harus bisa release
        escrow.timelockRelease(escrowId);

        assertEq(
            uint256(escrow.getEscrow(escrowId).state),
            uint256(EscrowV2.EscrowState.COMPLETE)
        );
    }

    function test_EdgeCase_DisputeExactBoundary() public {
        uint256 escrowId = _createETHEscrow();

        // Warp ke 1 detik sebelum timelock
        vm.warp(block.timestamp + TIMELOCK - 1);

        // Masih bisa raise dispute
        vm.prank(depositor);
        escrow.raiseDispute(escrowId);

        assertEq(
            uint256(escrow.getEscrow(escrowId).state),
            uint256(EscrowV2.EscrowState.IN_DISPUTE)
        );
    }

    function test_EdgeCase_DisputeExactExpiry_Revert() public {
        uint256 id =
            _createETHEscrow();

        vm.warp(
            block.timestamp + TIMELOCK
        );

        vm.prank(depositor);

        vm.expectRevert(
            EscrowV2.TimelockExpired.selector
        );

        escrow.raiseDispute(id);
    }

    function test_EdgeCase_MaxArbiterFee() public {
        // Buat escrow dengan fee maksimum (10%)
        vm.prank(depositor);
        uint256 escrowId = escrow.createEscrow{value: ETH_AMOUNT}(
            beneficiary,
            arbiter,
            address(0),
            0,
            TIMELOCK,
            1000 // 10% - MAX_ARBITER_FEE
        );

        vm.prank(depositor);
        escrow.raiseDispute(escrowId);

        uint256 expectedFee = ETH_AMOUNT * 1000 / 10_000; // 0.1 ETH
        uint256 expectedAmount = ETH_AMOUNT - expectedFee;

        vm.prank(arbiter);
        escrow.resolveDispute(escrowId, true);

        assertEq(beneficiary.balance, expectedAmount);
        assertEq(arbiter.balance, expectedFee);
    }

    function test_EdgeCase_TimelockTooLong() public {
        vm.prank(depositor);
        vm.expectRevert(EscrowV2.InvalidDuration.selector);
        escrow.createEscrow{value: ETH_AMOUNT}(
            beneficiary,
            arbiter,
            address(0),
            0,
            91 days, // lebih dari MAX_TIMELOCK (90 days)
            ARBITER_FEE
        );
    }

    function test_EdgeCase_SameParty_DepositorIsArbiter()
    public
    {
        vm.prank(depositor);


        vm.expectRevert(
            EscrowV2.SamePartyNotAllowed.selector
        );


        escrow.createEscrow{value: ETH_AMOUNT}(
            beneficiary,
            depositor,
            address(0),
            0,
            TIMELOCK,
            ARBITER_FEE
        );
    }

    // ---------------------------------------------
    // EVENT EMISSION TESTS
    // ---------------------------------------------

    function test_Event_EscrowCreated() public {
        vm.prank(depositor);

        vm.expectEmit(true, true, true, true);
        emit EscrowV2.EscrowCreated(
            0,           // escrowId
            depositor,
            beneficiary,
            arbiter,
            address(0), // ETH
            ETH_AMOUNT,
            TIMELOCK,
            ARBITER_FEE
        );

        escrow.createEscrow{value: ETH_AMOUNT}(
            beneficiary,
            arbiter,
            address(0),
            0,
            TIMELOCK,
            ARBITER_FEE
        );
    }

    function test_Event_FundsReleased() public {
        uint256 escrowId = _createETHEscrow();

        vm.expectEmit(true, true, false, true);
        emit EscrowV2.FundsReleased(escrowId, beneficiary, ETH_AMOUNT);

        vm.prank(depositor);
        escrow.confirmDelivery(escrowId);
    }

    function test_Event_DisputeRaised() public {
        uint256 escrowId = _createETHEscrow();

        vm.expectEmit(true, true, false, false);
        emit EscrowV2.DisputeRaised(escrowId, depositor);

        vm.prank(depositor);
        escrow.raiseDispute(escrowId);
    }

    function test_Event_DisputeResolved() public {
        uint256 escrowId = _createETHEscrow();

        vm.prank(depositor);
        escrow.raiseDispute(escrowId);

        uint256 expectedFee = (ETH_AMOUNT * ARBITER_FEE) / 10_000;
        uint256 expectedAmount = ETH_AMOUNT - expectedFee;

        vm.expectEmit(true, true, true, true);
        emit EscrowV2.DisputeResolved(
            escrowId,
            arbiter,
            beneficiary,
            expectedAmount,
            expectedFee
        );

        vm.prank(arbiter);
        escrow.resolveDispute(escrowId, true);
    }

    // ---------------------------------------------
    // ADDITIONAL FUZZ TESTS
    // ---------------------------------------------

    function testFuzz_ETHAmount_FullCoverage(uint256 amount) public {
        amount = bound(amount, 1, 1000 ether);
        vm.deal(depositor, amount);

        vm.prank(depositor);
        uint256 escrowId = escrow.createEscrow{value: amount}(
            beneficiary,
            arbiter,
            address(0),
            0,
            TIMELOCK,
            0 // zero fee untuk simplicity
        );

        assertEq(escrow.getEscrow(escrowId).amount, amount);

        uint256 beneficiaryBefore = beneficiary.balance;

        vm.prank(depositor);
        escrow.confirmDelivery(escrowId);

        assertEq(beneficiary.balance, beneficiaryBefore + amount);
        assertEq(address(escrow).balance, 0);
    }

    function testFuzz_MultipleDepositor_SameContract(
        uint8 numEscrows
    ) public {
        numEscrows = uint8(bound(uint256(numEscrows), 1, 10));

        uint256[] memory ids = new uint256[](numEscrows);
        uint256 ethPerEscrow = 1 ether;

        vm.deal(depositor, ethPerEscrow * numEscrows);

        // Buat multiple escrow
        for (uint256 i = 0; i < numEscrows;) {
            vm.prank(depositor);
            ids[i] = escrow.createEscrow{value: ethPerEscrow}(
                beneficiary,
                arbiter,
                address(0),
                0,
                TIMELOCK,
                0
            );
            unchecked { i++; }
        }

        assertEq(escrow.escrowCount(), numEscrows);

        // Verifikasi semua escrow independent
        for (uint256 i = 0; i < numEscrows;) {
            assertEq(escrow.getEscrow(ids[i]).amount, ethPerEscrow);
            assertEq(
                uint256(escrow.getEscrow(ids[i]).state),
                uint256(EscrowV2.EscrowState.AWAITING_DELIVERY)
            );
            unchecked { i++; }
        }
    }

    function testFuzz_FeeCalculation_NoPrecisionLoss(
        uint256 amount,
        uint256 feeRate
    ) public {
        amount = bound(amount, 1 ether, 100 ether);
        feeRate = bound(feeRate, 0, 1000);

        vm.deal(depositor, amount);

        vm.prank(depositor);
        uint256 escrowId = escrow.createEscrow{value: amount}(
            beneficiary,
            arbiter,
            address(0),
            0,
            TIMELOCK,
            feeRate
        );

        vm.prank(depositor);
        escrow.raiseDispute(escrowId);

        uint256 arbiterBefore = arbiter.balance;
        uint256 beneficiaryBefore = beneficiary.balance;

        vm.prank(arbiter);
        escrow.resolveDispute(escrowId, true);

        uint256 expectedFee = (amount * feeRate) / 10_000;
        uint256 expectedAmount = amount - expectedFee;

        // Verifikasi: total distribusi = amount awal
        assertEq(
            arbiter.balance - arbiterBefore + 
            beneficiary.balance - beneficiaryBefore,
            amount
        );
        assertEq(beneficiary.balance - beneficiaryBefore, expectedAmount);
        assertEq(arbiter.balance - arbiterBefore, expectedFee);
        assertEq(address(escrow).balance, 0);
    }
}