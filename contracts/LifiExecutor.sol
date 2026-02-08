// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract LiFiExecutor is AccessControl {
    using SafeERC20 for IERC20;
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    mapping(address => bool) public whitelistedTargets;

    event ExecutionSuccess(address indexed token, address indexed target, uint256 amount);
    event TargetWhitelisted(address indexed target, bool status);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EXECUTOR_ROLE, admin);
    }

    function setTargetWhitelist(address target, bool status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        whitelistedTargets[target] = status;
        emit TargetWhitelisted(target, status);
    }

    function execute(
        address token,
        address target,
        uint256 amount,
        bytes calldata data
    ) external onlyRole(EXECUTOR_ROLE) {
        require(whitelistedTargets[target], "Target not whitelisted");
        
        IERC20 token_ = IERC20(token);
        token_.safeTransferFrom(msg.sender, address(this), amount);
        token_.approve(target, amount);

        (bool success, bytes memory result) = target.call(data);
        if (!success) {
            if (result.length > 0) {
                assembly {
                    let returndata_size := mload(result)
                    revert(add(32, result), returndata_size)
                }
            } else {
                revert("LI.FI call failed");
            }
        }

        emit ExecutionSuccess(token, target, amount);
    }

    function rescueToken(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(token).safeTransfer(to, amount);
    }
}
