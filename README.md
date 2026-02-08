# Pulseremit Protocol

Pulseremit is a decentralized protocol for automated, cross-chain remittances. It enables users to set up recurring payment plans that can be executed across different blockchain networks, leveraging Li.Fi for bridging and a network of incentivized agents for execution.

## Core Components

### RemittanceVault
The central hub of the protocol. It handles:
- User fund management and plan accounting.
- Logic for recurring payments (streams).
- Secondary approval checks for large transactions.
- Role-based management for protocol upgrades and parameters.

### LiFiExecutor
A security-focused intermediary contract for cross-chain operations.
- Interacts with the Li.Fi Diamond to perform swaps and bridges.
- Uses a strict whitelist of allowed bridge targets to prevent arbitrary call data attacks.
- Pulls funds from the Vault only during active execution to minimize risk.

### AgentRegistry and Agent
Managed contracts that allow automation partners to interact with the protocol.
- **AgentRegistry**: Tracks authorized agents and enforces daily spending limits.
- **Agent**: Lightweight proxy contracts owned by external agents to perform plan executions and approvals safely.

### IdentityRegistry
Handles compliance and identity verification.
- Supports ENS-based verification where a specific ENS node must resolve to the plan owner.
- Allows for manual compliance approvals via authorized roles.

### RecipientRegistry
A user-preference store where recipients can specify their preferred chain and token for receiving remittances, assisting agents in selecting the best execution path.

## Security Model

- **RBAC**: Fine-grained access control using OpenZeppelin's `AccessControl`.
- **Whitelisting**: Bridges and targets must be explicitly approved by the protocol admin.
- **Consensus Threshold**: Plans exceeding a specific value require secondary approvals from a second independent agent.
- **Upgradability**: Core components use the UUPS (Universal Upgradeable Proxy Standard) for secure protocol evolution.

## Developer Setup

### Prerequisites
- Node.js
- Hardhat

### Installation
```bash
npm install
```

### Environment Configuration
Create a `.env` file based on the environment requirements:
- `SEPOLIA_RPC_URL`
- `SEPOLIA_PRIVATE_KEY`

### Testing
```bash
npx hardhat test
```

### Deployment
To deploy to Sepolia:
```bash
npx hardhat run scripts/deploy.ts --network sepolia
```
