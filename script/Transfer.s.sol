// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

// deploy command
// forge script script/Transfer.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify -vvvv
contract TransferScript is Script {


    // doesn't work
    function transferTo(address toAddress, uint256 amount) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        (bool ok, ) = payable(toAddress).call{value: amount}("");
        require(ok, "send ETH failed");
        vm.stopBroadcast();
    }

    function run() external {
        this.transferTo(0x4bD047CA72fa05F0B89ad08FE5Ba5ccdC07DFFBF, 300_000_000_000_000_000);
    }
}
