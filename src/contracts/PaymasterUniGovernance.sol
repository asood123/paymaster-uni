// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BasePaymaster} from "account-abstraction/core/BasePaymaster.sol";
import {Pausable} from "openzeppelin-contracts/security/Pausable.sol";
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

contract PaymasterUniGovernance is BasePaymaster, Pausable {
    
    // constants
    address constant _GOVERNOR_BRAVO_ADDRESS = 0x408ED6354d4973f66138C91495F2f2FCbd8724C3;
    address constant _UNI_TOKEN_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    bytes32 constant _EXECUTE_TYPEHASH = keccak256("execute(address,uint256,bytes)");
    bytes32 constant _CASTVOTE_TYPEHASH = keccak256("castVote(uint256,uint8)");
    bytes32 constant _DATA_PART_1 = hex"0000000000000000000000000000000000000000000000000000000000000060"; // based on observed data
    bytes32 constant _DATA_PART_2 = hex"0000000000000000000000000000000000000000000000000000000000000044"; // based on observed data
    
    // Requires proposals to be manually added
    mapping(uint256 => ProposalWindow) private _proposals; 
    uint256 _maxCostAllowed = 100000; // TODO: calculate reasonable upper bound and update

    // Tracks whether a user has voted on a proposal through this paymaster
    mapping(address => mapping(uint256 => bool)) public votingRecord;

    // blocklist - tracks any address whose transaction reverts
    mapping(address => bool) public blocklist;

    constructor(IEntryPoint _entryPoint) BasePaymaster(_entryPoint) {
        // TODO: figure out if this is needed; commenting out for now to get tests to pass
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
    function addOrModifyProposal(uint256 _proposalId, uint256 startTimestamp, uint256 endTimestamp, uint256 startBlock, uint256 endBlock) public  onlyOwner{
        _proposals[_proposalId] = ProposalWindow(startTimestamp, endTimestamp, startBlock, endBlock);
    }

    // nice to have to end proposals quickly
    function expireProposal(uint256 _proposalId) public  onlyOwner{
        ProposalWindow memory proposalWindow = _proposals[_proposalId];
        require(proposalWindow.startTimestamp > 0, "proposalId not found");
        _proposals[_proposalId] = ProposalWindow(0, 0, 0, 0);
    }

    function getProposalId(uint256 _proposalId) public view returns (ProposalWindow memory) {
        return _proposals[_proposalId];
    }

    function updateMaxCostAllowed(uint256 maxCost) public onlyOwner {
        _maxCostAllowed = maxCost;
    }

    /* Helpers for validation */
    function _verifyCallData(bytes calldata callData) private pure {
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
            , // proposalId
            uint256 support256
            ) = abi.decode(callData[4:],(address, bytes32, bytes32, bytes32, bytes32, uint256, uint256));

        // check each one
        require(toAddress == _GOVERNOR_BRAVO_ADDRESS, "address needs to point to GovernorBravo");
        require(value == 0, "value needs to be 0"); // no need to send any money to paymaster
        require(data1 == _DATA_PART_1, "data1 needs to be 0x60");
        require(data2 == _DATA_PART_2, "data2 needs to be 0x44");
        require(bytes4(castVoteHash) == bytes4(_CASTVOTE_TYPEHASH), "incorrect castVote signature");

        // proposalId checks happen outside this function

        // confirm  support is 0, 1, or 2
        require(uint8(support256) <= 2, "support must be 0, 1, or 2");
    }

    // Copid this function from UNI contract because first line isn't allowed in the paymaster verification step
    // https://etherscan.io/address/0x1f9840a85d5af5bf1d1762f925bdaddc4201f984#code#L474
    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address account, uint blockNumber) public view returns (uint96) {
        // following line not allowed due to block.number call
        // require(blockNumber < block.number, "Uni::getPriorVotes: not yet determined");
        IUni uni = IUni(_UNI_TOKEN_ADDRESS);
        
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
        (uint32 fromBlockIndex0, ) = uni.checkpoints(account, 0);
        if (fromBlockIndex0 > blockNumber) {
            return 0;
        }

        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            (uint32 fromBlock, uint96 votes) = uni.checkpoints(account, center);
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

    function _validatePaymasterUserOp(UserOperation calldata userOp, bytes32, uint256 maxCost)
    internal virtual override view whenNotPaused
    returns (bytes memory context, uint256 validationData) {

        // TODO: check that it's a SimpleAccount or an AA wallet. Confirm if it's possible and/or needed?
        
        // check that calldata is 452 bytes
        require(userOp.callData.length == 452, "callData must be 452 bytes");

        // check maxCost is less than _maxCostAllowed
        require(maxCost < _maxCostAllowed, "maxCost exceeds allowed amount");

        // check callData is valid
        _verifyCallData(userOp.callData);

        // check proposal exists in internal mapping
        uint256 proposalId = abi.decode(userOp.callData[164:196], (uint256));
        ProposalWindow memory proposalWindow = _proposals[proposalId];
        require(proposalWindow.startTimestamp > 0, "proposalId not found");
        uint256 validUntil = proposalWindow.endTimestamp; // TODO: could this be calculated from endBlock?
        uint256 validAfter = proposalWindow.startTimestamp; // TODO: could this be calculated from startBlock?

        // Check that UNI is delegated before the startBlock
        uint96 delegatedUni = getPriorVotes(userOp.sender, _proposals[proposalId].startBlock); // technically this is allowed by the spec
        require(delegatedUni > 0, "no UNI delegated");

        // Check that they haven't voted already in our internal mapping
        require(votingRecord[userOp.sender][proposalId] == false, "already voted");

        return (abi.encodePacked(userOp.sender, proposalId), uint256(bytes32(abi.encodePacked(address(0), uint48(validUntil),uint48(validAfter)))));
    }

    // called twice if first call reverts
    function _postOp(PostOpMode mode, bytes calldata context, uint256) internal override {
        // need to handle three outcomes: opSucceeded, opReverted, postOpReverted
        // opSucceeded: do nothing
        if (mode == PostOpMode.opSucceeded) {
            (address caller, uint256 proposalId) = abi.decode(context, (address, uint256));
            votingRecord[caller][proposalId] = true;
        }
        // opReverted: record caller address in a blocklist?
        else if (mode == PostOpMode.opReverted) {
            (address caller, ) = abi.decode(context, (address, uint256));
            blocklist[caller] = true;
        } else {
            // postOpReverted: not applicable. Based on current implementation, this should never happen
            // TODO: is it worth throwing an error?
        }
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

