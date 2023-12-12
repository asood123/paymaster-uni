// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import '../src/contracts/PaymasterCastVoteUni.sol';

// deploy command
// forge script script/PaymasterCastVoteUni.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify -vvvv
contract PaymasterCastVoteUniScript is Script {

    function deploy() external returns (address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IEntryPoint entryPoint = IEntryPoint(address(vm.envAddress("ENTRY_POINT")));
        PaymasterCastVoteUni paymasterCastVoteUni = new PaymasterCastVoteUni(entryPoint);
        address paymasterCastVoteUniAddress = address(paymasterCastVoteUni);
        vm.stopBroadcast();
        return paymasterCastVoteUniAddress;
        // deposit into EntryPoint
        // paymasterCastVote.deposit{value: 100_000_000_000_000_000}();

    }

    function deposit(address toAddress, uint256 amount) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        PaymasterCastVoteUni paymasterCastVoteUni = PaymasterCastVoteUni(payable(toAddress));
        paymasterCastVoteUni.deposit{value: amount}();
        vm.stopBroadcast();
    }

    function withdrawAll(address fromAddress) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        PaymasterCastVoteUni paymasterCastVoteUni = PaymasterCastVoteUni(payable(fromAddress));
        uint256 depositedAmount = paymasterCastVoteUni.getDeposit();
        paymasterCastVoteUni.withdrawTo(payable(address(vm.envAddress("PUBLIC_KEY"))), depositedAmount);
        vm.stopBroadcast();
    }

    // doesn't work
    function transferToPaymaster() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        // PaymasterCastVote paymasterCastVote = PaymasterCastVote(payable(address(vm.envAddress("PAYMASTER_DELEGATE_UNI"))));
        (bool ok, ) = payable(address(vm.envAddress("PAYMASTER_CASTVOTE_UNI"))).call{value: 1_000_000_000_000_000}("");
        require(ok, "send ETH failed");
        vm.stopBroadcast();
    }

    function increaseMaxCostAllowed() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        PaymasterCastVoteUni paymasterCastVoteUni = PaymasterCastVoteUni(payable(address(vm.envAddress("PAYMASTER_DELEGATE_UNI"))));
        paymasterCastVoteUni.updateMaxCostAllowed(200_000_000_000_000_000);
        vm.stopBroadcast();
    }

    function addStake(address deployedAddress) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        PaymasterCastVoteUni paymasterCastVoteUni = PaymasterCastVoteUni(payable(deployedAddress));
        paymasterCastVoteUni.addStake{value: 100_000_000_000_000_000}(1);
        vm.stopBroadcast();
    }

    function unlockStake(address deployedAddress) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        PaymasterCastVoteUni paymasterCastVoteUni = PaymasterCastVoteUni(payable(deployedAddress));
        paymasterCastVoteUni.unlockStake();
        vm.stopBroadcast();
    }

    function withdrawStake(address deployedAddress) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        PaymasterCastVoteUni paymasterCastVoteUni = PaymasterCastVoteUni(payable(deployedAddress));
        paymasterCastVoteUni.withdrawStake(payable(address(vm.envAddress("PUBLIC_KEY"))));
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
        PaymasterCastVoteUni paymasterCastVoteUni = PaymasterCastVoteUni(payable(paymasterAddress));
        paymasterCastVoteUni.unlockStake();
        vm.stopBroadcast();
    }

    function abandonPaymasterStep2of2(address paymasterAddress, address withdrawToAddress) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        PaymasterCastVoteUni paymasterCastVoteUni = PaymasterCastVoteUni(payable(paymasterAddress));
        uint256 depositedAmount = paymasterCastVoteUni.getDeposit();
        paymasterCastVoteUni.withdrawTo(payable(withdrawToAddress), depositedAmount);
        paymasterCastVoteUni.withdrawStake(payable(withdrawToAddress));
        vm.stopBroadcast();
    }

    function run() external {
        /* to deploy */
        this.deployAndSetupNewPaymaster();
        
        /* to withdraw (2 steps)
            Step 0: update address of paymaster
            Step 1: uncomment next two lines and run
        */
        // address deployedAddress = address(0x570f172eD6Eb3748dB046C244710BF473CB8a912);
        // this.abandonPaymasterStep1of2(deployedAddress);

        /* Step 2: comment above line and incomment this one */
        // this.abandonPaymasterStep2of2(deployedAddress, address(vm.envAddress("PUBLIC_KEY")));
    }
}
