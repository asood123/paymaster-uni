// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/contracts/PaymasterUniGovernance.sol";

contract PaymasterUniGovernanceTest is Test {
    PaymasterUniGovernance public paymaster;
    address owner = vm.envAddress("PUBLIC_KEY");
    address entryPointAddress = vm.envAddress("ENTRY_POINT");

    bytes correctCallData =
        hex"b61d27f6" // execute signature
        hex"000000000000000000000000408ed6354d4973f66138c91495f2f2fcbd8724c3" // GovernorBravo address
        hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
        hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
        hex"0000000000000000000000000000000000000000000000000000000000000044" // data2 (0x44)
        hex"5678138800000000000000000000000000000000000000000000000000000000" // castVote signature
        hex"0000000000000000000000000000000000000000000000000000000000000034" // proposalId (52)
        hex"0000000000000000000000000000000000000000000000000000000000000002"; // support (2)


    function setUp() public {
        IEntryPoint entryPoint = IEntryPoint(entryPointAddress);
        vm.prank(owner, owner);
        paymaster = new PaymasterUniGovernance(entryPoint);
        vm.roll(30000);
        vm.warp(360000);
        vm.prank(owner);
        paymaster.addOrModifyProposal(52, block.timestamp - 15, block.timestamp + 15, block.number - 1, block.number + 1 );
    }

    function _userOpsHelper(bytes memory callData) internal view returns (UserOperation memory) {
        UserOperation memory userOp = UserOperation(
            address(owner), 0, hex"", callData, 0, 0, 0, 0, 0, hex"", hex"");
        return userOp;
    }

    function test_ProposalIdExists() public {
        ProposalWindow memory pd = paymaster.getProposalId(52);
        assertEq(pd.startBlock == block.number - 1, true);
        assertEq(pd.endBlock == block.number + 1, true);
        assertEq(pd.startTimestamp == block.timestamp - 15, true);
        assertEq(pd.endTimestamp == block.timestamp + 15, true);
    }

    function test_ProposalIdDoesNotExist() public {
        ProposalWindow memory pd = paymaster.getProposalId(53);
        assertEq(pd.startBlock == 0, true);
        assertEq(pd.endBlock == 0, true);
        assertEq(pd.startTimestamp == 0, true);
        assertEq(pd.endTimestamp == 0, true);
    }

    function testFail_UpdateMaxCostAllowed() public {
        paymaster.updateMaxCostAllowed(0);
    }

    function test_UpdateMaxCostAllowed() public {
        vm.prank(owner);
        paymaster.updateMaxCostAllowed(1000000);
        assertEq(paymaster.getMaxCostAllowed(), 1000000);
    }

/*

        struct UserOperation {

        address sender;
        uint256 nonce;
        bytes initCode;
        bytes callData;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes paymasterAndData;
        bytes signature;
    }

*/

    function test_calldataIncorrectSize() public {
        bytes memory testCallData = 
            hex"b61e27f6"
            hex"000000000000000000000000408ed6354d4973f66138c91495f2f2fcbd8724c3";
        vm.prank(entryPointAddress);
        vm.expectRevert("callData must be 196 or 228 bytes");
        paymaster.validatePaymasterUserOp(_userOpsHelper(testCallData), hex"", 100);
    }

    function test_maxCostTooHigh() public {
        vm.prank(entryPointAddress);
        vm.expectRevert("maxCost exceeds allowed amount");
        paymaster.validatePaymasterUserOp(_userOpsHelper(correctCallData), hex"", 10000000);
    }

    function test_incorrectExecuteSig() public {
        bytes memory testCallData = 
            hex"b61d2766" // incorrect execute signature
            hex"000000000000000000000000408ed6354d4973f66138c91495f2f2fcbd8724c3" // GovernorBravo address
            hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000044" // data2 (0x44)
            hex"5678138800000000000000000000000000000000000000000000000000000000" // castVote signature
            hex"0000000000000000000000000000000000000000000000000000000000000034" // proposalId (52)
            hex"0000000000000000000000000000000000000000000000000000000000000002"; // support (2)
        vm.prank(entryPointAddress);
        vm.expectRevert("incorrect execute signature");
        paymaster.validatePaymasterUserOp(_userOpsHelper(testCallData), hex"", 10000);
    }

    function test_addressNotGovernorBravo() public {
        bytes memory testCallData = 
            hex"b61d27f6" // execute signature
            hex"000000000000000000000000408ed6354d4973f66138c91495f2f2fcbd8724c4" // incorrect GovernorBravo address
            hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000044" // data2 (0x44)
            hex"5678138800000000000000000000000000000000000000000000000000000000" // castVote signature
            hex"0000000000000000000000000000000000000000000000000000000000000034" // proposalId (52)
            hex"0000000000000000000000000000000000000000000000000000000000000002"; // support (2)
        vm.prank(entryPointAddress);
        vm.expectRevert("address needs to point to GovernorBravo");
        paymaster.validatePaymasterUserOp(_userOpsHelper(testCallData), hex"", 10000);
    }

    function test_includesPayment() public {
        bytes memory testCallData =
            hex"b61d27f6" // execute signature
            hex"000000000000000000000000408ed6354d4973f66138c91495f2f2fcbd8724c3" // GovernorBravo address
            hex"0000000000000000000000000000000000000000000000000000000000000001" // incorrect value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000044" // data2 (0x44)
            hex"5678138800000000000000000000000000000000000000000000000000000000" // castVote signature
            hex"0000000000000000000000000000000000000000000000000000000000000034" // proposalId (52)
            hex"0000000000000000000000000000000000000000000000000000000000000002"; // support (2)
        vm.prank(entryPointAddress);
        vm.expectRevert("value needs to be 0");
        paymaster.validatePaymasterUserOp(_userOpsHelper(testCallData), hex"", 10000);
    }

    function test_incorrectDataPart1() public {
        bytes memory testCallData =
             hex"b61d27f6" // execute signature
            hex"000000000000000000000000408ed6354d4973f66138c91495f2f2fcbd8724c3" // GovernorBravo address
            hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000061" // incorrect data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000044" // data2 (0x44)
            hex"5678138800000000000000000000000000000000000000000000000000000000" // castVote signature
            hex"0000000000000000000000000000000000000000000000000000000000000034" // proposalId (52)
            hex"0000000000000000000000000000000000000000000000000000000000000002"; // support (2)


        vm.prank(entryPointAddress);
        vm.expectRevert("data1 needs to be 0x60");
        paymaster.validatePaymasterUserOp(_userOpsHelper(testCallData), hex"", 10000);
    }

    function test_incorrectDataPart2() public {
        bytes memory testCallData = 
             hex"b61d27f6" // execute signature
            hex"000000000000000000000000408ed6354d4973f66138c91495f2f2fcbd8724c3" // GovernorBravo address
            hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000045" // incorrect data2 (0x44)
            hex"5678138800000000000000000000000000000000000000000000000000000000" // castVote signature
            hex"0000000000000000000000000000000000000000000000000000000000000034" // proposalId (52)
            hex"0000000000000000000000000000000000000000000000000000000000000002"; // support (2)
        vm.prank(entryPointAddress);
        vm.expectRevert("data2 needs to be 0x44");
        paymaster.validatePaymasterUserOp(_userOpsHelper(testCallData), hex"", 10000);
    }

    function test_incorrectCastVoteHash() public {
        bytes memory testCallData = 
            hex"b61d27f6" // execute signature
            hex"000000000000000000000000408ed6354d4973f66138c91495f2f2fcbd8724c3" // GovernorBravo address
            hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000044" // data2 (0x44)
            hex"5678138900000000000000000000000000000000000000000000000000000000" // incorrect castVote signature
            hex"0000000000000000000000000000000000000000000000000000000000000034" // proposalId (52)
            hex"0000000000000000000000000000000000000000000000000000000000000002"; // support (2)
        vm.prank(entryPointAddress);
        vm.expectRevert("incorrect castVote signature");
        paymaster.validatePaymasterUserOp(_userOpsHelper(testCallData), hex"", 10000);
    }

    function test_invalidSupportValue() public {
        bytes memory testCallData = 
            hex"b61d27f6" // execute signature
            hex"000000000000000000000000408ed6354d4973f66138c91495f2f2fcbd8724c3" // GovernorBravo address
            hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000044" // data2 (0x44)
            hex"5678138800000000000000000000000000000000000000000000000000000000" // incorrect castVote signature
            hex"0000000000000000000000000000000000000000000000000000000000000034" // proposalId (52)
            hex"0000000000000000000000000000000000000000000000000000000000000004"; // incorrect support (2)
        vm.prank(entryPointAddress);
        vm.expectRevert("support must be 0, 1, or 2");
        paymaster.validatePaymasterUserOp(_userOpsHelper(testCallData), hex"", 10000);
    }
    
    function test_incorrectProposalId() public {
        bytes memory testCallData = 
            hex"b61d27f6" // execute signature
            hex"000000000000000000000000408ed6354d4973f66138c91495f2f2fcbd8724c3" // GovernorBravo address
            hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000044" // data2 (0x44)
            hex"5678138800000000000000000000000000000000000000000000000000000000" // incorrect castVote signature
            hex"0000000000000000000000000000000000000000000000000000000000000035" // proposalId (52)
            hex"0000000000000000000000000000000000000000000000000000000000000002"; // support (2
        vm.prank(entryPointAddress);
        vm.expectRevert("proposalId not found");
        paymaster.validatePaymasterUserOp(_userOpsHelper(testCallData), hex"", 10000);
    }

    // TODO
    /* function test_noUNIDelegated() public {
        bytes memory testCallData = 
            hex"b61d27f6" // execute signature
            hex"000000000000000000000000408ed6354d4973f66138c91495f2f2fcbd8724c3" // GovernorBravo address
            hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000044" // data2 (0x44)
            hex"5678138800000000000000000000000000000000000000000000000000000000" // incorrect castVote signature
            hex"0000000000000000000000000000000000000000000000000000000000000034" // proposalId (52)
            hex"0000000000000000000000000000000000000000000000000000000000000002"; // support (2
        vm.prank(entryPointAddress);
        vm.expectRevert("no UNI delegated");
        paymaster.validatePaymasterUserOp(_userOpsHelper(testCallData), hex"", 10000);
    } */

    // TODO: add rest of the tests
}
