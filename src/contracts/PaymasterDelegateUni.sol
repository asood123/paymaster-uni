// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BasePaymaster} from "account-abstraction/core/BasePaymaster.sol";
import {Pausable} from "openzeppelin-contracts/security/Pausable.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
import {UserOperationLib} from "account-abstraction/interfaces/UserOperation.sol";
import {IUni} from "uni/interfaces/IUni.sol";
import "account-abstraction/core/Helpers.sol";
import "forge-std/console.sol";

// This paymaster pays only for delegating UNI tokens to a specific address
contract PaymasterDelegateUni is BasePaymaster, Pausable {
    
    // in ETH
    uint256 private _maxCostAllowed = 100_000_000_000_000_000; // TODO: calculate reasonable upper bound and update
    uint256 private _minWaitBetweenDelegations = 30 days; 

    // blocklist - tracks any address whose transaction reverts
    mapping(address => bool) public blocklist;

    // Track the last known delegation happened from this account
    // TODO: confirm that this data can't be reliably read from the UNI contract
    // afaict, the UNI contract only records checkpoints based on the delegatee (not the delegator)
    // so we can't tell when the last delegation happened from a specific account
    // thus, we'll keep track of it from our own contract
    mapping(address => uint256) public lastDelegationTimestamp;


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

    function getMinWaitBetweenDelegations() public view returns (uint256) {
        return _minWaitBetweenDelegations;
    }

    function updateMinWaitBetweenDelegations(uint256 minWait) public onlyOwner {
        require(minWait > 1 days, "minWait must be greater than 0");
        _minWaitBetweenDelegations = minWait;
    }

    /* Helpers for validation */
    function _verifyCallDataForDelegateAction(bytes calldata callData) internal pure {
        
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

        require(callData.length == 196, "callData must be 196 bytes");
        // extract initial `execute` signature
        // need to extract this separately because of the way abi.decode works
        bytes4 executeSig = bytes4(callData[:4]);
        require(executeSig == bytes4(keccak256("execute(address,uint256,bytes)")), "incorrect execute signature");        
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
        require(toAddress == 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984, "address needs to point to UNI token address");
        require(value == 0, "value needs to be 0"); // no need to send any money to paymaster
        require(data1 == hex"0000000000000000000000000000000000000000000000000000000000000060", "data1 needs to be 0x60");
        require(data2 == hex"0000000000000000000000000000000000000000000000000000000000000024", "data2 needs to be 0x24");
        require(bytes4(delegateHash) == bytes4(keccak256("delegate(address)")), "incorrect delegate signature");
        require(delegatee != address(0), "delegatee cannot be 0x0");
    }

    function _verifyUniHolding(address sender) internal view {
        IUni uni = IUni(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
        uint256 uniBalance = uni.balanceOf(sender);
        require(uniBalance > 0, "sender does not hold any UNI");
    }

    function _validatePaymasterUserOp(UserOperation calldata userOp, bytes32, uint256 maxCost)
    internal virtual override view whenNotPaused
    returns (bytes memory context, uint256 validationData) {

        // check maxCost is less than _maxCostAllowed
        // TODO: reenable after we get a working version
        require(maxCost < _maxCostAllowed, "maxCost exceeds allowed amount");
        
        _verifyCallDataForDelegateAction(userOp.callData);

        // verify that sender holds UNI
        _verifyUniHolding(userOp.sender);


        // calculate minTimestamp that the user can delegate again
        uint256 validAfter = lastDelegationTimestamp[userOp.sender] + _minWaitBetweenDelegations;

        //Helpers._packValidationData(false, validUntil, validAfter)
        // TODO: confirm if validAfter is 30 days away, does the Bundler holds it until then? Or does it
        // have an expiration?
        return (abi.encode(userOp.sender), _packValidationData(false, uint48(0), uint48(validAfter))); 
    }

    // called twice if first call reverts
    function _postOp(PostOpMode mode, bytes calldata context, uint256) internal override {
        // need to handle three outcomes: opSucceeded, opReverted, postOpReverted
        // 1. opSucceeded: do nothing
        if (mode == PostOpMode.opSucceeded) {
            (address caller) = abi.decode(context, (address));
            // TODO: record a successful delegation? Is this needed? Could read straight from UNI contract
            lastDelegationTimestamp[caller] = block.timestamp;
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

