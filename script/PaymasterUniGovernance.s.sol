// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import '../src/contracts/PaymasterUniGovernance.sol';

// deploy command
// forge script script/PaymasterUniGovernance.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify -vvvv
contract PaymasterUniGovernanceScript is Script {

    function deploy() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IEntryPoint entryPoint = IEntryPoint(address(vm.envAddress("ENTRY_POINT")));
        PaymasterUniGovernance paymasterUniGovernance = new PaymasterUniGovernance(entryPoint);
        // deposit into EntryPoint
        paymasterUniGovernance.deposit{value: 1_000_000_000_000_000}();

        vm.stopBroadcast();
    }

    function deposit() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        PaymasterUniGovernance paymasterUniGovernance = PaymasterUniGovernance(payable(address(vm.envAddress("PAYMASTER_UNI_GOVERNANCE"))));
        paymasterUniGovernance.deposit{value: 12_000_000_000_000_000}();
        vm.stopBroadcast();
    }

    // doesn't work
    function transferToPaymaster() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        // PaymasterUniGovernance paymasterUniGovernance = PaymasterUniGovernance(payable(address(vm.envAddress("PAYMASTER_UNI_GOVERNANCE"))));
        (bool ok, ) = payable(address(vm.envAddress("PAYMASTER_UNI_GOVERNANCE"))).call{value: 1_000_000_000_000_000}("");
        require(ok, "send ETH failed");
        vm.stopBroadcast();
    }

    function increaseMaxCostAllowed() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        PaymasterUniGovernance paymasterUniGovernance = PaymasterUniGovernance(payable(address(vm.envAddress("PAYMASTER_UNI_GOVERNANCE"))));
        paymasterUniGovernance.updateMaxCostAllowed(100_000_000_000_000_000);
        vm.stopBroadcast();
    }
    function run() external {
        this.deploy();
    }
}
