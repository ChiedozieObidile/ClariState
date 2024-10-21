# SecureEstate Smart Contract

A secure, transparent, and efficient escrow system for real estate transactions built on the Stacks blockchain using Clarity smart contracts.

## Overview

SecureEstate is a decentralized escrow solution designed to facilitate secure real estate transactions by implementing a trustless system that protects both buyers and sellers. The smart contract manages the entire transaction lifecycle, from property registration to final payment settlement.

## Features

- 🔐 **Secure Escrow System**: Automated handling of deposits and final payments
- 📋 **Property Registration**: Detailed property information storage and validation
- ⏱️ **Time-Bound Transactions**: Configurable deadlines for transaction completion
- 🏠 **Property Inspection Integration**: Built-in support for recording inspection results
- 👥 **Multi-Party Authorization**: Separate roles for buyer, seller, and contract owner
- 💰 **Maintenance Fund Management**: Post-sale maintenance fund handling
- 🔍 **Transaction Tracking**: Comprehensive transaction history and status monitoring

## Contract Functions

### Administrative Functions

- `initialize-escrow`: Set up a new escrow agreement between buyer and seller
- `register-property`: Record property details including address, size, and year built
- `record-inspection`: Document property inspection results

### Transaction Functions

- `pay-deposit`: Submit the initial deposit (10% of property price)
- `pay-remaining`: Complete the transaction with the remaining payment
- `refund-deposit`: Return deposit to buyer if conditions aren't met
- `add-maintenance-fund`: Contribute to property maintenance fund

### Query Functions

- `get-escrow-details`: Retrieve current escrow agreement details
- `get-transaction-detail`: View specific transaction information
- `get-property-detail`: Access registered property information
- `get-time-remaining`: Check remaining time before deadline
- `is-allowed-principal`: Verify if an address is authorized

## Error Handling

The contract includes comprehensive error handling for various scenarios:

- Invalid authorization attempts
- Incorrect transaction amounts
- Missing prerequisites
- Deadline violations
- Invalid property details
- Failed inspections

## Security Features

- Role-based access control
- Transaction validation checks
- Deadline enforcement
- Secure fund management
- Principal validation
- State transition guards

## Usage Example

```clarity
;; Initialize a new escrow agreement
(contract-call? .secureestate initialize-escrow 
    'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM  ;; seller
    'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG  ;; buyer
    u1000000  ;; price in uSTX
    u30)      ;; days active

;; Register property details
(contract-call? .secureestate register-property 
    u1  ;; property ID
    "123 Blockchain Street, Crypto City"  ;; address
    u2500  ;; size in sq ft
    u2020)  ;; year built
```

## Requirements

- Stacks 2.0 blockchain
- Clarity smart contract language
- STX token for transactions

## Getting Started

1. Deploy the contract to the Stacks blockchain
2. Initialize escrow with buyer and seller information
3. Register property details
4. Begin transaction process with deposit
5. Complete inspection and verification steps
6. Finalize transaction with remaining payment

## Security Considerations

- All functions include proper authorization checks
- Funds are securely held in contract until conditions are met
- Timelock mechanisms prevent indefinite fund locking
- Multiple validation layers for all critical operations


## Contributing

Ogechi