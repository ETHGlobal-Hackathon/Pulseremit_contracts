// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

interface IAgentRegistry {
    function isAgent(address) external view returns (bool);
    function checkAndSpend(address, uint256) external returns (bool);
}

interface IIdentityRegistry {
    function isApproved(address, bytes32) external view returns (bool);
}

interface ILiFiExecutor {
    function execute(address token, address target, uint256 amount, bytes calldata data) external;
}

contract RemittanceVault is
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    enum Status { ACTIVE, PAUSED, EXPIRED }

    IERC20 public usdc;
    IAgentRegistry public agentRegistry;
    IIdentityRegistry public identityRegistry;
    ILiFiExecutor public lifiExecutor;

    uint256 public nextPlanId;
    
    uint256 public totalVolumeProtected;
    uint256 public totalFeesSaved;
    
    uint256 public maxExecutionLimit;
    uint256 public consensusThreshold;
    mapping(address => bool) public allowedTargets;

    struct Plan {
        address owner;
        address recipient;
        uint256 amount;
        uint256 balance;
        uint256 interval;
        uint256 lastPaid;
        Status status;
        bytes32 ensNode;
    }

    mapping(uint256 => Plan) public plans;
    mapping(uint256 => mapping(address => bool)) public secondaryApprovals;

    event PlanCreated(uint256 indexed planId, address indexed owner);
    event PlanExecuted(uint256 indexed planId, uint256 amount, bool crossChain, uint256 feesSaved);
    event PlanStatusChanged(uint256 indexed planId, Status newStatus);
    event MaxExecutionLimitUpdated(uint256 newLimit);
    event ConsensusThresholdUpdated(uint256 newThreshold);
    event SecondaryApproval(uint256 indexed planId, address indexed agent);
    event TargetWhitelisted(address indexed target, bool status);

    function initialize(
        address admin,
        address usdc_,
        address agentRegistry_,
        address identityRegistry_,
        address lifiExecutor_,
        uint256 maxLimit_,
        uint256 consensusThreshold_
    ) external initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        usdc = IERC20(usdc_);
        agentRegistry = IAgentRegistry(agentRegistry_);
        identityRegistry = IIdentityRegistry(identityRegistry_);
        lifiExecutor = ILiFiExecutor(lifiExecutor_);
        maxExecutionLimit = maxLimit_;
        consensusThreshold = consensusThreshold_;
    }

    function setMaxExecutionLimit(uint256 newLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxExecutionLimit = newLimit;
        emit MaxExecutionLimitUpdated(newLimit);
    }

    function setConsensusThreshold(uint256 newThreshold) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newThreshold > 0, "Invalid threshold");
        consensusThreshold = newThreshold;
        emit ConsensusThresholdUpdated(newThreshold);
    }

    function setTargetWhitelisting(address target, bool status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        allowedTargets[target] = status;
        emit TargetWhitelisted(target, status);
    }

    function createPlan(
        address recipient,
        uint256 amount,
        uint256 interval,
        bytes32 ensNode
    ) external whenNotPaused nonReentrant returns (uint256 planId) {
        require(amount > 0, "Invalid amount");
        require(interval >= 1 days, "Interval too short");

        planId = nextPlanId++;

        plans[planId] = Plan({
            owner: msg.sender,
            recipient: recipient,
            amount: amount,
            balance: amount,
            interval: interval,
            lastPaid: block.timestamp,
            status: Status.ACTIVE,
            ensNode: ensNode
        });

        usdc.safeTransferFrom(msg.sender, address(this), amount);

        emit PlanCreated(planId, msg.sender);
    }

    function topUpPlan(uint256 planId, uint256 amount) external whenNotPaused nonReentrant {
        Plan storage plan = plans[planId];
        require(plan.owner != address(0), "Invalid plan");
        require(plan.status != Status.EXPIRED, "Plan expired");
        require(amount > 0, "Invalid amount");

        plan.balance += amount;
        usdc.safeTransferFrom(msg.sender, address(this), amount);
    }

    function approvePlan(uint256 planId) external {
        require(agentRegistry.isAgent(msg.sender), "Not agent");
        Plan storage plan = plans[planId];
        require(plan.owner != address(0), "Invalid plan");
        
        secondaryApprovals[planId][msg.sender] = true;
        emit SecondaryApproval(planId, msg.sender);
    }

    function executePlan(
        uint256 planId, 
        address target, 
        bytes calldata bridgeData, 
        uint256 feesSaved,
        address secondaryAgent
    )
        external
        whenNotPaused
        nonReentrant
    {
        Plan storage plan = plans[planId];
        require(plan.owner != address(0), "Invalid plan");
        require(agentRegistry.checkAndSpend(msg.sender, plan.amount), "Agent limit exceeded or not agent");
        require(plan.status == Status.ACTIVE, "Plan not active");
        require(plan.amount <= maxExecutionLimit, "Amount exceeds limit");
        require(plan.balance >= plan.amount, "Insufficient plan balance");
        require(feesSaved <= plan.amount / 10, "Invalid feesSaved");
        
        if (plan.amount > consensusThreshold) {
            require(secondaryApprovals[planId][secondaryAgent], "Missing secondary approval");
            require(secondaryAgent != msg.sender, "Same agent");
            // Persistent approval for automated streams
        }

        require(
            block.timestamp >= plan.lastPaid + plan.interval,
            "Too early"
        );
        require(
            identityRegistry.isApproved(plan.owner, plan.ensNode),
            "Compliance not approved"
        );

        plan.lastPaid = block.timestamp;
        plan.balance -= plan.amount;
        
        totalVolumeProtected += plan.amount;
        totalFeesSaved += feesSaved;

        if (target != address(0)) {
            require(allowedTargets[target], "Target not allowed");
            // Handle USDC (some versions don't return bool, safeApprove is deprecated in OZ 5.x)
            // Use forceApprove to handle potential non-zero allowance
            usdc.forceApprove(address(lifiExecutor), plan.amount);
            lifiExecutor.execute(address(usdc), target, plan.amount, bridgeData);
            
            emit PlanExecuted(planId, plan.amount, true, feesSaved);
        } else {
            usdc.safeTransfer(plan.recipient, plan.amount);
            emit PlanExecuted(planId, plan.amount, false, feesSaved);
        }
    }

    function pausePlan(uint256 planId) external {
        Plan storage plan = plans[planId];
        require(plan.owner != address(0), "Invalid plan");
        require(msg.sender == plan.owner, "Not owner");
        require(plan.status == Status.ACTIVE, "Not active");

        plan.status = Status.PAUSED;
        emit PlanStatusChanged(planId, Status.PAUSED);
    }

    function resumePlan(uint256 planId) external {
        Plan storage plan = plans[planId];
        require(plan.owner != address(0), "Invalid plan");
        require(msg.sender == plan.owner, "Not owner");
        require(plan.status == Status.PAUSED, "Not paused");

        plan.status = Status.ACTIVE;
        emit PlanStatusChanged(planId, Status.ACTIVE);
    }

    function cancelPlan(uint256 planId) external nonReentrant {
        Plan storage plan = plans[planId];
        require(plan.owner != address(0), "Invalid plan");
        require(msg.sender == plan.owner, "Not owner");
        require(plan.status != Status.EXPIRED, "Already expired");

        uint256 refundAmount = plan.balance;
        plan.balance = 0;
        plan.status = Status.EXPIRED;
        
        if (refundAmount > 0) {
            usdc.safeTransfer(plan.owner, refundAmount);
        }

        emit PlanStatusChanged(planId, Status.EXPIRED);
    }

    function emergencyRecover(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(token).safeTransfer(to, amount);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}
}
