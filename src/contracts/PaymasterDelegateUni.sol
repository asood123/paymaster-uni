// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BasePaymaster} from "account-abstraction/core/BasePaymaster.sol";
import {Pausable} from "openzeppelin-contracts/security/Pausable.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
import {UserOperationLib} from "account-abstraction/interfaces/UserOperation.sol";
import {IUni} from "uni/interfaces/IUni.sol";
import "forge-std/console.sol";

// This paymaster pays only for delegating UNI tokens to a specific address
contract PaymasterDelegateUni is BasePaymaster, Pausable {
    
    // constants
    address constant _UNI_TOKEN_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    bytes32 constant _EXECUTE_TYPEHASH = keccak256("execute(address,uint256,bytes)");

    bytes32 constant _DELEGATE_TYPEHASH = keccak256("delegate(address)");
    bytes32 constant _DELEGATE_DATA_PART_1 = hex"0000000000000000000000000000000000000000000000000000000000000060"; // based on observed data
    bytes32 constant _DELEGATE_DATA_PART_2 = hex"0000000000000000000000000000000000000000000000000000000000000024"; // based on observed data

    // in ETH
    uint256 private _maxCostAllowed = 100_000_000_000_000_000; // TODO: calculate reasonable upper bound and update

    // blocklist - tracks any address whose transaction reverts
    mapping(address => bool) public blocklist;

    constructor(IEntryPoint _entryPoint) BasePaymaster(_entryPoint) {
        // TODO: figure out if this is needed in our implementation
        // to support "deterministic address" factory
        // solhint-disable avoid-tx-origin
        if (tx.origin != msg.sender) {
            _transferOwnership(tx.origin);
        }
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /* HELPERS for Paymaster state*/
    function getMaxCostAllowed() public view returns (uint256) {
        return _maxCostAllowed;
    }

    function updateMaxCostAllowed(uint256 maxCost) public onlyOwner {
        _maxCostAllowed = maxCost;
    }

    /* Helpers for validation */
    function _verifyCallDataForDelegateAction(bytes calldata callData) internal pure {
        require(callData.length == 196, "callData must be 196 bytes");
        // extract initial `execute` signature
        // need to extract this separately because of the way abi.decode works
        bytes4 executeSig = bytes4(callData[:4]);
        require(executeSig == bytes4(_EXECUTE_TYPEHASH), "incorrect execute signature");        
        // extract rest of info from callData
        (
            address toAddress, 
            bytes32 value, 
            bytes32 data1, 
            bytes32 data2
            ) = abi.decode(callData[4:132],(address, bytes32, bytes32, bytes32));
        bytes4 delegateHash = bytes4(callData[132:136]);
        address delegatee = abi.decode(callData[136:168], (address));
        // note that there is additional 28 bytes of filler data at the end

        // check each one
        require(toAddress == _UNI_TOKEN_ADDRESS, "address needs to point to UNI token address");
        require(value == 0, "value needs to be 0"); // no need to send any money to paymaster
        require(data1 == _DELEGATE_DATA_PART_1, "data1 needs to be 0x60");
        require(data2 == _DELEGATE_DATA_PART_2, "data2 needs to be 0x44");
        require(bytes4(delegateHash) == bytes4(_DELEGATE_TYPEHASH), "incorrect delegate signature");
        require(delegatee != address(0), "delegatee cannot be 0x0");
    }



    function _validatePaymasterUserOp(UserOperation calldata userOp, bytes32, uint256 maxCost)
    internal virtual override view whenNotPaused
    returns (bytes memory context, uint256 validationData) {

        // check maxCost is less than _maxCostAllowed
        require(maxCost < _maxCostAllowed, "maxCost exceeds allowed amount");
        // need to verify two paths: either castVote or delegate
        _verifyCallDataForDelegateAction(userOp.callData);
        // TODO: need additional checks like only allow delegation once x period of time
        
        return (abi.encodePacked(userOp.sender), 0); 
    }

    // called twice if first call reverts
    function _postOp(PostOpMode mode, bytes calldata context, uint256) internal override {
        // need to handle three outcomes: opSucceeded, opReverted, postOpReverted
        // 1. opSucceeded: do nothing
        if (mode == PostOpMode.opSucceeded) {
            (address caller) = abi.decode(context, (address));
            // TODO: record a successful delegation? Is this needed? Could read straight from UNI contract
        }
        // 2. opReverted: record caller address in a blocklist?
        else if (mode == PostOpMode.opReverted) {
            (address caller) = abi.decode(context, (address));
            blocklist[caller] = true;
        // 3. postOpReverted: not applicable. Based on current implementation, this should never happen
        } else {
            // TODO: is it worth throwing an error?
        }
    }
}

    // NOTES. TODO: remove before finalizing. Can use these for docs
    // example
    // encodeFunctionData("execute", [to, value, data])
    // calldata: "0xb61d27f60000000000000000000000004bd047ca72fa05f0b89ad08fe5ba5ccdc07dffbf00000000000000000000000000000000000000000000000000038d7ea4c6800000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000"
    // 0x
    // 4: b61d27f6
    // 64: 0000000000000000000000004bd047ca72fa05f0b89ad08fe5ba5ccdc07dffbf
    // 64: 00000000000000000000000000000000000000000000000000038d7ea4c68000
    // 64: 0000000000000000000000000000000000000000000000000000000000000060
    // 64: 0000000000000000000000000000000000000000000000000000000000000000
    
    // check userOp.calldata is:
    // - an instance of SimpleAccount
    // - first 4 bytes is a call to "execute" (same as above)
    // - next 32 bytes are the addres of governor bravo
    // - next 32 bytes are 0 (no value sent)
    // - ignore next 64 bytes
    // - next 32 bytes are for "castVote"
    // - next 32 bytes are the proposalId
    // - next 32 bytes are the support (1 for yes, 0 for no)

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


    // UNI Delegate call
    // 0x
    // b61d27f6 "execute" hash
    // 0000000000000000000000001f9840a85d5af5bf1d1762f925bdaddc4201f984 Uni address
    // 0000000000000000000000000000000000000000000000000000000000000000 value
    // 0000000000000000000000000000000000000000000000000000000000000060 data1
    // 0000000000000000000000000000000000000000000000000000000000000024 data2
    // 5c19a95c "delegate" hash
    // 000000000000000000000000b6c7ff166b0d27aa6132673838995f0fa68c7676 delgatee
    // 00000000000000000000000000000000000000000000000000000000 filler
