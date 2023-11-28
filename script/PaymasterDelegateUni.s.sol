// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import '../src/contracts/PaymasterDelegateUni.sol';

// deploy command
// forge script script/PaymasterDelegateUni.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify -vvvv
contract PaymasterDelegatUniScript is Script {

    function deploy() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IEntryPoint entryPoint = IEntryPoint(address(vm.envAddress("ENTRY_POINT")));
        PaymasterDelegateUni paymasterDelegateUni = new PaymasterDelegateUni(entryPoint);
        // deposit into EntryPoint
        paymasterDelegateUni.deposit{value: 100_000_000_000_000_000}();

        vm.stopBroadcast();
    }

    function deposit() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        PaymasterDelegateUni paymasterDelegateUni = PaymasterDelegateUni(payable(address(vm.envAddress("PAYMASTER_DELEGATE_UNI"))));
        paymasterDelegateUni.deposit{value: 12_000_000_000_000_000}();
        vm.stopBroadcast();
    }

    // doesn't work
    function transferToPaymaster() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        // PaymasterDelegateUni paymasterDelegateUni = PaymasterDelegateUni(payable(address(vm.envAddress("PAYMASTER_DELEGATE_UNI"))));
        (bool ok, ) = payable(address(vm.envAddress("PAYMASTER_DELEGATE_UNI"))).call{value: 1_000_000_000_000_000}("");
        require(ok, "send ETH failed");
        vm.stopBroadcast();
    }

    function increaseMaxCostAllowed() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        PaymasterDelegateUni paymasterDelegateUni = PaymasterDelegateUni(payable(address(vm.envAddress("PAYMASTER_DELEGATE_UNI"))));
        paymasterDelegateUni.updateMaxCostAllowed(100_000_000_000_000_000);
        vm.stopBroadcast();
    }
    function run() external {
        this.deploy();
    }
}
