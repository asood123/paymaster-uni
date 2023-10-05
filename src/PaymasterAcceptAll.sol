// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BasePaymaster} from "account-abstraction/core/BasePaymaster.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
import {UserOperationLib} from "account-abstraction/interfaces/UserOperation.sol";

contract PaymasterAcceptAll is BasePaymaster {
    uint256 public number;

    constructor(IEntryPoint _entryPoint) BasePaymaster(_entryPoint) {
        // to support "deterministic address" factory
        // solhint-disable avoid-tx-origin
        if (tx.origin != msg.sender) {
            _transferOwnership(tx.origin);
        }
    }

    function _validatePaymasterUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 maxCost)
    internal virtual override view
    returns (bytes memory context, uint256 validationData) {
        (userOp, userOpHash, maxCost);
        return ("", maxCost == 12345 ? 1 : 0);
    }

    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost) internal override {
        // //we don't really care about the mode, we just pay the gas with the user's tokens.
        // (mode);
        // address sender = abi.decode(context, (address));
        // //actualGasCost is known to be no larger than the above requiredPreFund, so the transfer should succeed.
        // address(this).call{value: actualGasCost + COST_OF_POST}("");
        
    }
}
