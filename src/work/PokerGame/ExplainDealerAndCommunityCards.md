### 1. Dealer Role

**Concept:**
The dealer is a crucial role in a poker game, responsible for managing and revealing community cards. To implement this, we introduce a distinct dealer role using the AccessControl mechanism provided by OpenZeppelin.

**Implementation:**
- Define a constant for the `DEALER_ROLE`.
- Use AccessControl to manage this role, allowing specific addresses to be assigned as dealers.

### 2. Community Cards Commitment and Revelation

**Concept:**
In poker, community cards (flop, turn, river) are initially kept secret and revealed progressively. This means they decide on the cards in advance but keep them secret. To ensure fairness and prevent tampering, the dealer will commit to these cards upfront using cryptographic commitments (hashes). These commitments are revealed later to verify that no changes were made to the cards.

**Implementation:**
- Create a `CommunityCards` struct to hold the commitments and the actual cards.
- The dealer provides a cryptographic hash of each card's value. 
- These hashes are stored securely initially. This step is called "committing" the cards.
- When revealing the cards, ensure the revealed cards match their initial commitments using cryptographic verification.

### 3. Card Commitment

**Concept:**
At specific points during the game, the dealer reveals the cards. To maintain trust, the revealed cards must match the committed hashes. This ensures the dealer didn't change the cards after committing to them.
The dealer commits to each card by providing a cryptographic hash of the card's value. This ensures that the card cannot be changed later without detection.

**Implementation:**
- Implement a function `commitCommunityCards` that takes the cryptographic commitments (hashes) for the flop, turn, and river cards.
- When the dealer reveals a card, the system checks if the card's hash matches the initially stored commitment.
- Store these commitments in the `CommunityCards` struct.
- These hashes are stored securely. This step is called "committing" the cards.
- Use digital signatures to verify that the revealed cards come from the dealer, preventing unauthorized parties from revealing cards.

### 4. Card Revelation

**Concept:**
The actual values of the community cards are revealed progressively (flop, turn, river). Each revealed card must match its initial commitment to ensure fairness. Cryptographic methods ensure that the commitments and revelations are secure and verifiable. This prevents cheating and ensures integrity.

**Implementation:**
- Implement functions `revealFlop`, `revealTurn`, and `revealRiver`.
- Each function checks the revealed card against the initial commitment using cryptographic verification.
- Use signatures to ensure that the dealer is the one revealing the cards.

### 5. Cryptographic Verification

**Concept:**
To verify that the revealed cards match their initial commitments, cryptographic signatures and hashing are used. This ensures the integrity and authenticity of the revealed cards.

**Implementation:**
- Use the ECDSA library from OpenZeppelin for cryptographic operations.
- Verify that the hash of the revealed card matches the stored commitment.
- Ensure the dealer's signature validates the revealed card.

### 6. Events for Transparency

**Concept:**
Emitting events when cards are committed and revealed provides transparency and allows external observers to track the game's progress.

**Implementation:**
- Emit events `CardCommitted` and `CardRevealed` for each card commitment and revelation.

### 7. Access Control

**Concept:**
Restrict certain functions to only be callable by the dealer or admin, ensuring that only authorized parties can commit or reveal cards.

**Implementation:**
- Use a modifier `onlyDealer` to restrict functions to the dealer.
- Implement a function to assign a dealer to a game, restricted to the admin role.
