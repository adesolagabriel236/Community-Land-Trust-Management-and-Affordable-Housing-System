# Community Land Trust Management and Affordable Housing System

A blockchain-based system for managing community land trusts and maintaining affordable housing through smart contracts on the Stacks blockchain.

## Overview

This system provides a decentralized approach to community land trust management, ensuring long-term affordability, community control, and sustainable housing solutions. The system consists of five interconnected smart contracts that work together to manage all aspects of a community land trust.

## System Architecture

### Core Contracts

1. **Land Ownership Contract** (`land-ownership.clar`)
    - Verifies and manages land held in trust for community benefit
    - Tracks land parcels, ownership status, and trust conditions
    - Prevents speculative land acquisition

2. **Affordability Restrictions Contract** (`affordability-restrictions.clar`)
    - Enforces price limits on housing to maintain affordability
    - Manages resale restrictions and price appreciation caps
    - Calculates maximum allowable sale prices

3. **Member Selection Contract** (`member-selection.clar`)
    - Prioritizes housing allocation for local residents and essential workers
    - Manages waiting lists and eligibility criteria
    - Handles application and selection processes

4. **Property Maintenance Contract** (`property-maintenance.clar`)
    - Coordinates upkeep and repairs of community-owned housing
    - Manages maintenance funds and contractor selection
    - Tracks property conditions and maintenance history

5. **Governance Contract** (`governance.clar`)
    - Enables resident participation in community land trust decisions
    - Manages voting on policy changes and major decisions
    - Handles proposal submission and voting processes

## Key Features

- **Permanent Affordability**: Housing remains affordable in perpetuity through resale restrictions
- **Community Control**: Residents have democratic input on trust operations
- **Local Priority**: Housing prioritized for community members and essential workers
- **Transparent Maintenance**: All maintenance activities tracked on-chain
- **Anti-Speculation**: Prevents speculative investment in community land

## Data Structures

### Land Parcels
- Unique parcel ID
- Geographic coordinates
- Trust status and conditions
- Current use designation

### Housing Units
- Unit ID linked to land parcel
- Affordability restrictions
- Current and maximum allowable prices
- Resident information

### Community Members
- Member status and eligibility
- Priority level (local resident, essential worker, etc.)
- Application history

### Maintenance Records
- Work orders and completion status
- Contractor information
- Cost tracking and fund allocation

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm
- Stacks wallet for testing

### Installation

1. Clone the repository
2. Install dependencies: \`npm install\`
3. Run tests: \`npm test\`
4. Deploy contracts: \`clarinet deploy\`

### Testing

The system includes comprehensive tests using Vitest:

\`\`\`bash
npm test
\`\`\`

Tests cover:
- Contract deployment and initialization
- Land trust creation and management
- Affordability restriction enforcement
- Member selection and prioritization
- Maintenance coordination
- Governance voting mechanisms

## Usage Examples

### Creating a Land Trust
1. Deploy land ownership contract
2. Register land parcels with trust conditions
3. Set affordability restrictions for housing units
4. Initialize community member registry

### Managing Housing Allocation
1. Community members submit applications
2. Selection contract prioritizes based on criteria
3. Affordability contract enforces price limits
4. Governance contract handles appeals and policy changes

### Maintenance Coordination
1. Residents report maintenance needs
2. Property maintenance contract manages work orders
3. Community votes on major repairs through governance
4. Transparent tracking of all maintenance activities

## Security Considerations

- All contracts include proper access controls
- Price manipulation prevention mechanisms
- Multi-signature requirements for major decisions
- Audit trails for all transactions

## Contributing

Please read the PR-DETAILS.md file for information about contributing to this project.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
