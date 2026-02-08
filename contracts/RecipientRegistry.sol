// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract RecipientRegistry is AccessControl {
    struct RecipientProfile {
        uint256 preferredChainId;
        address preferredToken;
        address destinationAddress;
        string ensName;
    }

    mapping(address => RecipientProfile) public profiles;

    event ProfileUpdated(
        address indexed recipient,
        uint256 preferredChainId,
        address preferredToken,
        address destinationAddress,
        string ensName
    );

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function updateProfile(
        uint256 preferredChainId,
        address preferredToken,
        address destinationAddress,
        string calldata ensName
    ) external {
        profiles[msg.sender] = RecipientProfile({
            preferredChainId: preferredChainId,
            preferredToken: preferredToken,
            destinationAddress: destinationAddress,
            ensName: ensName
        });

        emit ProfileUpdated(
            msg.sender,
            preferredChainId,
            preferredToken,
            destinationAddress,
            ensName
        );
    }

    function getProfile(address recipient) external view returns (RecipientProfile memory) {
        return profiles[recipient];
    }
}
