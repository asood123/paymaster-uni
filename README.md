## Governance Paymaster
This repository includes explorations of various Paymasters that can be used to pay for Governance/DAO actions on chain. 

### Delgate your vote
`PaymasterDelegateUni.sol`: This proof of concept Paymaster pays for UNI delegations on-chain. You can see a deployed version at: [PaymasterDelegateUni on Sepolia](https://sepolia.etherscan.io/address/0x4409a6647892b7eeca5bc3b819576395173cf722).
A sample transaction [here](https://sepolia.etherscan.io/tx/0x7a5e019b3cbc2482326e7e07a821ef038d98b49d3df9098198b5d0853bf1351a/advanced#eventlog) that shows the `DelegateChanged` event from Uniswap Token contract.

The demo transactions were created via a separate frontend repo: [AA-Wallet-Demo](https://github.com/asood123/aa-wallet-starter)

### Cast votes
`PaymasterCastVoteUni.sol`: This pays for casting a vote on-chain. As there is no `GovernorBravo` on Sepolia for Uniswap DAO, this one is tricky to test live. Working on it.

### Build
To build: `forge build`

To deploy (example): `forge script script/PaymasterDelegateUni.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify -vvvv

### Next Steps/Explorations
- Generalize Paymaster for any `GovernorBravo` like Compound DAO without requiring contract change.
- Figure out how to test casting votes on Sepolia
- Combine both actions in a single Paymaster (see wip in `PaymasterUniGovernance.sol`)
- Approach a DAO to build an end to end flow where their holders can delegate to their own AA wallet and DAO pays for the next vote.
