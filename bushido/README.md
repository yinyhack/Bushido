# Bushido

A Clarity smart contract implementing an honorable samurai dueling game on the Stacks blockchain. Two warriors commit to hidden fighting stances and reveal them in turn-based combat following the ancient way of the warrior.

## Overview

Bushido is a commit-reveal game where samurai challenge each other to honor duels. Players secretly choose their fighting technique, then reveal simultaneously to determine the victor through honorable combat.

### Combat System

The game follows a rock-paper-scissors mechanic with samurai techniques:

- **Katana Strike** defeats **Defensive Stance**
- **Defensive Stance** defeats **Throwing Star** 
- **Throwing Star** defeats **Katana Strike**

## Game Flow

1. **Challenge Phase**: A samurai challenges an opponent, setting honor stakes and battlefield location
2. **Commitment Phase**: Both warriors secretly commit their fighting stance using cryptographic hashes
3. **Reveal Phase**: Warriors reveal their techniques with spirit energy to prove authenticity
4. **Resolution**: The contract determines the victor and concludes the duel

## Key Features

- **Commit-Reveal Mechanism**: Prevents cheating by hiding moves until both players commit
- **Honor System**: Duels are bound by honor stakes and conducted on named battlefields
- **Cryptographic Security**: Uses SHA-256 hashing to ensure technique authenticity
- **Phase Management**: Enforces proper game progression through distinct phases

## Contract Functions

### Public Functions

- `challenge-to-duel`: Issue an honor challenge to another samurai
- `set-fighting-stance`: Commit your secret fighting technique 
- `reveal-technique`: Reveal your technique with spirit energy proof

### Read-Only Functions

- `get-duel-details`: View complete duel information
- `get-honor-victor`: Check who won a specific duel
- `technique-name`: Convert technique codes to readable names
- `get-battlefield`: View the duel location

## Technical Details

### Data Structures

The contract maintains honor duels in a map with the following structure:
- Samurai participants
- Hidden stance commitments (SHA-256 hashes)
- Revealed techniques
- Victor determination
- Duel phase tracking
- Honor stakes and battlefield location

### Security Features

- **Commitment Binding**: Players cannot change their move after committing
- **Authenticity Verification**: Reveals must match original commitments
- **Phase Enforcement**: Actions are only valid in appropriate game phases
- **Participant Validation**: Only duel participants can make moves

## Error Codes

- `ERR-HONOR-VIOLATED (100)`: Cannot duel yourself
- `ERR-DUEL-NOT-FOUND (101)`: Invalid duel ID
- `ERR-STANCE-COMMITTED (102)`: Stance already set
- `ERR-STANCE-NOT-SET (103)`: Must set stance first
- `ERR-ALREADY-SHOWN (104)`: Technique already revealed
- `ERR-INVALID-TECHNIQUE (105)`: Invalid technique or hash mismatch
- `ERR-DUEL-CONCLUDED (106)`: Duel is finished
- `ERR-TOO-EARLY-REVEAL (107)`: Cannot reveal before commitment phase ends
- `ERR-NOT-PARTICIPANT (108)`: Only duel participants can act

## Usage Example

```clarity
;; Challenge another samurai
(challenge-to-duel 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u100 "Cherry Blossom Dojo")

;; Commit your stance (hash of technique + spirit energy + your principal)
(set-fighting-stance u1 0x1234...hash)

;; Reveal your technique
(reveal-technique u1 u1 u42) ;; Katana Strike with spirit energy 42
```

## Philosophy

Built in the spirit of bushido - the way of the warrior - this contract emphasizes honor, commitment, and fair play. The commit-reveal mechanism ensures that victory comes through strategy and honor, not deception or timing advantages.
