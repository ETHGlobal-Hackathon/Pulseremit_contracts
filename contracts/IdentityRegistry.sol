// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

interface IENS {
    function resolver(bytes32 node) external view returns (address);
}

interface IResolver {
    function addr(bytes32 node) external view returns (address);
    function name(bytes32 node) external view returns (string memory);
}

contract IdentityRegistry is AccessControl {
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");

    IENS public ensRegistry;
    mapping(address => bool) public complianceApproved;

    event ComplianceApproved(address indexed account);
    event ComplianceRevoked(address indexed account);

    constructor(address admin, address ens) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(COMPLIANCE_ROLE, admin);
        ensRegistry = IENS(ens);
    }

    function approve(address account) external onlyRole(COMPLIANCE_ROLE) {
        complianceApproved[account] = true;
        emit ComplianceApproved(account);
    }

    function revoke(address account) external onlyRole(COMPLIANCE_ROLE) {
        complianceApproved[account] = false;
        emit ComplianceRevoked(account);
    }

    function isApproved(address account, bytes32 node) external view returns (bool) {
        if (complianceApproved[account]) return true;
        if (node == bytes32(0)) return false;
        
        address resolverAddr = ensRegistry.resolver(node);
        if (resolverAddr == address(0)) return false;
        return IResolver(resolverAddr).addr(node) == account;
    }

    function isIdentified(address account, bytes32 node) external view returns (bool) {
        address resolverAddr = ensRegistry.resolver(node);
        if (resolverAddr == address(0)) return false;
        return IResolver(resolverAddr).addr(node) == account;
    }
}
