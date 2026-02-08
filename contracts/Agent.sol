// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

interface IRemittanceVault {
    function approvePlan(uint256) external;
    function executePlan(uint256, address, bytes calldata, uint256, address) external;
}

contract Agent is AccessControl {
    IRemittanceVault public vault;

    constructor(address owner, address vault_) {
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        vault = IRemittanceVault(vault_);
    }

    function approvePlan(uint256 planId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        vault.approvePlan(planId);
    }

    function executePlan(
        uint256 planId,
        address target,
        bytes calldata bridgeData,
        uint256 feesSaved,
        address secondaryAgent
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        vault.executePlan(planId, target, bridgeData, feesSaved, secondaryAgent);
    }
}
