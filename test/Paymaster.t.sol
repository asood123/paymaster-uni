// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Paymaster.sol";

contract PaymasterTest is Test {
    Paymaster public paymaster;

    function setUp() public {
        paymaster = new Paymaster();
        paymaster.setNumber(0);
    }

    function testIncrement() public {
        paymaster.increment();
        assertEq(paymaster.number(), 1);
    }

    function testSetNumber(uint256 x) public {
        paymaster.setNumber(x);
        assertEq(paymaster.number(), x);
    }
}
