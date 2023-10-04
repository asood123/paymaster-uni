// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Paymaster.sol";

contract PaymasterTest is Test {
    Paymaster public paymaster;

    function setUp() public {
        entrypoint = new EntryPoint();
        paymaster = new Paymaster(entrypoint);
        paymaster.setNumber(0);
    }
}
