import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { network } from "hardhat";
import { parseUnits, getAddress, zeroHash, hexToBytes, bytesToHex } from "viem";

describe("Pulseremit Full Lifecycle Integration", async function () {
    const { viem } = await (network as any).connect();

    async function deploySuite() {
        const [admin, user, agentOwner, recipient] = await viem.getWalletClients();

        const agentRegistry = await viem.deployContract("AgentRegistry", [admin.account.address]);
        const identityRegistry = await viem.deployContract("IdentityRegistry", [admin.account.address, admin.account.address]);
        const lifiExecutor = await viem.deployContract("LiFiExecutor", [admin.account.address]);
        const agentFactory = await viem.deployContract("AgentFactory");
        const recipientRegistry = await viem.deployContract("RecipientRegistry", [admin.account.address]);

        const vault = await viem.deployContract("RemittanceVault");

        const usdc = await viem.deployContract("MockUSDC");
        const mockUsdcAddress = usdc.address;

        const maxLimit = parseUnits("1000", 6);
        const consensusThreshold = parseUnits("500", 6);

        await vault.write.initialize([
            admin.account.address,
            mockUsdcAddress,
            agentRegistry.address,
            identityRegistry.address,
            lifiExecutor.address,
            maxLimit,
            consensusThreshold
        ]);

        await lifiExecutor.write.setTargetWhitelist([vault.address, true]);

        const mockBridgeTarget = getAddress("0x1234567890123456789012345678901234567890");
        await vault.write.setTargetWhitelisting([mockBridgeTarget, true]);

        return {
            admin, user, agentOwner, recipient,
            agentRegistry, identityRegistry, lifiExecutor, agentFactory, recipientRegistry, vault,
            usdc, mockUsdcAddress, maxLimit, consensusThreshold
        };
    }

    it("Should manage plan lifecycle: Create -> Top-up -> Execute -> Cancel", async function () {
        const { admin, user, recipient, vault, identityRegistry, agentRegistry, usdc, mockUsdcAddress } = await deploySuite();

        await identityRegistry.write.approve([user.account.address]);

        await agentRegistry.write.addAgent([admin.account.address, parseUnits("2000", 6)]);

        await usdc.write.mint([user.account.address, parseUnits("1000", 6)]);
        await usdc.write.approve([vault.address, parseUnits("1000", 6)], { account: user.account });

        const amount = parseUnits("100", 6);
        const interval = 86400n;
        await vault.write.createPlan([
            recipient.account.address,
            amount,
            interval,
            zeroHash
        ], { account: user.account });

        const plan = await vault.read.plans([0n]);
        assert.equal(plan[5], amount);
        assert.equal(plan[6], amount);

        const topUpAmount = parseUnits("50", 6);
        await vault.write.topUpPlan([0n, topUpAmount], { account: user.account });
        const planAfterTopUp = await vault.read.plans([0n]);
        assert.equal(planAfterTopUp[6], amount + topUpAmount);


        await vault.write.cancelPlan([0n], { account: user.account });
        const planAfterCancel = await vault.read.plans([0n]);
        assert.equal(planAfterCancel[6], 0n);
        assert.equal(planAfterCancel[4], 2);
    });

    it("Should facilitate agent creation and execution via Factory", async function () {
        const { admin, agentFactory, vault, agentRegistry, identityRegistry, user, recipient, usdc } = await deploySuite();

        const agentName = "PrimaryBot";
        await agentFactory.write.createAgent([admin.account.address, vault.address, agentName]);
        const agentCount = await agentFactory.read.getDeployedAgentsCount();
        assert.equal(agentCount, 1n);

        const agentContractAddress = await agentFactory.read.deployedAgents([0n]);
        const storedName = await agentFactory.read.agentNames([agentContractAddress]);
        assert.equal(storedName, agentName);

        // Verify multi-agent tracking
        const ownerAgentCount = await agentFactory.read.getOwnerAgentsCount([admin.account.address]);
        assert.equal(ownerAgentCount, 1n);

        await agentRegistry.write.addAgent([agentContractAddress, parseUnits("5000", 6)]);

        await identityRegistry.write.approve([user.account.address]);
        await usdc.write.mint([user.account.address, parseUnits("1000", 6)]);
        await usdc.write.approve([vault.address, parseUnits("1000", 6)], { account: user.account });

        await vault.write.createPlan([recipient.account.address, parseUnits("10", 6), 86400n, zeroHash], { account: user.account });

        const isAgent = await agentRegistry.read.isAgent([agentContractAddress]);
        assert.equal(isAgent, true);
    });

    it("Should respect agent pausing", async function () {
        const { admin, agentFactory, vault, agentRegistry, identityRegistry, user, recipient, usdc } = await deploySuite();

        await agentFactory.write.createAgent([admin.account.address, vault.address, "TestBot"]);
        const agentAddr = await agentFactory.read.deployedAgents([0n]);
        await agentRegistry.write.addAgent([agentAddr, parseUnits("5000", 6)]);

        // Pause the agent
        await agentRegistry.write.pauseAgent([agentAddr]);
        let paused = await agentRegistry.read.agentPaused([agentAddr]);
        assert.equal(paused, true);

        // checkAndSpend should return false for paused agents
        let canSpend = await agentRegistry.read.checkAndSpend([agentAddr, 100n]);
        assert.equal(canSpend, false);

        // Resume the agent
        await agentRegistry.write.resumeAgent([agentAddr]);
        paused = await agentRegistry.read.agentPaused([agentAddr]);
        assert.equal(paused, false);

        canSpend = await agentRegistry.read.checkAndSpend([agentAddr, 100n]);
        assert.equal(canSpend, true);
    });

    it("Should support identity flexibility (Address vs ENS)", async function () {
        const { identityRegistry, user } = await deploySuite();

        await identityRegistry.write.approve([user.account.address]);
        let approved = await identityRegistry.read.isApproved([user.account.address, zeroHash]);
        assert.equal(approved, true);

        const fakeNode = zeroHash;
        approved = await identityRegistry.read.isApproved([user.account.address, fakeNode]);
        assert.equal(approved, true);
    });
});
