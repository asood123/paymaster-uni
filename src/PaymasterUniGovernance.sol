// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BasePaymaster} from "account-abstraction/core/BasePaymaster.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
import {UserOperationLib} from "account-abstraction/interfaces/UserOperation.sol";
import "forge-std/console.sol";

contract PaymasterUniGovernance is BasePaymaster {
    uint256 public number;
    bytes32 constant EXECUTE_TYPEHASH = keccak256("execute(address,uint256,bytes)");
    address constant GOVERNOR_BRAVO_ADDRESS = 0x408ED6354d4973f66138C91495F2f2FCbd8724C3;
    bytes32 constant CASTVOTE_TYPEHASH = keccak256("castVote(uint256,uint8)");
    bytes32 constant DATA_PART_1 = hex"0000000000000000000000000000000000000000000000000000000000000060";
    bytes32 constant DATA_PART_2 = hex"0000000000000000000000000000000000000000000000000000000000000044";


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

        // example
        // encodeFunctionData("execute", [to, value, data])
        // calldata: "0xb61d27f60000000000000000000000004bd047ca72fa05f0b89ad08fe5ba5ccdc07dffbf00000000000000000000000000000000000000000000000000038d7ea4c6800000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000"
        // 0x
        // 32: b61d27f6000000000000000000000000
        // 40: 4bd047ca72fa05f0b89ad08fe5ba5ccdc07dffbf
        // 64: 00000000000000000000000000000000000000000000000000038d7ea4c68000
        // 64: 0000000000000000000000000000000000000000000000000000000000000060
        // 64: 0000000000000000000000000000000000000000000000000000000000000000
        
        // check userOp.calldata is:
        // - an instance of SimpleAccount
        // - first 32 bytes is a call to "execute" (same as above)
        // - next 40 bytes are the addres of governor bravo
        // - next 64 bytes are 0 (no value sent)
        // - ignore next 128 bytes
        // - next 64 bytes are for "castVote"
        // - next 64 bytes are the proposalId
        // - next 64 bytes are the support (1 for yes, 0 for no)

        // could also call governorBravo on chain to confirm if a proposal is currently pending?
        /*
        enum ProposalState {
            Pending,
            Active,
            Canceled,
            Defeated,
            Succeeded,
            Queued,
            Expired,
            Executed
        }*/

        // governorbravo vote call
        // 0x
        // 32: b61d27f6 "execute"
        // 64: 000000000000000000000000408ed6354d4973f66138c91495f2f2fcbd8724c3 "governorBravoAddress"
        // 64: 0000000000000000000000000000000000000000000000000000000000000000 "value"
        // rest: data
        // 0000000000000000000000000000000000000000000000000000000000000060
        // 0000000000000000000000000000000000000000000000000000000000000044
        // 5678138800000000000000000000000000000000000000000000000000000000 "castVote"
        // 0000000000000000000000000000000000000000000000000000000000000000 "proposalId"
        // 0000000100000000000000000000000000000000000000000000000000000000 "support"

        // 0x
        // 32: b61d27f6 "execute"
        // 64: 000000000000000000000000408ed6354d4973f66138c91495f2f2fcbd8724c3 "governorBravoAddress"
        // 64: 0000000000000000000000000000000000000000000000000000000000000000 "value" Payable
        // rest: data
        // 0000000000000000000000000000000000000000000000000000000000000060
        // 0000000000000000000000000000000000000000000000000000000000000044
        // 5678138800000000000000000000000000000000000000000000000000000000 "castVote"
        // 0000000000000000000000000000000000000000000000000000000000000033 "proposalId"
        // 0000000100000000000000000000000000000000000000000000000000000000 "support"
        // (uint256 execute, address toAddress) = abi.decode(userOp.callData[:72],(uint256, address));
        // (uint256 value, uint256 data1, uint256 data2, uint256 castVote, uint256 proposalId, uint256 support) = abi.decode(userOp.callData[72:],(uint256, uint256, uint256, uint256, uint256, uint256));
        // check execute is 0x56781388

        // check toAddress is governorBravoAddress
        // check value is 0
        // check data1 is ?
        // check data2 is ?
        // check castVote is 0x56781388
        // check proposalId is ?
        // check support is 1 or 0

        // signature = paymasterAndData[SIGNATURE_OFFSET:];
        return ("", maxCost == 12345 ? 1 : 0);
    }

    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost) internal override {
        // //we don't really care about the mode, we just pay the gas with the user's tokens.
        // (mode);
        // address sender = abi.decode(context, (address));
        // //actualGasCost is known to be no larger than the above requiredPreFund, so the transfer should succeed.
        // address(this).call{value: actualGasCost + COST_OF_POST}("");
        
    }

    function _verifyCallData(bytes calldata callData) external view returns (bool) {
        // need to extract this separately because of the way abi.decode works
        bytes4 executeSig = bytes4(callData[:4]);
        (
            address toAddress, 
            bytes32 value, 
            bytes32 data1, 
            bytes32 data2, 
            bytes32 castVoteHash,
            uint256 proposalId,
            uint256 support256
            ) = abi.decode(callData[4:],(address, bytes32, bytes32, bytes32, bytes32, uint256, uint256));

        if (executeSig != bytes4(EXECUTE_TYPEHASH)) return false;
        if (toAddress != GOVERNOR_BRAVO_ADDRESS) return false;
        if (value != 0) return false;
        if (data1 != DATA_PART_1) return false;
        if (data2 != DATA_PART_2) return false;
        // console.logBytes4(bytes4(CASTVOTE_TYPEHASH));
        // console.logBytes4(bytes4(castVoteHash));
        if (bytes4(castVoteHash) != bytes4(CASTVOTE_TYPEHASH)) return false;

        // TODO: can we call governorBravo on chain to confirm if a proposal is currently pending?
        uint8 proposalState = GOVERNOR_BRAVO_ADDRESS.call(bytes4(keccak256("state(uint256)")),proposalId);
        // require(proposalState, "GovernorBravo call failed");
                /*
        enum ProposalState {
            Pending,
            Active,
            Canceled,
            Defeated,
            Succeeded,
            Queued,
            Expired,
            Executed
        }*/
        console.log(proposalState);
        if (proposalState != 1) return false;
//        console.logUint(proposalId);
//        if (proposalId < 51 || proposalId > 100) return false; // TODO: update this if above check is confirmed
        uint8 support = uint8(support256);

        console.logUint(support256);
        console.logUint(support);

        if (support != 0 && support != 1 && support != 2) return false;
        return true;
    }

    function bytesToAddress(bytes memory bys) private pure returns (address addr) {
        assembly {
        addr := mload(add(bys,20))
        } 
    }
}
