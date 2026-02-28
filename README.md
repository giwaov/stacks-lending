# Stacks Lending

A peer-to-peer lending protocol on Stacks blockchain using `@stacks/connect` and `@stacks/transactions`.

## Features

- 🏦 Request loans with custom terms
- 💵 Fund loans as a lender
- 📊 Track loan status
- 💰 Earn interest on funded loans

## Tech Stack

- **Frontend**: Next.js 14, React 18, TypeScript
- **Blockchain**: Stacks Mainnet
- **Smart Contract**: Clarity
- **Libraries**: @stacks/connect, @stacks/transactions, @stacks/network

## Contract Functions

- `request-loan` - Create loan request
- `fund-loan` - Fund a pending loan
- `repay-loan` - Repay borrowed amount + interest
- `get-loan` - Get loan details
- `calculate-repayment` - Calculate total repayment

## Getting Started

```bash
npm install
npm run dev
```

## Contract Address

Deployed on Stacks Mainnet: `SP3E0DQAHTXJHH5YT9TZCSBW013YXZB25QFDVXXWY.lending`

## License

MIT
