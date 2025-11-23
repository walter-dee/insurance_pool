# Insurance Pool

An autonomous insurance pool smart contract built on Stacks (STX) using Clarity v2. This contract enables users to collectively stake STX into a shared pool, with payouts distributed proportionally when an oracle-triggered insurance event occurs.

## Overview

Insurance Pool creates a decentralized insurance mechanism where users deposit STX to build and share a collective insurance reserve. An oracle-designated account verifies insurance events and triggers proportional payout distribution among stakers based on their contribution weight.

## Features

### Staking Mechanism
- Users deposit STX into contract-owned pool
- Stake amounts tracked per user individually
- Total pool balance accumulates across all stakers
- Flexible entry - users can stake anytime before event trigger

### Oracle Event Trigger
- Designated oracle account can trigger insurance event
- One-time event mechanism (prevents multiple triggers)
- Locks pool and enables claim period
- Role-based access control

### Proportional Payout System
- Payouts calculated as: (user_stake / total_stake) × pool_balance
- Fair distribution based on contribution weight
- Prevents reward dilution for early/larger stakers
- Atomic STX transfers with error handling

### Claim Management
- Users claim payouts after oracle triggers event
- Double-claim prevention with tracking mechanism
- Atomic execution with error validation
- Payout amount determined at claim time based on pool balance

### Oracle Management
- Set/update oracle address (oracle-only)
- Prevent self-assignment as oracle (security guard)
- Role-based access control with permission checks

## Technical Specifications

### Storage
| Variable | Type | Purpose |
|----------|------|---------|
| `oracle` | principal | Designated oracle account |
| `total-staked` | uint | Total STX staked across all users |
| `event-triggered` | bool | Insurance event status flag |
| `stakes` | map | User → amount staked mapping |
| `claimed` | map | User → claim status mapping |

### Error Codes
| Code | Description |
|------|-------------|
| 100 | Not authorized as oracle |
| 101 | User has no stake in pool |
| 102 | User already claimed payout |
| 103 | Insurance event not triggered |
| 104 | Insurance event already triggered |
| 105 | Invalid amount or parameter |
| 200 | STX transfer failed (stake) |
| 201 | STX transfer failed (claim) |

### Units & Precision
- **Base Unit**: STX (standard blockchain unit)
- **Decimal Places**: 6 (micro-STX)
- **Payout Calculation**: Integer division (potential rounding down)

## Contract Functions

### User Functions

#### `stake(amount: uint)`
Deposit STX into the insurance pool.

**Returns:** Total stake amount for user on success  
**Errors:** ERR-INVALID-AMOUNT (105), Transfer Error (200)

```clarity
(contract-call? .insurance-pool stake u1000000) ;; Stake 1 STX
