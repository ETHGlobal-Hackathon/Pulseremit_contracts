// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Agent} from "./Agent.sol";

contract AgentFactory {
    address[] public deployedAgents;
    mapping(address => bool) public isAgentContract;

    event AgentCreated(address indexed agentAddress, address indexed owner, address vault);

    function createAgent(address owner, address vault) external returns (address) {
        Agent newAgent = new Agent(owner, vault);
        address agentAddr = address(newAgent);
        
        deployedAgents.push(agentAddr);
        isAgentContract[agentAddr] = true;

        emit AgentCreated(agentAddr, owner, vault);
        return agentAddr;
    }

    function getDeployedAgentsCount() external view returns (uint256) {
        return deployedAgents.length;
    }
}
