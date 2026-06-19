// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title EscrowV1
 * @author Absalom Benu | Bukit Digital Nusantara
 * @notice Basic ETH escrow with three-party agreement system
 * @dev Supports depositor, beneficiary, and arbiter roles.
 *      Funds are held until both parties agree or arbiter decides.
 */
contract EscrowV1 {

    // ---------------------------------------------
    // ERRORS
    // ---------------------------------------------

    error InvalidAddress();
    error InvalidAmount();
    error InvalidState(EscrowState current, EscrowState required);
    error Unauthorized(address caller);
    error TransferFailed();
    error SamePartyNotAllowed();
    error AlreadyApproved();

    // ---------------------------------------------
    // TYPES
    // ---------------------------------------------

    enum EscrowState {
        AWAITING_DELIVERY, // Funds deposited, waiting
        COMPLETE,          // Funds released to beneficiary
        REFUNDED,          // Funds returned to depositor
        IN_DISPUTE         // Dispute raised, arbiter to decide
    }


    // ---------------------------------------------
    // STATE
    // ---------------------------------------------

    address public immutable depositor;
    address public immutable beneficiary;
    address public immutable arbiter;

    uint256 public immutable amount;
    uint256 public immutable createdAt;

    EscrowState public state;

    bool public depositorApproved;
    bool public beneficiaryConfirmed;


    // ---------------------------------------------
    // EVENTS
    // ---------------------------------------------

    event FundsDeposited(
        address indexed depositor,
        address indexed beneficiary,
        uint256 amount
    );
    event DeliveryConfirmed(address indexed confirmedBy);
    event FundsReleased(address indexed beneficiary, uint256 amount);
    event FundsRefunded(address indexed depositor, uint256 amount);
    event DisputeRaised(address indexed raisedBy);
    event DisputeResolved(
        address indexed arbiter,
        address indexed recipient,
        uint256 amount
    );

    
    // ---------------------------------------------
    // MODIFIERS
    // ---------------------------------------------

    modifier onlyDepositor() {
        if (msg.sender != depositor) revert Unauthorized(msg.sender);
        _;
    }

    modifier onlyBeneficiary() {
        if (msg.sender != beneficiary) revert Unauthorized(msg.sender);
        _;
    }

    modifier onlyArbiter() {
        if (msg.sender != arbiter) revert Unauthorized(msg.sender);
        _;
    }

    modifier onlyParties() {
        if (
            msg.sender != depositor &&
            msg.sender != beneficiary
        ) revert Unauthorized(msg.sender);
        _;
    }

    modifier inState(EscrowState _state) {
        if (state != _state) revert InvalidState(state, _state);
        _;
    }

    
    // ---------------------------------------------
    // CONSTRUCTOR
    // ---------------------------------------------

    /**
     * @notice Deploy dan deposit ETH dalam satu transaksi
     * @param _beneficiary Penerima dana jika escrow selesai
     * @param _arbiter Pihak ketiga yang resolve dispute
     */
    constructor(
        address _beneficiary,
        address _arbiter
    ) payable {
        // Validasi addresses
        if (_beneficiary == address(0)) revert InvalidAddress();
        if (_arbiter == address(0)) revert InvalidAddress();

        // Semua pihak harus berbeda
        if (_beneficiary == msg.sender) revert SamePartyNotAllowed();
        if (_arbiter == msg.sender) revert SamePartyNotAllowed();
        if (_arbiter == _beneficiary) revert SamePartyNotAllowed();

        // Harus ada ETH yang di-deposit
        if (msg.value == 0) revert InvalidAmount();

        depositor = msg.sender;
        beneficiary = _beneficiary;
        arbiter = _arbiter;
        amount = msg.value;
        createdAt = block.timestamp;
        state = EscrowState.AWAITING_DELIVERY;

        emit FundsDeposited(msg.sender, _beneficiary, msg.value);
    }


    // ---------------------------------------------
    // CORE FUNCTIONS
    // ---------------------------------------------

    /**
     * @notice Depositor mengkonfirmasi delivery dan release dana
     * @dev Jika depositor approve, dana langsung ke beneficiary
     */
    function confirmDelivery()
        external
        onlyDepositor
        inState(EscrowState.AWAITING_DELIVERY)
    {
        // EFFECTS
        state = EscrowState.COMPLETE;
        depositorApproved = true;

        emit DeliveryConfirmed(msg.sender);

        // INTERACTIONS
        _release();
    }

    /**
     * @notice Depositor request refund (hanya jika tidak ada dispute)
     * @dev Beneficiary harus konfirmasi refund, atau arbiter decide
     */
    function requestRefund()
        external
        onlyDepositor
        inState(EscrowState.AWAITING_DELIVERY)
    {
        // EFFECTS
        state = EscrowState.REFUNDED;

        emit FundsRefunded(depositor, amount);

        // INTERACTIONS — refund ke depositor
        _refund();
    }

    /**
     * @notice Raise dispute — bisa dilakukan depositor atau beneficiary
     * @dev Setelah dispute raised, hanya arbiter yang bisa resolve
     */
    function raiseDispute()
        external
        onlyParties
        inState(EscrowState.AWAITING_DELIVERY)
    {
        // EFFECTS
        state = EscrowState.IN_DISPUTE;

        emit DisputeRaised(msg.sender);
    }

    /**
     * @notice Arbiter resolve dispute
     * @param releaseTobeneficiary true = release ke beneficiary,
     *                             false = refund ke depositor
     */
    function resolveDispute(bool releaseTobeneficiary)
        external
        onlyArbiter
        inState(EscrowState.IN_DISPUTE)
    {
        if (releaseTobeneficiary) {
            // EFFECTS
            state = EscrowState.COMPLETE;

            emit DisputeResolved(arbiter, beneficiary, amount);

            // INTERACTIONS
            _release();
        } else {
            // EFFECTS
            state = EscrowState.REFUNDED;

            emit DisputeResolved(arbiter, depositor, amount);

            // INTERACTIONS
            _refund();
        }
    }

    

    // ---------------------------------------------
    // INTERNAL FUNCTIONS
    // ---------------------------------------------

    /**
     * @dev Transfer ETH ke beneficiary
     */
    function _release() internal {
        (bool success, ) = beneficiary.call{value: amount}("");
        if (!success) revert TransferFailed();
        emit FundsReleased(beneficiary, amount);
    }

    /**
     * @dev Transfer ETH kembali ke depositor
     */
    function _refund() internal {
        (bool success, ) = depositor.call{value: amount}("");
        if (!success) revert TransferFailed();
    }



    // ---------------------------------------------
    // VIEW FUNCTIONS
    // ---------------------------------------------

    /**
     * @notice Kembalikan semua info escrow dalam satu call
     */
    function getEscrowInfo() external view returns (
        address _depositor,
        address _beneficiary,
        address _arbiter,
        uint256 _amount,
        uint256 _createdAt,
        EscrowState _state,
        bool _depositorApproved,
        bool _beneficiaryConfirmed
    ) {
        return (
            depositor,
            beneficiary,
            arbiter,
            amount,
            createdAt,
            state,
            depositorApproved,
            beneficiaryConfirmed
        );
    }

    /**
     * @notice Cek ETH balance contract
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}