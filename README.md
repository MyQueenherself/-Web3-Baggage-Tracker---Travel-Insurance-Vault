# 🧳 Web3 Baggage Tracker & Travel Insurance Vault

> 🚀 Decentralized travel insurance with automated claims processing and real-time baggage tracking

## 🌟 Overview

This smart contract revolutionizes travel insurance by providing:
- ⚡ **Instant Policy Creation**: Get coverage in seconds, not days
- 📍 **Real-time Baggage Tracking**: Monitor your luggage location
- 🤖 **Automated Claims Processing**: Smart contract handles payouts
- 💰 **Secure Vault System**: Funds held in escrow until needed
- 🔍 **Transparent Operations**: All transactions on-chain

## 🎯 Problem & Solution

**Problem**: Travelers lose luggage or face delays with slow/no insurance payouts 😤

**Solution**: Smart contracts hold insurance funds and automatically release them on verified travel disruptions ✅

**Impact**: Brings speed, trust, and automation to travel insurance claims 🌍

## 🔧 Core Features

### 📋 Insurance Policies
- Create coverage with customizable amounts and duration
- Automatic premium calculation based on coverage
- Policy extension functionality
- Multi-policy support per user

### 🎒 Baggage Management  
- Register baggage items with initial location
- Update status and location in real-time
- Track multiple items per policy
- Value-based coverage allocation

### 💸 Claims Processing
- Submit claims with evidence
- Automated processing for lost baggage
- Manual review system for complex cases
- Instant payouts upon approval

### ✈️ Travel Delay Compensation
- Report flight delays with automatic compensation
- Tiered compensation based on delay duration
- Instant payouts for qualifying delays
- No manual claims processing required

### 🔄 Policy Transfer & Beneficiary System
- Transfer policy ownership between users
- Set beneficiaries with emergency access rights
- Corporate travel management capabilities
- Family policy management for minors

## 🚀 Usage Instructions

### Creating a Policy

```clarity
(contract-call? .contract create-policy u1000000 u1008)
```
- `coverage-amount`: Maximum payout amount in microSTX
- `duration-blocks`: Policy duration in blocks (~1 week = 1008 blocks)

### Registering Baggage

```clarity
(contract-call? .contract register-baggage u1 "Airport Check-in" u500000)
```
- `policy-id`: Your policy ID
- `initial-location`: Starting location
- `value`: Baggage value in microSTX

### Updating Baggage Status

```clarity
(contract-call? .contract update-baggage-status u1 "in-transit" "Flight ABC123")
```
- `baggage-id`: Baggage ID to update
- `new-status`: Current status ("registered", "in-transit", "delivered", "lost")
- `location`: Current location

### Submitting Claims

```clarity
(contract-call? .contract submit-claim u1 u1 "lost-baggage" u500000 "Flight delayed 6 hours")
```
- `policy-id`: Policy ID
- `baggage-id`: Affected baggage ID  
- `claim-type`: Type of claim ("lost-baggage", "delayed", "damaged")
- `amount`: Claim amount in microSTX
- `evidence`: Supporting evidence

### Reporting Flight Delays

```clarity
(contract-call? .contract report-flight-delay u1 "AA123" u1000 u1300)
```
- `policy-id`: Your policy ID
- `flight-number`: Flight identifier
- `scheduled-departure`: Scheduled departure time (block height)
- `actual-departure`: Actual departure time (block height)

### Processing Delay Compensation

```clarity
(contract-call? .contract process-delay-compensation u1)
```
- Automatically calculates and pays compensation based on delay duration
- 6+ hours: 25% of coverage
- 3+ hours: 12.5% of coverage  
- 1+ hours: 6.25% of coverage

### Managing Policy Transfers & Beneficiaries

```clarity
(contract-call? .contract set-policy-beneficiary u1 'SP123... true)
```
- Set a beneficiary with emergency access rights

```clarity
(contract-call? .contract request-policy-transfer u1 'SP456...)
```
- Request to transfer policy to another user

```clarity
(contract-call? .contract approve-policy-transfer u1)
```
- Approve an incoming policy transfer (called by recipient)

```clarity
(contract-call? .contract beneficiary-submit-claim u1 u1 "emergency" u100000 "Traveler incapacitated")
```
- Submit emergency claim as beneficiary

### Reading Contract Data

```clarity
(contract-call? .contract get-policy u1)
(contract-call? .contract get-baggage u1)
(contract-call? .contract get-claim u1)
(contract-call? .contract get-delay u1)
(contract-call? .contract get-policy-beneficiary u1)
(contract-call? .contract get-transfer-request u1)
(contract-call? .contract get-user-policies 'SP1234...)
(contract-call? .contract get-delay-compensation-estimate u180 u1000000)
(contract-call? .contract can-user-access-policy u1 'SP123...)
```

## 🔐 Security Features

- ✅ **Owner Authorization**: Only contract owner can process claims
- ✅ **Policy Validation**: Claims verified against active policies
- ✅ **Fund Protection**: Automatic balance checks prevent overdrafts
- ✅ **Time Limits**: Claims must be processed within timeframes
- ✅ **Status Verification**: Prevents duplicate claim processing

## 💡 Smart Automation

### Auto-Processing Lost Baggage
If baggage status is "lost" and hasn't been updated for 1008 blocks (~1 week), the contract automatically processes a claim for the baggage value.

```clarity
(contract-call? .contract auto-process-lost-baggage u1)
```

### Policy Extension
Extend coverage duration by paying additional premium:

```clarity
(contract-call? .contract extend-policy u1 u504)
```

## 📊 Contract State

The contract maintains:
- **Policies**: Coverage details and vault balances
- **Baggage Items**: Status, location, and ownership
- **Claims**: Submission details and processing status
- **User Mappings**: Policy and baggage associations

## 🌐 Deployment

1. **Clone & Setup**:
   ```bash
   git clone <repository-url>
   cd Web3-Baggage-Tracker---Travel-Insurance-Vault
   ```

2. **Deploy with Clarinet**:
   ```bash
   clarinet deploy --testnet
   ```

3. **Test Functions**:
   ```bash
   clarinet test
   ```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push branch: `git push origin feature/amazing-feature`
5. Open Pull Request

## 📜 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Built with ❤️ for the decentralized travel future** 🌟✈️
