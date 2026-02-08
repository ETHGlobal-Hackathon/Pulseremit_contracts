import { parseUnits, getAddress } from "viem";
import { network } from "hardhat";

async function main() {
    const { viem } = await (network as any).connect();
    const [deployer] = await viem.getWalletClients();

    console.log("Deploying Pulseremit suite with account:", deployer.account.address);

    const ensRegistryAddress = getAddress("0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e");
    const usdcAddress = getAddress("0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238");

    const agentRegistry = await viem.deployContract("AgentRegistry", [deployer.account.address]);
    console.log("AgentRegistry deployed to:", agentRegistry.address);

    const identityRegistry = await viem.deployContract("IdentityRegistry", [deployer.account.address, ensRegistryAddress]);
    console.log("IdentityRegistry deployed to:", identityRegistry.address);

    const lifiExecutor = await viem.deployContract("LiFiExecutor", [deployer.account.address]);
    console.log("LiFiExecutor deployed to:", lifiExecutor.address);

    const recipientRegistry = await viem.deployContract("RecipientRegistry", [deployer.account.address]);
    console.log("RecipientRegistry deployed to:", recipientRegistry.address);

    const agentFactory = await viem.deployContract("AgentFactory");
    console.log("AgentFactory deployed to:", agentFactory.address);

    const vault = await viem.deployContract("RemittanceVault");
    console.log("RemittanceVault (Implementation) deployed to:", vault.address);

    const maxLimit = parseUnits("1000", 6);
    const consensusThreshold = parseUnits("500", 6);

    const publicClient = await viem.getPublicClient();

    const hashInit = await vault.write.initialize([
        deployer.account.address,
        usdcAddress,
        agentRegistry.address,
        identityRegistry.address,
        lifiExecutor.address,
        maxLimit,
        consensusThreshold
    ]);
    await publicClient.waitForTransactionReceipt({ hash: hashInit });
    console.log("RemittanceVault initialized.");

    const hashWhitelistVault = await lifiExecutor.write.setTargetWhitelist([vault.address, true]);
    await publicClient.waitForTransactionReceipt({ hash: hashWhitelistVault });
    console.log("Vault whitelisted in LiFiExecutor.");

    const mockBridgeTarget = getAddress("0x1234567890123456789012345678901234567890");
    const hashWhitelistTarget = await vault.write.setTargetWhitelisting([mockBridgeTarget, true]);
    await publicClient.waitForTransactionReceipt({ hash: hashWhitelistTarget });
    console.log("Mock bridge target whitelisted in Vault.");

    console.log("--- Deployment Summary ---");
    console.log(`AgentRegistry: ${agentRegistry.address}`);
    console.log(`IdentityRegistry: ${identityRegistry.address}`);
    console.log(`RecipientRegistry: ${recipientRegistry.address}`);
    console.log(`AgentFactory: ${agentFactory.address}`);
    console.log(`LiFiExecutor: ${lifiExecutor.address}`);
    console.log(`RemittanceVault: ${vault.address}`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
