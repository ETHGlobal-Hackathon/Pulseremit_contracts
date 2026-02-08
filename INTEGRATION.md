# Pulseremit Integration Guide

This guide outlines the workflow for integrating the Pulseremit protocol into your Frontend (User Interface) and Backend (Agent/Automation) services.

## Phase 1: User Onboarding (Frontend)

Before a user can create a plan, they must satisfy identity and token requirements.

1.  **Identity Verification**: 
    *   Call `IdentityRegistry.isApproved(userAddress, ensNode)`.
    *   If `false`, prompt the user to link their ENS name or wait for manual compliance approval.
2.  **Token Allowance**:
    *   The user must `approve` the `RemittanceVault` to spend their USDC. 
    *   *Tip:* Use `allowance()` to check if they've already approved enough for the initial deposit.

## Phase 2: Plan Creation (Frontend)

1.  **Recipient Preferences**: 
    *   Query `RecipientRegistry.getProfile(recipientAddress)`.
    *   If a profile exists, display the recipient's preferred chain/token to the user.
2.  **Vault Transaction**:
    *   Call `Vault.createPlan(recipient, amount, interval, ensNode)`.
    *   This pulls the initial `amount` into the vault and registers the stream.

## Phase 3: Monitoring & Automation (Backend/Agent)

The Agent service is responsible for finding and executing due plans.

1.  **Indexing**: 
    *   Listen for `PlanCreated` events or poll `Vault.nextPlanId()` to build a local state of active plans.
2.  **Selecting Due Plans**:
    *   Filter plans where `block.timestamp >= lastPaid + interval`.
    *   Verify `Vault.plans(planId).balance >= amount`.
3.  **Compliance Pre-Check**:
    *   Call `IdentityRegistry.isApproved(owner, ensNode)`. If `false`, skip execution and flag for compliance.

## Phase 4: Execution & Routing (Backend/Agent)

1.  **Route Selection (Li.Fi)**:
    *   For cross-chain transfers, call the [Li.Fi API](https://docs.li.fi/api-reference/evm/get-quote) to get `bridgeData` and the `target` router address.
2.  **Security Check**:
    *   Verify the Li.Fi `target` is whitelisted in `lifiExecutor.whitelistedTargets()`.
3.  **Contract Call**:
    *   **Standard (< Threshold)**: Call `Agent.executePlan(...)`.
    *   **High Value (> Threshold)**: requires two-step consensus:
        *   **Agent A** calls `Agent.approvePlan(planId)`.
        *   **Agent B** calls `Agent.executePlan(..., secondaryAgent: AgentA)`.

## Phase 5: Feedback Loop (Frontend)

1.  **Global Stats**:
    *   Query `Vault.totalVolumeProtected()` and `Vault.totalFeesSaved()` for protocol-wide metrics.
2.  **User Dashboard**:
    *   Listen for `PlanExecuted` events to update the user's payment history and display savings realized via agent optimization.

---

## Integration Checklist

| Component | Action | Library Recommendation |
| :--- | :--- | :--- |
| **Frontend** | Wallet Connection | Wagmi / RainbowKit |
| **Frontend** | Contract Interactions | Viem |
| **Backend** | Chain Interaction | Viem / Ethers |
| **Backend** | Bridge Routing | Li.Fi SDK |
| **Indexing** | Event Tracking | Subgraph (Standard) or Envoy |
