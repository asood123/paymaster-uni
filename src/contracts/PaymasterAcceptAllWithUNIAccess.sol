// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BasePaymaster} from "account-abstraction/core/BasePaymaster.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
import {UserOperationLib} from "account-abstraction/interfaces/UserOperation.sol";
import {IUni} from "uni/interfaces/IUni.sol";
import {GovernorBravoDelegateStorageV1} from "compound-protocol/contracts/Governance/GovernorBravoInterfaces.sol";

// Same as AcceptAll but also checks that the user has UNI tokens
// Used to test out storage access rules. This works

contract PaymasterAcceptAllWithUNIAccess is BasePaymaster {
    address constant _UNI_TOKEN_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    address constant _GOVERNOR_BRAVO_ADDRESS = 0x408ED6354d4973f66138C91495F2f2FCbd8724C3;

    constructor(IEntryPoint _entryPoint) BasePaymaster(_entryPoint) {
        // to support "deterministic address" factory
        // solhint-disable avoid-tx-origin
        if (tx.origin != msg.sender) {
            _transferOwnership(tx.origin);
        }
    }

    // have to copy this code from UNI contract because first line isn't allowed in the paymaster code
    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address account, uint blockNumber) public view returns (uint96) {
        // require(blockNumber < block.number, "Uni::getPriorVotes: not yet determined");
        IUni uni = IUni(_UNI_TOKEN_ADDRESS);
        //uint32 nCheckpoints = numCheckpoints[account];
        uint32 nCheckpoints = uni.numCheckpoints(account);
        if (nCheckpoints == 0) {
            return 0;
        }

        (uint32 fromBlockIndexNminus1, uint96 votesIndexNminus1) = uni.checkpoints(account, nCheckpoints - 1);
        // First check most recent balance
        if (fromBlockIndexNminus1 <= blockNumber) {
            return votesIndexNminus1;
        }

        // Next check implicit zero balance
        (uint32 fromBlockIndex0, uint96 votesIndex0) = uni.checkpoints(account, 0);
        if (fromBlockIndex0 > blockNumber) {
            return 0;
        }

        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            (uint32 fromBlock, uint96 votes) = uni.checkpoints(account, center);
            // Checkpoint memory cp = checkpoints[account][center];
            if (fromBlock == blockNumber) {
                return votes;
            } else if (fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        (, uint96 votesIndexLower) = uni.checkpoints(account, lower);
        return votesIndexLower;
    }

    function getMintingAllowedAfter() public view returns (uint) {
        IUni uni = IUni(_UNI_TOKEN_ADDRESS);
        return uni.mintingAllowedAfter();
    }

    function _validatePaymasterUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 maxCost)
    internal virtual override view
    returns (bytes memory context, uint256 validationData) {
        (userOp, userOpHash, maxCost);
        uint96 delegatedUni = getPriorVotes(userOp.sender, 0); // technically this is allowed by the spec
        // next line doesn't work.        
        // uint mintingAllowedAfter = getMintingAllowedAfter();
        return ("", 0);
    }

    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost) internal override {
        // //we don't really care about the mode, we just pay the gas with the user's tokens.
        // (mode);
        // address sender = abi.decode(context, (address));
        // //actualGasCost is known to be no larger than the above requiredPreFund, so the transfer should succeed.
        // address(this).call{value: actualGasCost + COST_OF_POST}("");
        
    }
}
