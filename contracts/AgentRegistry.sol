// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract AgentRegistry is AccessControl {
    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");

    mapping(address => uint256) public agentDailyLimits;
    mapping(address => uint256) public agentDailySpent;
    mapping(address => uint256) public lastSpentReset;

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function addAgent(address agent, uint256 dailyLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(AGENT_ROLE, agent);
        agentDailyLimits[agent] = dailyLimit;
    }

    function removeAgent(address agent) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(AGENT_ROLE, agent);
        agentDailyLimits[agent] = 0;
    }

    function setAgentLimit(address agent, uint256 dailyLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        agentDailyLimits[agent] = dailyLimit;
    }

    function checkAndSpend(address agent, uint256 amount) external returns (bool) {
        if (!hasRole(AGENT_ROLE, agent)) return false;
        
        uint256 currentDay = block.timestamp / 1 days;
        if (lastSpentReset[agent] < currentDay) {
            agentDailySpent[agent] = 0;
            lastSpentReset[agent] = currentDay;
        }

        if (agentDailySpent[agent] + amount > agentDailyLimits[agent]) return false;

        agentDailySpent[agent] += amount;
        return true;
    }

    function isAgent(address agent) external view returns (bool) {
        return hasRole(AGENT_ROLE, agent);
    }
}
