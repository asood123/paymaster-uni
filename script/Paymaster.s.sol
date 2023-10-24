// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import '../src/PaymasterAcceptAll.sol';

// deploy command
// forge script script/Paymaster.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify -vvvv
contract PaymasterScript is Script {


    function deploy() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IEntryPoint entryPoint = IEntryPoint(address(vm.envAddress("ENTRY_POINT")));
        PaymasterAcceptAll paymasterAcceptAll = new PaymasterAcceptAll(entryPoint);
        paymasterAcceptAll.deposit{value: 1_000_000_000_000_000}();

        vm.stopBroadcast();
    }

    function deposit() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        // IEntryPoint entryPoint = IEntryPoint(address(vm.envAddress("ENTRY_POINT")));
        PaymasterAcceptAll paymasterAcceptAll = PaymasterAcceptAll(address(vm.envAddress("PAYMASTER_ACCEPT_ALL")));
        paymasterAcceptAll.deposit{value: 1_000_000_000_000_000}();
        vm.stopBroadcast();
    }

    function transferToPaymaster() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        (bool ok, ) = payable(address(vm.envAddress("PAYMASTER_ACCEPT_ALL"))).call{value: 1_000_000_000_000_000}("");
        require(ok, "send ETH failed");
        vm.stopBroadcast();
    }
    function run() external {
        this.transferToPaymaster();
    }
}
