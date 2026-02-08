// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Agent} from "./Agent.sol";

contract AgentFactory {
    address[] public deployedAgents;
    mapping(address => bool) public isAgentContract;
    mapping(address => address[]) public ownerAgents;
    mapping(address => string) public agentNames;

    event AgentCreated(address indexed agentAddress, address indexed owner, address vault, string name);

    function createAgent(address owner, address vault, string calldata name) external returns (address) {
        Agent newAgent = new Agent(owner, vault);
        address agentAddr = address(newAgent);
        
        deployedAgents.push(agentAddr);
        isAgentContract[agentAddr] = true;
        ownerAgents[owner].push(agentAddr);
        agentNames[agentAddr] = name;

        emit AgentCreated(agentAddr, owner, vault, name);
        return agentAddr;
    }

    function getDeployedAgentsCount() external view returns (uint256) {
        return deployedAgents.length;
    }

    function getOwnerAgentsCount(address owner) external view returns (uint256) {
        return ownerAgents[owner].length;
    }
}
