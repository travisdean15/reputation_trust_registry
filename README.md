# Reputation & Trust Registry

A comprehensive on-chain reputation system built on the Stacks blockchain using Clarity smart contracts. This system provides decentralized reputation tracking, Sybil resistance through staking, and transferable NFT badges.

## Features

### <¯ Core Functionality
- **On-chain Reputation Scores**: Track user reputation with transparent scoring
- **Stake-based Sybil Resistance**: Users must stake STX to participate and earn reputation
- **Reputation Decay**: Automatic score reduction over time to maintain system health
- **Transferable Badges**: NFT-like achievements that users can earn and trade

### = Security Features
- **Authorization System**: Only authorized contracts and admin can modify reputation
- **Slashing Mechanism**: Admin can reduce stakes as penalties for bad behavior
- **Emergency Controls**: Contract pause/unpause functionality
- **Input Validation**: Comprehensive checks on all user inputs

### ™ Admin Controls
- Set decay rates (0-100%)
- Configure minimum stake requirements
- Authorize/revoke contract permissions
- Emergency pause/unpause
- Slash user stakes for penalties

## Smart Contract Architecture

### Data Structures

```clarity
;; User Data
{
  reputation-score: uint,
  staked-amount: uint,
  last-decay-block: uint
}

;; Badge Metadata
{
  name: (string-ascii 64),
  description: (string-ascii 256),
  creator: principal
}
```

### Key Constants
- **Minimum Stake**: 1 STX (1,000,000 microSTX)
- **Default Decay Rate**: 5% per decay call
- **Badge Reputation Requirement**: 100 points minimum

## Usage

### For Users

#### 1. Stake STX
```clarity
(stake u1000000) ;; Stake 1 STX minimum
```

#### 2. Earn Reputation
Reputation is awarded by authorized contracts or admin for verified actions:
- Completing tasks
- Participating in governance
- Contributing to community

#### 3. Earn Badges
Once you have 100+ reputation, you can be awarded badges:
```clarity
(mint-badge user "Hero" "Heroic achievements")
```

### For Developers

#### Integrating with the Registry

1. **Get Authorization**: Contact admin to authorize your contract
2. **Award Reputation**: 
   ```clarity
   (increment-reputation user-principal points)
   ```
3. **Check User Status**:
   ```clarity
   (get-reputation user-principal)
   (get-stake user-principal)
   ```

## Installation & Testing

### Prerequisites
- [Clarinet](https://docs.hiro.so/clarinet) installed
- Node.js and npm

### Setup
```bash
git clone <repository-url>
cd reputation_trust_registry/reputation_trust
npm install
```

### Testing
```bash
# Run all tests
npm test

# Run with coverage
npm run test:report

# Watch mode
npm run test:watch
```

### Development
```bash
# Check contract syntax
clarinet check

# Deploy to devnet
clarinet integrate
```

## API Reference

### Public Functions

#### Staking
- `stake(amount: uint)` - Stake STX to participate
- `unstake()` - Withdraw all staked STX
- `partial-unstake(amount: uint)` - Withdraw partial stake

#### Reputation Management
- `increment-reputation(user: principal, points: uint)` - Add reputation points
- `decrement-reputation(user: principal, points: uint)` - Remove reputation points
- `decay-reputation(user: principal)` - Apply time-based decay

#### Badge System
- `mint-badge(user: principal, name: string, description: string)` - Create new badge
- `transfer-badge(from: principal, to: principal, badge-id: uint)` - Transfer badge
- `burn-badge(badge-id: uint)` - Destroy badge

#### Admin Functions
- `set-decay-rate(new-rate: uint)` - Update decay percentage
- `set-min-stake(new-min: uint)` - Change minimum stake requirement
- `authorize-contract(contract: principal)` - Grant reputation management rights
- `slash-stake(user: principal, amount: uint)` - Penalty mechanism
- `pause-contract()` / `unpause-contract()` - Emergency controls

### Read-Only Functions

- `get-reputation(user: principal)` - Get user's reputation score
- `get-stake(user: principal)` - Get user's staked amount
- `get-user-data(user: principal)` - Get complete user information
- `get-badge-owner(badge-id: uint)` - Get badge owner
- `get-badge-metadata(badge-id: uint)` - Get badge information
- `user-owns-badge(user: principal, badge-id: uint)` - Check badge ownership
- `get-contract-settings()` - Get current system parameters
- `is-authorized-contract(contract: principal)` - Check authorization status

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 401 | ERR-UNAUTHORIZED | Caller lacks permission |
| 402 | ERR-INSUFFICIENT-STAKE | Not enough staked STX |
| 403 | ERR-INVALID-AMOUNT | Invalid input amount |
| 404 | ERR-USER-NOT-FOUND | User not registered |
| 405 | ERR-BADGE-NOT-FOUND | Badge doesn't exist |
| 407 | ERR-INSUFFICIENT-REPUTATION | Not enough reputation for action |
| 408 | ERR-TRANSFER-FAILED | STX transfer failed |

## Events

All major actions emit structured events for tracking:

- `StakeAdded` - User stakes STX
- `StakeWithdrawn` - User unstakes STX  
- `PartialStakeWithdrawn` - Partial unstaking
- `StakeSlashed` - Admin penalty applied
- `ReputationUpdated` - Score changed
- `ReputationDecayed` - Time decay applied
- `BadgeMinted` - New badge created
- `BadgeTransferred` - Badge ownership changed
- `BadgeBurned` - Badge destroyed
- `ContractPaused` / `ContractUnpaused` - Emergency controls

## Use Cases

### <Û Governance Systems
- Reputation-weighted voting
- Proposal submission requirements
- Delegate selection based on trust scores

### <® Gaming & Social Platforms
- Player skill ratings
- Achievement systems
- Trust-based matchmaking

### > Marketplace & Trading
- Seller reputation scores
- Buyer protection mechanisms  
- Service provider ratings

### =¼ Professional Networks
- Skill verification badges
- Work history tracking
- Professional endorsements

## Security Considerations

- **Stake Requirements**: Prevents spam and Sybil attacks
- **Decay Mechanism**: Prevents reputation hoarding
- **Authorization Checks**: Only trusted contracts can modify scores
- **Emergency Controls**: Admin can pause system if needed
- **Input Validation**: All parameters are validated
- **Slashing**: Economic penalties for bad behavior

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

For questions, suggestions, or support, please open an issue on GitHub.