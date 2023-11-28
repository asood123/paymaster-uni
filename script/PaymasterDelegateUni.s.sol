// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import '../src/contracts/PaymasterDelegateUni.sol';

// deploy command
// forge script script/PaymasterDelegateUni.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify -vvvv
contract PaymasterDelegatUniScript is Script {

    function deploy() external returns (address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IEntryPoint entryPoint = IEntryPoint(address(vm.envAddress("ENTRY_POINT")));
        PaymasterDelegateUni paymasterDelegateUni = new PaymasterDelegateUni(entryPoint);
        address paymasterDelegateUniAddress = address(paymasterDelegateUni);
        vm.stopBroadcast();
        return paymasterDelegateUniAddress;
        // deposit into EntryPoint
        // paymasterDelegateUni.deposit{value: 100_000_000_000_000_000}();

    }

    function deposit(address toAddress, uint256 amount) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        PaymasterDelegateUni paymasterDelegateUni = PaymasterDelegateUni(payable(toAddress));
        paymasterDelegateUni.deposit{value: amount}();
        vm.stopBroadcast();
    }

    function withdrawAll(address fromAddress) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        PaymasterDelegateUni paymasterDelegateUni = PaymasterDelegateUni(payable(fromAddress));
        uint256 depositedAmount = paymasterDelegateUni.getDeposit();
        paymasterDelegateUni.withdrawTo(payable(address(vm.envAddress("PUBLIC_KEY"))), depositedAmount);
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
        paymasterDelegateUni.updateMaxCostAllowed(200_000_000_000_000_000);
        vm.stopBroadcast();
    }


    function run() external {
        //address deployedAddress = this.deploy();
        address deployedAddress = address(vm.envAddress("PAYMASTER_DELEGATE_UNI"));
        this.deposit(deployedAddress, 200_000_000_000_000_000);
        // this.withdrawAll();
    }
}
