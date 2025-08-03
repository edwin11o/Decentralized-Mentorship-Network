# Decentralized Mentorship Network Smart Contract

A blockchain-based mentorship platform built on Stacks that connects mentors and mentees with transparent reputation tracking, secure payments, and decentralized governance.

## Overview

The Decentralized Mentorship Network enables professionals to offer mentorship services while providing mentees with access to quality guidance. The platform handles payments, reputation management, and session coordination through smart contracts, ensuring transparency and trust.

## Features

### Core Functionality
- **Mentor Registration**: Professionals can register with their expertise, hourly rates, and background
- **Mentee Registration**: Students/professionals can create profiles with their interests and goals
- **Session Booking**: Secure booking system with escrow-based payments
- **Session Management**: Start, complete, and track mentorship sessions
- **Rating System**: Bi-directional rating system for mentors and mentees
- **Balance Management**: Deposit, withdraw, and manage STX tokens for payments

### Smart Contract Features
- **Escrow System**: Funds are held in the contract until session completion
- **Platform Fees**: 2% platform fee for sustainability
- **Reputation Tracking**: Automatic calculation of mentor ratings
- **Session History**: Complete audit trail of all mentorship activities

## Contract Structure

### Data Maps
- `mentors`: Stores mentor profiles, rates, and statistics
- `mentees`: Stores mentee profiles and preferences  
- `sessions`: Tracks all mentorship sessions and their status
- `session-ratings`: Stores ratings and feedback for completed sessions
- `user-balances`: Manages user STX balances within the platform

### Session States
- `pending`: Session booked but not yet started
- `active`: Session currently in progress
- `completed`: Session finished and payments processed
- `cancelled`: Session cancelled (future enhancement)

## Public Functions

### Registration Functions
```clarity
(register-mentor (name string) (expertise string) (hourly-rate uint))
(register-mentee (name string) (interests string))
(update-mentor-profile (name string) (expertise string) (hourly-rate uint))
```

### Financial Functions
```clarity
(deposit-funds (amount uint))
(withdraw-funds (amount uint))
```

### Session Management
```clarity
(book-session (mentor principal) (duration uint))
(start-session (session-id uint))
(complete-session (session-id uint))
(rate-session (session-id uint) (rating uint) (feedback string))
```

### Read-Only Functions
```clarity
(get-mentor (mentor principal))
(get-mentee (mentee principal))
(get-session (session-id uint))
(get-session-rating (session-id uint))
(get-user-balance (user principal))
(get-platform-revenue)
```

## Usage Flow

### For Mentors
1. Register as a mentor with `register-mentor`
2. Wait for mentees to book sessions
3. Start sessions using `start-session`
4. Complete sessions with `complete-session` to receive payment
5. Rate mentees using `rate-session`
6. Withdraw earnings with `withdraw-funds`

### For Mentees
1. Register as a mentee with `register-mentee`
2. Deposit funds using `deposit-funds`
3. Book sessions with desired mentors using `book-session`
4. Participate in sessions (started by mentor)
5. Rate mentors after session completion
6. Withdraw unused funds if needed

## Error Codes

- `u401`: Not authorized to perform action
- `u402`: Resource already exists (duplicate registration)
- `u403`: Insufficient balance
- `u404`: Resource not found
- `u405`: Action already completed
- `u406`: Invalid rating (must be 1-5)
- `u407`: Session not started yet

## Security Features

- **Authorization Checks**: Only authorized users can perform specific actions
- **Balance Validation**: Prevents overdrawing and invalid amounts
- **Session State Management**: Enforces proper session lifecycle
- **Rating Validation**: Ensures ratings are within valid range (1-5 stars)
- **Escrow Protection**: Funds are held securely until session completion

## Platform Economics

- **Platform Fee**: 2% of each completed session goes to platform revenue
- **Mentor Payments**: 98% of session cost paid to mentors upon completion
- **Rating Impact**: Mentor ratings automatically update their reputation

## Deployment

1. Deploy the contract to Stacks blockchain
2. The deployer becomes the contract owner
3. Users can immediately start registering as mentors/mentees

## Future Enhancements

- Session cancellation and refund mechanisms
- Dispute resolution system
- Mentor verification badges
- Group mentorship sessions
- Integration with external identity providers
- Advanced matching algorithms based on expertise and interests

## Testing

The contract includes comprehensive error handling and validation. Test scenarios should cover:

- Registration edge cases
- Payment flows with insufficient funds
- Session lifecycle management
- Rating system accuracy
- Withdrawal restrictions
- Authorization boundaries

## Contributing

This is an open-source project. Contributions are welcome for:
- Additional features
- Security improvements
- Gas optimization
- Documentation enhancements
- Testing coverage

## License

This project is open source and available under the MIT License.