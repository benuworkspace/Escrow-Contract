// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {EscrowV1} from "../src/EscrowV1.sol";

contract EscrowV1Test is Test {

    EscrowV1 public escrow;

    address public depositor = makeAddr("depositor");
    address public beneficiary = makeAddr("beneficiary");
    address public arbiter = makeAddr("arbiter");
    address public stranger = makeAddr("stranger");

    uint256 public constant ESCROW_AMOUNT = 1 ether;

    // ---------------------------------------------
    // SETUP
    // ---------------------------------------------

    function setUp() public {
        vm.deal(depositor, 10 ether);

        vm.prank(depositor);
        escrow = new EscrowV1{value: ESCROW_AMOUNT}(
            beneficiary,
            arbiter
        );
    }

    // ---------------------------------------------
    // CONSTRUCTOR TESTS
    // ---------------------------------------------

    function test_Constructor_SetsCorrectState() public view {
        assertEq(escrow.depositor(), depositor);
        assertEq(escrow.beneficiary(), beneficiary);
        assertEq(escrow.arbiter(), arbiter);
        assertEq(escrow.amount(), ESCROW_AMOUNT);
        assertEq(
            uint256(escrow.state()),
            uint256(EscrowV1.EscrowState.AWAITING_DELIVERY)
        );
    }

    function test_Constructor_HoldsETH() public view {
        assertEq(address(escrow).balance, ESCROW_AMOUNT);
    }

    function test_Constructor_RevertIf_ZeroBeneficiary() public {
        vm.prank(depositor);
        vm.expectRevert(EscrowV1.InvalidAddress.selector);
        new EscrowV1{value: 1 ether}(address(0), arbiter);
    }

    function test_Constructor_RevertIf_ZeroArbiter() public {
        vm.prank(depositor);
        vm.expectRevert(EscrowV1.InvalidAddress.selector);
        new EscrowV1{value: 1 ether}(beneficiary, address(0));
    }

    function test_Constructor_RevertIf_ZeroAmount() public {
        vm.prank(depositor);
        vm.expectRevert(EscrowV1.InvalidAmount.selector);
        new EscrowV1{value: 0}(beneficiary, arbiter);
    }

    function test_Constructor_RevertIf_SameParty() public {
        vm.prank(depositor);
        vm.expectRevert(EscrowV1.SamePartyNotAllowed.selector);
        new EscrowV1{value: 1 ether}(depositor, arbiter);
    }

    function test_Constructor_RevertIf_ArbiterIsDepositor() public {
        vm.prank(depositor);
        vm.expectRevert(
            EscrowV1.SamePartyNotAllowed.selector
        );

        new EscrowV1{value:1 ether}(
            beneficiary,
            depositor
        );
    }

    function test_Constructor_RevertIf_ArbiterIsBeneficiary() public {
        vm.prank(depositor);
        vm.expectRevert(
            EscrowV1.SamePartyNotAllowed.selector
        );

        new EscrowV1{value:1 ether}(
            beneficiary,
            beneficiary
        );
    }

    // ---------------------------------------------
    // CONFIRM DELIVERY TESTS
    // ---------------------------------------------

    function test_ConfirmDelivery_ReleaseFunds() public {
        uint256 beneficiaryBalanceBefore = beneficiary.balance;

        vm.prank(depositor);
        escrow.confirmDelivery();

        assertEq(
            beneficiary.balance,
            beneficiaryBalanceBefore + ESCROW_AMOUNT
        );
        assertEq(address(escrow).balance, 0);
        assertEq(
            uint256(escrow.state()),
            uint256(EscrowV1.EscrowState.COMPLETE)
        );
    }

    function test_ConfirmDelivery_RevertIf_NotDepositor() public {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                EscrowV1.Unauthorized.selector,
                stranger
            )
        );
        escrow.confirmDelivery();
    }

    function test_ConfirmDelivery_RevertIf_WrongState() public {
        // First confirm
        vm.prank(depositor);
        escrow.confirmDelivery();

        // Try to confirm again
        vm.prank(depositor);
        vm.expectRevert(
            abi.encodeWithSelector(
                EscrowV1.InvalidState.selector,
                EscrowV1.EscrowState.COMPLETE,
                EscrowV1.EscrowState.AWAITING_DELIVERY
            )
        );
        escrow.confirmDelivery();
    }

    // ---------------------------------------------
    // REFUND TESTS
    // ---------------------------------------------

    function test_RequestRefund_ReturnsETH() public {
        uint256 depositorBalanceBefore = depositor.balance;

        vm.prank(depositor);
        escrow.requestRefund();

        assertEq(
            depositor.balance,
            depositorBalanceBefore + ESCROW_AMOUNT
        );
        assertEq(address(escrow).balance, 0);
        assertEq(
            uint256(escrow.state()),
            uint256(EscrowV1.EscrowState.REFUNDED)
        );
    }

    function test_RequestRefund_RevertIf_NotDepositor() public {
        vm.prank(beneficiary);
        vm.expectRevert(
            abi.encodeWithSelector(
                EscrowV1.Unauthorized.selector,
                beneficiary
            )
        );
        escrow.requestRefund();
    }

    // ---------------------------------------------
    // DISPUTE TESTS
    // ---------------------------------------------

    function test_RaiseDispute_ChangesState() public {
        vm.prank(depositor);
        escrow.raiseDispute();

        assertEq(
            uint256(escrow.state()),
            uint256(EscrowV1.EscrowState.IN_DISPUTE)
        );
    }

    function test_RaiseDispute_ByBeneficiary() public {
        vm.prank(beneficiary);
        escrow.raiseDispute();

        assertEq(
            uint256(escrow.state()),
            uint256(EscrowV1.EscrowState.IN_DISPUTE)
        );
    }

    function test_RaiseDispute_RevertIf_NotParties() public {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                EscrowV1.Unauthorized.selector,
                stranger
            )
        );
        escrow.raiseDispute();
    }

    // ---------------------------------------------
    // RESOLVE DISPUTE TESTS
    // ---------------------------------------------

    function test_ResolveDispute_ReleaseToBeneficiary() public {
        // Setup dispute
        vm.prank(depositor);
        escrow.raiseDispute();

        uint256 beneficiaryBalanceBefore = beneficiary.balance;

        // Arbiter decides for beneficiary
        vm.prank(arbiter);
        escrow.resolveDispute(true);

        assertEq(
            beneficiary.balance,
            beneficiaryBalanceBefore + ESCROW_AMOUNT
        );
        assertEq(
            uint256(escrow.state()),
            uint256(EscrowV1.EscrowState.COMPLETE)
        );
    }

    function test_ResolveDispute_RefundToDepositor() public {
        // Setup dispute
        vm.prank(beneficiary);
        escrow.raiseDispute();

        uint256 depositorBalanceBefore = depositor.balance;

        // Arbiter decides for depositor
        vm.prank(arbiter);
        escrow.resolveDispute(false);

        assertEq(
            depositor.balance,
            depositorBalanceBefore + ESCROW_AMOUNT
        );
        assertEq(
            uint256(escrow.state()),
            uint256(EscrowV1.EscrowState.REFUNDED)
        );
    }

    function test_ResolveDispute_RevertIf_NotArbiter() public {
        vm.prank(depositor);
        escrow.raiseDispute();

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                EscrowV1.Unauthorized.selector,
                stranger
            )
        );
        escrow.resolveDispute(true);
    }

    function test_ResolveDispute_RevertIf_NotInDispute() public {
        vm.prank(arbiter);
        vm.expectRevert(
            abi.encodeWithSelector(
                EscrowV1.InvalidState.selector,
                EscrowV1.EscrowState.AWAITING_DELIVERY,
                EscrowV1.EscrowState.IN_DISPUTE
            )
        );
        escrow.resolveDispute(true);
    }

    // ---------------------------------------------
    // VIEW FUNCTIONS TESTS
    // ---------------------------------------------

    function test_GetEscrowInfo_ReturnsCorrectData() public view {
        
        (
            address _depositor,
            address _beneficiary,
            address _arbiter,
            uint256 _amount,
            uint256 _createdAt,
            EscrowV1.EscrowState _state,
            bool _depositorApproved,
            bool _beneficiaryConfirmed
        ) = escrow.getEscrowInfo();

        assertEq(_depositor, depositor);
        assertEq(_beneficiary, beneficiary);
        assertEq(_arbiter, arbiter);
        assertEq(_amount, ESCROW_AMOUNT);

        assertGt(_createdAt, 0);

        assertEq(
            uint256(_state),
            uint256(
                EscrowV1.EscrowState.AWAITING_DELIVERY
            )
        );

        assertFalse(_depositorApproved);
        assertFalse(_beneficiaryConfirmed);
    }

    function test_GetBalance_ReturnsContractBalance() public view {
        assertEq(
            escrow.getBalance(),
            ESCROW_AMOUNT
        );
    }

    // ---------------------------------------------
    // FUZZ TESTS
    // ---------------------------------------------

    function testFuzz_Constructor_Amount(uint256 amount) public {
        amount = bound(amount, 1, 100 ether);
        vm.deal(depositor, amount);

        vm.prank(depositor);
        EscrowV1 fuzzEscrow = new EscrowV1{value: amount}(
            beneficiary,
            arbiter
        );

        assertEq(fuzzEscrow.amount(), amount);
        assertEq(address(fuzzEscrow).balance, amount);
    }

    function testFuzz_ConfirmDelivery_FullAmount(
        uint256 amount
    ) public {
        amount = bound(amount, 1, 100 ether);
        vm.deal(depositor, amount);

        vm.prank(depositor);
        EscrowV1 fuzzEscrow = new EscrowV1{value: amount}(
            beneficiary,
            arbiter
        );

        uint256 beneficiaryBefore = beneficiary.balance;

        vm.prank(depositor);
        fuzzEscrow.confirmDelivery();

        assertEq(beneficiary.balance, beneficiaryBefore + amount);
        assertEq(address(fuzzEscrow).balance, 0);
    }

    // ---------------------------------------------
    // INTEGRATION TESTS
    // ---------------------------------------------

    function test_FullFlow_HappyPath() public {
        // 1. Escrow sudah dibuat di setUp()
        assertEq(
            uint256(escrow.state()),
            uint256(EscrowV1.EscrowState.AWAITING_DELIVERY)
        );

        // 2. Depositor konfirmasi delivery
        vm.prank(depositor);
        escrow.confirmDelivery();

        // 3. Verifikasi state dan balance
        assertEq(
            uint256(escrow.state()),
            uint256(EscrowV1.EscrowState.COMPLETE)
        );
        assertEq(beneficiary.balance, ESCROW_AMOUNT);
        assertEq(address(escrow).balance, 0);
    }

    function test_FullFlow_DisputeResolution() public {
        // 1. Beneficiary raise dispute
        vm.prank(beneficiary);
        escrow.raiseDispute();

        assertEq(
            uint256(escrow.state()),
            uint256(EscrowV1.EscrowState.IN_DISPUTE)
        );

        // 2. Arbiter resolve untuk beneficiary
        uint256 beneficiaryBefore = beneficiary.balance;

        vm.prank(arbiter);
        escrow.resolveDispute(true);

        // 3. Verifikasi
        assertEq(beneficiary.balance, beneficiaryBefore + ESCROW_AMOUNT);
        assertEq(
            uint256(escrow.state()),
            uint256(EscrowV1.EscrowState.COMPLETE)
        );
    }
}