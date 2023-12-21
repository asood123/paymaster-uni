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

    function increaseMaxCostAllowed(address paymaster) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        PaymasterDelegateUni paymasterDelegateUni = PaymasterDelegateUni(payable(paymaster));
        paymasterDelegateUni.updateMaxCostAllowed(200_000_000_000_000_000);
        vm.stopBroadcast();
    }

    function addStake(address deployedAddress) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        PaymasterDelegateUni paymasterDelegateUni = PaymasterDelegateUni(payable(deployedAddress));
        paymasterDelegateUni.addStake{value: 100_000_000_000_000_000}(1);
        vm.stopBroadcast();
    }

    function unlockStake(address deployedAddress) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        PaymasterDelegateUni paymasterDelegateUni = PaymasterDelegateUni(payable(deployedAddress));
        paymasterDelegateUni.unlockStake();
        vm.stopBroadcast();
    }

    function withdrawStake(address deployedAddress) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        PaymasterDelegateUni paymasterDelegateUni = PaymasterDelegateUni(payable(deployedAddress));
        paymasterDelegateUni.withdrawStake(payable(address(vm.envAddress("PUBLIC_KEY"))));
        vm.stopBroadcast();
    }

    function deployAndSetupNewPaymaster() external {
        // deploy
        address deployedAddress = this.deploy();
        // add deposit
        this.deposit(deployedAddress, 200_000_000_000_000_000);
        // add stake
        this.addStake(deployedAddress);
    }

    function abandonPaymasterStep1of2(address paymasterAddress) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        PaymasterDelegateUni paymasterDelegateUni = PaymasterDelegateUni(payable(paymasterAddress));
        paymasterDelegateUni.unlockStake();
        vm.stopBroadcast();
    }

    function abandonPaymasterStep2of2(address paymasterAddress, address withdrawToAddress) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        PaymasterDelegateUni paymasterDelegateUni = PaymasterDelegateUni(payable(paymasterAddress));
        uint256 depositedAmount = paymasterDelegateUni.getDeposit();
        paymasterDelegateUni.withdrawTo(payable(withdrawToAddress), depositedAmount);
        paymasterDelegateUni.withdrawStake(payable(withdrawToAddress));
        vm.stopBroadcast();
    }

    function run() external {
        /* to deploy */
        this.deployAndSetupNewPaymaster();
        
        /* to withdraw (2 steps)
            Step 0: update address of paymaster
            Step 1: uncomment next two lines and run
        */
        // address deployedAddress = address(0x4409a6647892B7Eeca5bC3b819576395173Cf722);
        // this.abandonPaymasterStep1of2(deployedAddress);

        /* Step 2: comment above line and incomment this one */
        // this.abandonPaymasterStep2of2(deployedAddress, address(vm.envAddress("PUBLIC_KEY")));

    }
}
