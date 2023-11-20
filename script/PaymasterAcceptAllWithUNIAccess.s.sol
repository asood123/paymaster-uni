// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import '../src/contracts/PaymasterAcceptAllWithUNIAccess.sol';

// deploy command
// forge script script/PaymasterAcceptAllWithUNIAccess.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify -vvvv
contract PaymasterAcceptAllUNIAccessScript is Script {


    function deploy() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IEntryPoint entryPoint = IEntryPoint(address(vm.envAddress("ENTRY_POINT")));
        PaymasterAcceptAllWithUNIAccess paymasterAcceptAllWithUNIAccess = new PaymasterAcceptAllWithUNIAccess(entryPoint);
        paymasterAcceptAllWithUNIAccess.deposit{value: 1_000_000_000_000_000}();

        vm.stopBroadcast();
    }

    function deposit() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        PaymasterAcceptAllWithUNIAccess paymasterAcceptAllWithUNIAccess = PaymasterAcceptAllWithUNIAccess(address(vm.envAddress("PAYMASTER_ACCEPT_ALL_WITH_UNI_ACCESS")));
        paymasterAcceptAllWithUNIAccess.deposit{value: 1_000_000_000_000_000}();
        vm.stopBroadcast();
    }

    function addStake() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        PaymasterAcceptAllWithUNIAccess paymasterAcceptAllWithUNIAccess = PaymasterAcceptAllWithUNIAccess(address(vm.envAddress("PAYMASTER_ACCEPT_ALL_WITH_UNI_ACCESS")));
        paymasterAcceptAllWithUNIAccess.addStake{value: 1_000_000_000_000_000}(1000);
        vm.stopBroadcast();
    }

    function run() external {
        this.deploy();
    }
}
