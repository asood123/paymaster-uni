// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/PaymasterAcceptAll.sol";

contract PaymasterAcceptAllTest is Test {
    PaymasterAcceptAll public paymaster;

    function setUp() public {
        IEntryPoint entryPoint = IEntryPoint(address(0x0));
        paymaster = new PaymasterAcceptAll(entryPoint);
    }
}
