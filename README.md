# Base Nexus Streaming

A decentralized, continuous payment streaming protocol on the Base network. Nexus enables block-by-block linear asset distribution, fundamentally transforming how DAOs, Web3 startups, and freelancers handle payroll, vesting, and subscriptions.

## Core Mechanics
* **Linear Block-by-Block Streaming:** Funds are dynamically unlocked over time based on strict `block.timestamp` differentials. The recipient can withdraw their accumulated balance at any exact second.
* **Sender Cancellation Rights:** The stream creator can cancel an active stream at any time. The smart contract automatically calculates the exact split, routing the earned amount to the recipient and refunding the unstreamed remainder to the sender.
* **Zero-Lockup Withdrawals:** Recipients are not forced to wait until the stream concludes; they have permissionless access to claim their real-time vested balance instantly.

## Technical Implementation
Developed using Solidity `0.8.37`. The protocol avoids expensive loop iterations, instead utilizing constant-time O(1) mathematical formulas to calculate time elapsed and vested amounts, ensuring absolute minimal gas consumption for everyday payroll operations.
