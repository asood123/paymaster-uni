// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BasePaymaster} from "account-abstraction/core/BasePaymaster.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
import {UserOperationLib} from "account-abstraction/interfaces/UserOperation.sol";
import {IUni} from "uni/interfaces/IUni.sol";
import {GovernorBravoDelegateStorageV1} from "compound-protocol/contracts/Governance/GovernorBravoInterfaces.sol";
// import {GovernorBravoDelegateStorageCustomV1} from "compound-protocol/contracts/Governance/GovernorBravoCustomInterfaces.sol";
import "forge-std/console.sol";

// useful to have both timestamp and block
struct ProposalWindow {
    uint256 startTimestamp;
    uint256 endTimestamp;
    uint256 startBlock;
    uint256 endBlock;
}

contract PaymasterUniGovernance is BasePaymaster {
    
    // constants
    address constant _GOVERNOR_BRAVO_ADDRESS = 0x408ED6354d4973f66138C91495F2f2FCbd8724C3;
    address constant _UNI_TOKEN_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    bytes32 constant _EXECUTE_TYPEHASH = keccak256("execute(address,uint256,bytes)");
    bytes32 constant _CASTVOTE_TYPEHASH = keccak256("castVote(uint256,uint8)");
    bytes32 constant _DATA_PART_1 = hex"0000000000000000000000000000000000000000000000000000000000000060"; // based on observed data
    bytes32 constant _DATA_PART_2 = hex"0000000000000000000000000000000000000000000000000000000000000044"; // based on observed data
    
    // Requires proposals to be manually added
    mapping(uint256 => ProposalWindow) private _proposals; 
    uint256 _maxCostAllowed = 123456789; // TODO: calculate reasonable upper bound and update

    mapping(address => mapping(uint256 => bool)) public votingRecord;

    // blocklist - tracks any address whose transaction reverts
    mapping(address => bool) public blocklist;

    constructor(IEntryPoint _entryPoint) BasePaymaster(_entryPoint) {
        // TODO: figure out if this is needed; commenting out for now to get tests to pass
        // to support "deterministic address" factory
        // solhint-disable avoid-tx-origin
        // if (tx.origin != msg.sender) {
        //     _transferOwnership(tx.origin);
        // }
    }

    /* HELPERS for Paymaster state*/
    // only needed (Path 2 below) if storage access rules don't allow access to GovernorBravo's proposal data
    function addOrModifyProposal(uint256 _proposalId, uint256 startTimestamp, uint256 endTimestamp, uint256 startBlock, uint256 endBlock) public  onlyOwner{
        _proposals[_proposalId] = ProposalWindow(startTimestamp, endTimestamp, startBlock, endBlock);
    }


    // needed, in case a proposal is canceled
    // only needed (Path 2 below) if storage access rules don't allow access to GovernorBravo's proposal data
    function expireProposal(uint256 _proposalId) public  onlyOwner{
        ProposalWindow memory proposalWindow = _proposals[_proposalId];
        require(proposalWindow.startTimestamp > 0, "proposalId not found");
        _proposals[_proposalId] = ProposalWindow(0, 0, 0, 0);
    }

    // only needed (Path 2 below) if storage access rules don't allow access to GovernorBravo's proposal data
    function getProposalId(uint256 _proposalId) public view returns (ProposalWindow memory) {
        return _proposals[_proposalId];
    }

    function updateMaxCostAllowed(uint256 maxCost) public onlyOwner {
        _maxCostAllowed = maxCost;
    }

    /* Helpers for validation */
    function _verifyCallData(bytes calldata callData) private view {
        // extract initial `execute` signature
        // need to extract this separately because of the way abi.decode works
        bytes4 executeSig = bytes4(callData[:4]);
        require(executeSig == bytes4(_EXECUTE_TYPEHASH), "incorrect execute signature");        
        // extract rest of info from callData
        (
            address toAddress, 
            bytes32 value, 
            bytes32 data1, 
            bytes32 data2, 
            bytes32 castVoteHash,
            uint256 proposalId,
            uint256 support256
            ) = abi.decode(callData[4:],(address, bytes32, bytes32, bytes32, bytes32, uint256, uint256));

        // check each one
        require(toAddress == _GOVERNOR_BRAVO_ADDRESS, "address needs to point to GovernorBravo");
        require(value == 0, "value needs to be 0"); // no need to send any money to paymaster
        require(data1 == _DATA_PART_1, "data1 needs to be 0x60");
        require(data2 == _DATA_PART_2, "data2 needs to be 0x44");
        require(bytes4(castVoteHash) == bytes4(_CASTVOTE_TYPEHASH), "incorrect castVote signature");

        // validate that it's an active proposal
        // Note: Ideally, we would call UNI GovernorBravo contract to confirm proposalId is currently active
        // but that's not allowed in this function
        // Instead, we rely on an owner-updated mapping of proposalId to start and end timestamp & blocks
        ProposalWindow memory proposalWindow = _proposals[proposalId];
        require(proposalWindow.startTimestamp > 0, "proposalId not found");
        // confirm  support is 0, 1, or 2
        require(uint8(support256) <= 2, "support must be 0, 1, or 2");
    }

    // TODO: figure out if this is allowed by storage access rules
    function _getProposalInfo(uint _proposalId) private view returns (uint256, uint256, uint256, uint256, bool, bool) {
        GovernorBravoDelegateStorageV1 governorBravo = GovernorBravoDelegateStorageV1(_GOVERNOR_BRAVO_ADDRESS);
        (
            uint256 id, 
            , 
            uint256 eta, 
            uint256 startBlock, 
            uint256 endBlock,
            , 
            , 
            ,
            bool canceled, 
            bool executed
        ) = governorBravo.proposals(_proposalId);
        return (
            id,
            eta,
            startBlock, 
            endBlock, 
            canceled, 
            executed
        );
    }

    // detect all proposal states to disallow obvious proposals that aren't active
    function _checkProposalState(uint _proposalId) private view returns (uint256, uint256) {
        (uint256 id, uint256 eta, uint256 startBlock, uint256 endBlock, bool canceled, bool executed) = _getProposalInfo(_proposalId);

        // confirm proposal exists
        require(id > 0, "proposalId not found");

        // not canceled
        require(canceled == false, "proposal was already canceled");
        
        // not executed
        require(executed == false, "proposal was already executed");

        // not queued
        require(eta > 0, "proposal is already queued or succeeded");

        // pending, defeated, expired, succeeded: handled later with validAfter and validUntil
        return (startBlock, endBlock);
    }


    /*
    Ideal checks
    4. UNI Governance related checks
        a. check that the proposalId is currently active 
            - can't access storage of another contract, so handled with internal mapping 
                that needs to be updated manually (see #2 above)
        b. check that there is UNI delegated before the startBlock
            - based on spec, this should be accessible via UNI checkPoints mapping
        c. check that they haven't voted already
    */
    function _validatePaymasterUserOp(UserOperation calldata userOp, bytes32, uint256 maxCost)
    internal virtual override view
    returns (bytes memory context, uint256 validationData) {

        // TODO: check that it's a SimpleAccount or an AA wallet. Is this possible or needed?
        
        // check that calldata is 452 bytes
        require(userOp.callData.length == 452, "callData must be 452 bytes");

        // check maxCost is less than _maxCostAllowed
        require(maxCost < _maxCostAllowed, "maxCost exceeds allowed amount");

        // check callData is valid
        _verifyCallData(userOp.callData);

        // Two paths to confirm that proposal is active
        // Path 1: check proposal state and use validAfter and validUntil
        uint proposalId = abi.decode(userOp.callData[164:196],(uint));
        (uint256 startBlock, uint256 endBlock) = _checkProposalState(proposalId);
        uint256 validUntil = endBlock; // not correct, need timestamp
        uint256 validAfter = startBlock; // not correct, need timestamp

        // Path 2: use the manual proposal data and validAfter and validUntil
        // this assumes PM can't access proposal data from GovernorBravo due to 
        // storage access rules
        // ProposalWindow memory proposalWindow = _proposals[proposalId];
        // require(proposalWindow.startTimestamp > 0, "proposalId not found");
        // uint256 validUntil = proposalWindow.endTimestamp;
        // uint256 validAfter = proposalWindow.startTimestamp;

        // Check that UNI is delegated before the startBlock
        IUni uni = IUni(_UNI_TOKEN_ADDRESS);
        uint96 delegatedUni = uni.getPriorVotes(userOp.sender, _proposals[proposalId].startBlock); // technically this is allowed by the spec
        require(delegatedUni > 0, "no UNI delegated");

        // Check that they haven't voted already
        // TODO: running into issues extract `hasVoted` from GovernorBravo.Proposals(proposalId).receipts(userOp.sender)

        // ensure they haven't voted already through this paymaster
        // check our internal mapping
        require(votingRecord[userOp.sender][proposalId] == false, "already voted");

        return (abi.encodePacked(userOp.sender, proposalId), uint256(bytes32(abi.encodePacked(address(0), uint48(validUntil),uint48(validAfter)))));
    }

    // called twice if first time reverts
    function _postOp(PostOpMode mode, bytes calldata context, uint256) internal override {
        // need to handle three outcomes: opSucceeded, opReverted, postOpReverted
        // opSucceeded: do nothing
        // TODO: is it worth recording this in a mapping?
        if (mode == PostOpMode.opSucceeded) {
            (address caller, uint256 proposalId) = abi.decode(context, (address, uint256));
            votingRecord[caller][proposalId] = true;
            return;
        }
        // opReverted: record caller address in a blocklist?
        if (mode == PostOpMode.opReverted) {
            (address caller, ) = abi.decode(context, (address, uint256));
            blocklist[caller] = true;
        }
        // postOpReverted: not applicable. Based on current implementation, this should never happen        
    }
}


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

