# BitVault Protocol

**Bitcoin-Native Staking Platform on Stacks**

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Clarity](https://img.shields.io/badge/Clarity-Smart%20Contract-orange.svg)](https://clarity-lang.org/)
[![Stacks](https://img.shields.io/badge/Built%20on-Stacks-purple.svg)](https://stacks.co/)

BitVault Protocol is a sophisticated staking platform that enables Bitcoin holders to earn passive yields on their sBTC assets through secure, time-locked vaults with dynamic reward mechanisms. Built on Stacks Layer 2, it combines Bitcoin's security with programmable yield generation for long-term HODLers.

## 🎯 Overview

BitVault harnesses the security of Bitcoin and the programmability of Stacks to create a trustless staking ecosystem. Users can deposit sBTC into time-locked vaults to earn rewards based on staking duration and network participation. The protocol features flexible staking periods, compound rewards, transparent governance, and emergency withdrawal mechanisms - all while maintaining Bitcoin's security guarantees.

## ✨ Key Features

- **🔒 Secure Staking**: Time-locked sBTC vaults with Bitcoin-level security
- **📈 Dynamic Rewards**: APY-based rewards calculated per block with compounding
- **⏰ Flexible Lock Periods**: Configurable minimum lock durations (default ~10 days)
- **🏛️ Decentralized Governance**: On-chain parameter management and ownership transfer
- **💰 Treasury Management**: Sustainable reward distribution system
- **🛡️ Safety Features**: Rate caps, sufficient balance checks, and emergency controls
- **📊 Transparent Metrics**: Real-time TVL, APY, and reward tracking

## 🏗️ Architecture

### Core Components

```
BitVault Protocol
├── Staking Engine
│   ├── Position Management
│   ├── Reward Calculation
│   └── Lock Period Enforcement
├── Treasury System
│   ├── Reward Pool Management
│   └── Balance Validation
└── Governance Layer
    ├── Parameter Control
    ├── Ownership Management
    └── Emergency Functions
```

### Error Constants

| Code | Constant | Description |
|------|----------|-------------|
| `u100` | `ERR_UNAUTHORIZED` | Caller not authorized for operation |
| `u101` | `ERR_ZERO_AMOUNT` | Amount must be greater than zero |
| `u102` | `ERR_NO_POSITION` | No staking position found for user |
| `u103` | `ERR_LOCKED_PERIOD` | Minimum lock period not elapsed |
| `u104` | `ERR_INVALID_RATE` | Yield rate exceeds 50% cap |
| `u105` | `ERR_INSUFFICIENT_REWARDS` | Treasury lacks sufficient funds |
| `u106` | `ERR_INVALID_PERIOD` | Invalid lock period specified |
| `u107` | `ERR_SAME_OWNER` | New owner cannot be current owner |

### Data Structures

#### Staking Positions

```clarity
{
  staker: principal,
  amount: uint,      // Staked sBTC amount
  locked-at: uint    // Block height when locked
}
```

#### Reward History

```clarity
{
  staker: principal,
  total-claimed: uint  // Lifetime rewards claimed
}
```

### Protocol Parameters

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `annual-yield-rate` | `u500` (5.00% APY) | Yield rate in basis points |
| `minimum-lock-period` | `u1440` (~10 days) | Minimum staking duration in blocks |
| `treasury-balance` | `u0` | Available reward funds |
| `total-value-locked` | `u0` | Total staked sBTC in protocol |

## 🔧 Core Functions

### Staking Operations

#### `stake-btc(amount: uint)`

Stakes sBTC tokens in the protocol vault.

- Transfers sBTC from user to contract
- Creates or updates staking position
- Resets lock timestamp to current block
- Updates total value locked (TVL)

```clarity
;; Example usage
(contract-call? .bitvault stake-btc u1000000) ;; Stake 1 sBTC
```

#### `unstake-btc(amount: uint)`

Withdraws staked sBTC after lock period expires.

- Validates minimum lock period compliance
- Auto-claims pending rewards
- Updates or removes staking position
- Transfers tokens back to user

```clarity
;; Example usage
(contract-call? .bitvault unstake-btc u500000) ;; Unstake 0.5 sBTC
```

#### `claim-rewards()`

Claims accumulated staking rewards.

- Calculates time-weighted rewards
- Validates treasury balance sufficiency
- Updates reward history
- Resets reward calculation timestamp
- Transfers rewards to user

### Governance Functions

#### `transfer-ownership(new-owner: principal)`

Transfers protocol ownership to new address.

#### `update-yield-rate(new-rate: uint)`

Updates annual yield rate (max 50% APY = 5000 basis points).

#### `set-lock-period(blocks: uint)`

Adjusts minimum lock period duration.

#### `fund-treasury(amount: uint)`

Deposits sBTC into reward treasury.

### Query Functions

#### `get-pending-rewards(staker: principal) -> uint`

Calculates pending rewards for a staker based on:

- Staked amount
- Blocks since last reward claim/stake
- Current annual yield rate
- Stacks blocks per year (~52,560)

#### `get-position(staker: principal) -> (optional tuple)`

Returns staker's position details or none.

#### `get-protocol-config() -> tuple`

Returns current protocol configuration:

```clarity
{
  annual-yield-rate: uint,
  minimum-lock-period: uint,
  treasury-balance: uint,
  total-value-locked: uint
}
```

#### `can-unstake(staker: principal) -> bool`

Checks if staker can withdraw (lock period elapsed).

#### `get-current-apy() -> uint`

Returns formatted APY as percentage (e.g., u5 for 5%).

## 🧮 Reward Calculation

Rewards are calculated using the time-weighted formula:

```
rewards = (staked_amount × annual_rate × blocks_staked) ÷ (10,000 × blocks_per_year)
```

Where:

- `staked_amount`: User's staked sBTC balance
- `annual_rate`: APY in basis points (500 = 5%)
- `blocks_staked`: Blocks since last claim/stake
- `blocks_per_year`: ~52,560 (Stacks network average)

## 🛠️ Development Setup

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) v2.0+
- Node.js v18+ and npm
- Git

### Installation

```bash
git clone https://github.com/ibukun-ayo/bitvault.git
cd bitvault
clarinet check
```

### Testing

```bash
# Run contract syntax check
clarinet check

# Execute test suite
npm test

# Run specific test file
clarinet test tests/bitvault.test.ts
```

### Local Development

```bash
# Start local testnet
clarinet integrate

# Deploy to devnet
clarinet deploy --network=devnet
```

## 🔐 Security Considerations

### Safety Mechanisms

1. **Rate Limiting**: Maximum 50% APY to prevent excessive inflation
2. **Balance Validation**: Rewards only distributed if treasury sufficient
3. **Lock Period Enforcement**: Prevents instant withdrawal farming attacks
4. **Ownership Protection**: Prevents accidental self-assignment of ownership
5. **Zero Amount Guards**: Validates all monetary inputs are positive

### Audit Recommendations

- [ ] External security audit before mainnet deployment
- [ ] Formal verification of reward calculation logic  
- [ ] Stress testing with high TVL scenarios
- [ ] Emergency pause mechanism consideration
- [ ] Multi-signature governance implementation

## 📊 Protocol Metrics

### Key Performance Indicators

- **Total Value Locked (TVL)**: Aggregate sBTC staked
- **Annual Percentage Yield (APY)**: Current reward rate
- **Average Lock Duration**: Mean staking period across users  
- **Treasury Health**: Available rewards vs. pending obligations
- **Active Stakers**: Unique addresses with positions

## 🤝 Contributing

We welcome contributions from the Stacks and Bitcoin communities!

### Development Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes with comprehensive tests
4. Ensure code passes `clarinet check` and test suite
5. Commit with conventional commits (`feat:`, `fix:`, `docs:`)
6. Push and create a Pull Request

### Code Standards

- Follow Clarity best practices and naming conventions
- Add comprehensive test coverage for new features
- Update documentation for API changes
- Include security considerations in PR descriptions

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
