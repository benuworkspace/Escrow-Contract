// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title EscrowV2
 * @author Absalom Benu | Bukit Digital Nusantara
 * @notice Multi-escrow contract with timelock, ERC20 support,
 *         and arbiter fee mechanism
 * @dev One contract instance handles unlimited escrow agreements.
 *      Supports both ETH (token = address(0)) and ERC20 tokens.
 */
contract EscrowV2 is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---------------------------------------------
    // ERRORS
    // ---------------------------------------------

    error InvalidAddress();
    error InvalidAmount();
    error InvalidDuration();
    error InvalidFeeRate();
    error EscrowNotFound(uint256 escrowId);
    error Unauthorized(address caller);
    error InvalidState(EscrowState current, EscrowState required);
    error TimelockNotExpired(uint256 releaseTime, uint256 currentTime);
    error TimelockExpired();
    error DisputeWindowClosed();
    error TransferFailed();
    error SamePartyNotAllowed();
    error IncorrectETHAmount(uint256 sent, uint256 required);
    error ETHNotAccepted();

    // ---------------------------------------------
    // TYPES
    // ---------------------------------------------

    enum EscrowState {
        AWAITING_DELIVERY,
        COMPLETE,
        REFUNDED,
        IN_DISPUTE
    }

    struct Escrow {
        address depositor;
        address beneficiary;
        address arbiter;
        address token;          // address(0) = ETH
        uint256 amount;
        uint256 createdAt;
        uint256 timelockDuration;
        uint256 arbiterFeeRate; // basis points (100 = 1%)
        EscrowState state;
        address disputeRaisedBy;  // track siapa raise dispute
        uint256 disputeRaisedAt;  // track kapan dispute di-raise
    }

    // ---------------------------------------------
    // CONSTANTS
    // ---------------------------------------------

    uint256 public constant MIN_TIMELOCK = 1 days;
    uint256 public constant MAX_TIMELOCK = 90 days;
    uint256 public constant MAX_ARBITER_FEE = 1000; // 10% max
    uint256 public constant BASIS_POINTS = 10_000;

    // ---------------------------------------------
    // STATE
    // ---------------------------------------------

    // Auto-incrementing escrow ID
    uint256 private _escrowCount;

    // escrowId -> Escrow data
    mapping(uint256 => Escrow) private _escrows;

    // ---------------------------------------------
    // EVENTS
    // ---------------------------------------------

    event EscrowCreated(
        uint256 indexed escrowId,
        address indexed depositor,
        address indexed beneficiary,
        address arbiter,
        address token,
        uint256 amount,
        uint256 timelockDuration,
        uint256 arbiterFeeRate
    );
    event FundsReleased(
        uint256 indexed escrowId,
        address indexed beneficiary,
        uint256 amount
    );
    event FundsRefunded(
        uint256 indexed escrowId,
        address indexed depositor,
        uint256 amount
    );
    event DisputeRaised(
        uint256 indexed escrowId,
        address indexed raisedBy
    );
    event DisputeResolved(
        uint256 indexed escrowId,
        address indexed arbiter,
        address indexed recipient,
        uint256 amountToRecipient,
        uint256 arbiterFee
    );
    event TimelockReleased(
        uint256 indexed escrowId,
        address indexed triggeredBy
    );

    // ---------------------------------------------
    // MODIFIERS
    // ---------------------------------------------

    modifier escrowExists(uint256 escrowId) {
        if (escrowId >= _escrowCount) revert EscrowNotFound(escrowId);
        _;
    }

    modifier inState(uint256 escrowId, EscrowState required) {
        EscrowState current = _escrows[escrowId].state;
        if (current != required) revert InvalidState(current, required);
        _;
    }

    modifier onlyDepositor(uint256 escrowId) {
        if (msg.sender != _escrows[escrowId].depositor) {
            revert Unauthorized(msg.sender);
        }
        _;
    }

    modifier onlyArbiter(uint256 escrowId) {
        if (msg.sender != _escrows[escrowId].arbiter) {
            revert Unauthorized(msg.sender);
        }
        _;
    }

    modifier onlyParties(uint256 escrowId) {
        Escrow storage escrow = _escrows[escrowId];
        if (
            msg.sender != escrow.depositor &&
            msg.sender != escrow.beneficiary
        ) revert Unauthorized(msg.sender);
        _;
    }

    // ---------------------------------------------
    // CORE FUNCTIONS
    // ---------------------------------------------

    /**
     * @notice Buat escrow baru dengan ETH atau ERC20
     * @param beneficiary Penerima dana
     * @param arbiter Pihak ketiga untuk resolve dispute
     * @param token Token address (address(0) untuk ETH)
     * @param amount Jumlah token (0 jika ETH — gunakan msg.value)
     * @param timelockDuration Durasi timelock dalam detik
     * @param arbiterFeeRate Fee arbiter dalam basis points
     * @return escrowId ID escrow yang baru dibuat
     */
    function createEscrow(
        address beneficiary,
        address arbiter,
        address token,
        uint256 amount,
        uint256 timelockDuration,
        uint256 arbiterFeeRate
    ) external payable nonReentrant returns (uint256 escrowId) {
        // --- Validasi addresses ---
        if (beneficiary == address(0)) revert InvalidAddress();
        if (arbiter == address(0)) revert InvalidAddress();
        if (beneficiary == msg.sender) revert SamePartyNotAllowed();
        if (arbiter == msg.sender) revert SamePartyNotAllowed();
        if (arbiter == beneficiary) revert SamePartyNotAllowed();

        // --- Validasi timelock ---
        if (timelockDuration < MIN_TIMELOCK) revert InvalidDuration();
        if (timelockDuration > MAX_TIMELOCK) revert InvalidDuration();

        // --- Validasi fee ---
        if (arbiterFeeRate > MAX_ARBITER_FEE) revert InvalidFeeRate();

        // --- Handle ETH vs ERC20 ---
        uint256 actualAmount;

        if (token == address(0)) {
            // ETH escrow
            if (msg.value == 0) revert InvalidAmount();
            actualAmount = msg.value;
        } else {
            // ERC20 escrow
            if (msg.value > 0) revert ETHNotAccepted();
            if (amount == 0) revert InvalidAmount();

            // Record balance sebelum transfer untuk handle
            // fee-on-transfer tokens
            uint256 balanceBefore = IERC20(token).balanceOf(
                address(this)
            );
            IERC20(token).safeTransferFrom(
                msg.sender,
                address(this),
                amount
            );
            uint256 balanceAfter = IERC20(token).balanceOf(
                address(this)
            );

            // Actual amount yang diterima (handle fee-on-transfer)
            actualAmount = balanceAfter - balanceBefore;
            if (actualAmount == 0) revert InvalidAmount();
        }

        // --- Create escrow record ---
        escrowId = _escrowCount;

        _escrows[escrowId] = Escrow({
            depositor: msg.sender,
            beneficiary: beneficiary,
            arbiter: arbiter,
            token: token,
            amount: actualAmount,
            createdAt: block.timestamp,
            timelockDuration: timelockDuration,
            arbiterFeeRate: arbiterFeeRate,
            state: EscrowState.AWAITING_DELIVERY,
            disputeRaisedBy: address(0),
            disputeRaisedAt: 0
        });

        // --- Increment counter ---
        unchecked {
            _escrowCount++;
        }

        emit EscrowCreated(
            escrowId,
            msg.sender,
            beneficiary,
            arbiter,
            token,
            actualAmount,
            timelockDuration,
            arbiterFeeRate
        );
    }

    /**
     * @notice Depositor konfirmasi delivery - release dana ke beneficiary
     * @dev Bisa dipanggil kapan saja selama state AWAITING_DELIVERY
     */
    function confirmDelivery(uint256 escrowId)
        external
        nonReentrant
        escrowExists(escrowId)
        onlyDepositor(escrowId)
        inState(escrowId, EscrowState.AWAITING_DELIVERY)
    {
        Escrow storage escrow = _escrows[escrowId];

        // EFFECTS
        escrow.state = EscrowState.COMPLETE;

        // INTERACTIONS
        _transferFunds(
            escrow.token,
            escrow.beneficiary,
            escrow.amount
        );

        emit FundsReleased(escrowId, escrow.beneficiary, escrow.amount);
    }

    /**
     * @notice Trigger auto-release setelah timelock expired
     * @dev Siapa pun bisa trigger ini - tidak perlu depositor
     */
    function timelockRelease(uint256 escrowId)
        external
        nonReentrant
        escrowExists(escrowId)
        inState(escrowId, EscrowState.AWAITING_DELIVERY)
    {
        Escrow storage escrow = _escrows[escrowId];

        uint256 releaseTime = escrow.createdAt + escrow.timelockDuration;

        if (block.timestamp < releaseTime) {
            revert TimelockNotExpired(releaseTime, block.timestamp);
        }

        // EFFECTS
        escrow.state = EscrowState.COMPLETE;

        emit TimelockReleased(escrowId, msg.sender);

        // INTERACTIONS
        _transferFunds(
            escrow.token,
            escrow.beneficiary,
            escrow.amount
        );

        emit FundsReleased(escrowId, escrow.beneficiary, escrow.amount);
    }

    /**
     * @notice Raise dispute — harus sebelum timelock expired
     * @dev Setelah dispute, hanya arbiter yang bisa resolve
     */
    function raiseDispute(uint256 escrowId)
        external
        nonReentrant
        escrowExists(escrowId)
        onlyParties(escrowId)
        inState(escrowId, EscrowState.AWAITING_DELIVERY)
    {
        Escrow storage escrow = _escrows[escrowId];

        // Dispute harus di-raise SEBELUM timelock expired
        uint256 releaseTime = escrow.createdAt + escrow.timelockDuration;
        if (block.timestamp >= releaseTime) revert TimelockExpired();

        // EFFECTS
        escrow.state = EscrowState.IN_DISPUTE;
        escrow.disputeRaisedBy = msg.sender;      // track siapa
        escrow.disputeRaisedAt = block.timestamp; // track kapan

        emit DisputeRaised(escrowId, msg.sender);
    }

    /**
     * @notice Arbiter resolve dispute dengan atau tanpa fee
     * @param escrowId ID escrow
     * @param releaseTobeneficiary true = beneficiary menang,
     *                             false = depositor dapat refund
     */
    function resolveDispute(
        uint256 escrowId,
        bool releaseTobeneficiary
    )
        external
        nonReentrant
        escrowExists(escrowId)
        onlyArbiter(escrowId)
        inState(escrowId, EscrowState.IN_DISPUTE)
    {
        Escrow storage escrow = _escrows[escrowId];

        // Kalkulasi arbiter fee
        uint256 arbiterFee = (escrow.amount * escrow.arbiterFeeRate)
            / BASIS_POINTS;
        uint256 amountAfterFee = escrow.amount - arbiterFee;

        address recipient = releaseTobeneficiary
            ? escrow.beneficiary
            : escrow.depositor;

        // EFFECTS
        escrow.state = releaseTobeneficiary
            ? EscrowState.COMPLETE
            : EscrowState.REFUNDED;

        emit DisputeResolved(
            escrowId,
            escrow.arbiter,
            recipient,
            amountAfterFee,
            arbiterFee
        );

        // INTERACTIONS - recipient first, then arbiter fee
        _transferFunds(escrow.token, recipient, amountAfterFee);

        if (arbiterFee > 0) {
            _transferFunds(escrow.token, escrow.arbiter, arbiterFee);
        }

        if (releaseTobeneficiary) {
            emit FundsReleased(
                escrowId,
                escrow.beneficiary,
                amountAfterFee
            );
        } else {
            emit FundsRefunded(
                escrowId,
                escrow.depositor,
                amountAfterFee
            );
        }
    }

    // ---------------------------------------------
    // INTERNAL FUNCTIONS
    // ---------------------------------------------

    /**
     * @dev Transfer ETH atau ERC20 ke recipient
     */
    function _transferFunds(
        address token,
        address recipient,
        uint256 amount
    ) internal {
        if (token == address(0)) {
            // ETH transfer
            (bool success, ) = recipient.call{value: amount}("");
            if (!success) revert TransferFailed();
        } else {
            // ERC20 transfer
            IERC20(token).safeTransfer(recipient, amount);
        }
    }

    // ---------------------------------------------
    // VIEW FUNCTIONS
    // ---------------------------------------------

    /**
     * @notice Ambil data escrow berdasarkan ID
     */
    function getEscrow(uint256 escrowId)
        external
        view
        escrowExists(escrowId)
        returns (Escrow memory)
    {
        return _escrows[escrowId];
    }

    /**
     * @notice Cek apakah timelock sudah expired
     */
    function isTimelockExpired(uint256 escrowId)
        external
        view
        escrowExists(escrowId)
        returns (bool)
    {
        Escrow storage escrow = _escrows[escrowId];
        return block.timestamp >=
            escrow.createdAt + escrow.timelockDuration;
    }

    /**
     * @notice Waktu tersisa sebelum timelock expired (dalam detik)
     */
    function timeUntilRelease(uint256 escrowId)
        external
        view
        escrowExists(escrowId)
        returns (uint256)
    {
        Escrow storage escrow = _escrows[escrowId];
        uint256 releaseTime = escrow.createdAt + escrow.timelockDuration;

        if (block.timestamp >= releaseTime) return 0;

        unchecked {
            return releaseTime - block.timestamp;
        }
    }

    /**
     * @notice Total escrow yang pernah dibuat
     */
    function escrowCount() external view returns (uint256) {
        return _escrowCount;
    }

    /**
     * @notice Kalkulasi arbiter fee untuk escrow tertentu
     */
    function calculateArbiterFee(uint256 escrowId)
        external
        view
        escrowExists(escrowId)
        returns (uint256)
    {
        Escrow storage escrow = _escrows[escrowId];
        return (escrow.amount * escrow.arbiterFeeRate) / BASIS_POINTS;
    }

    /**
     * @notice Ambil informasi dispute untuk escrow tertentu
     * @return raisedBy Address yang raise dispute
     * @return raisedAt Timestamp saat dispute di-raise
     * @return isActive Apakah dispute masih aktif
     */
    function getDisputeInfo(uint256 escrowId)
        external
        view
        escrowExists(escrowId)
        returns (
            address raisedBy,
            uint256 raisedAt,
            bool isActive
        )
    {
        Escrow storage escrow = _escrows[escrowId];
        return (
            escrow.disputeRaisedBy,
            escrow.disputeRaisedAt,
            escrow.state == EscrowState.IN_DISPUTE
        );
    }
}