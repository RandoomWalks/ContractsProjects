// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Card Game Implementation in Solidity
/// @author An experienced Web3 tech lead
/// @notice This contract implements basic functionality for a card game
contract CardGame {
    //  Card Representation
    enum Suit { Hearts, Diamonds, Clubs, Spades }
    enum Value { Two, Three, Four, Five, Six, Seven, Eight, Nine, Ten, Jack, Queen, King, Ace }

    struct Card {
        Suit suit;
        Value value;
    }

    //  Deck Initialization
    Card[] private deck;

    //  Dealing Cards
    mapping(address => Card[]) private playerHands;

    //  Player Management
    address[] private players;

    /// @notice Initializes the deck with 52 cards
    function initializeDeck() public {
        delete deck; // Clear the existing deck
        for (uint8 s = 0; s < 4; s++) {
            for (uint8 v = 0; v < 13; v++) {
                deck.push(Card(Suit(s), Value(v)));
            }
        }
    }

    /// @notice Shuffles the deck using Fisher-Yates algorithm
    /// @dev This uses block information for randomness, which is not secure for high-stakes games
    function shuffleDeck() public {
        for (uint256 i = deck.length - 1; i > 0; i--) {
            uint256 j = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, i))) % (i + 1);
            (deck[i], deck[j]) = (deck[j], deck[i]);
        }
    }

    /// @notice Deals a specified number of cards to a player
    /// @param player The address of the player to deal cards to
    /// @param numCards The number of cards to deal
    function dealCards(address player, uint256 numCards) public {
        require(numCards <= deck.length, "Not enough cards in the deck");
        for (uint256 i = 0; i < numCards; i++) {
            playerHands[player].push(deck[deck.length - 1]);
            deck.pop();
        }
    }

    /// @notice Adds a new player to the game
    /// @param player The address of the player to add
    function addPlayer(address player) public {
        require(!isPlayer(player), "Player already exists");
        players.push(player);
    }

    /// @notice Removes a player from the game
    /// @param player The address of the player to remove
    function removePlayer(address player) public {
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == player) {
                players[i] = players[players.length - 1];
                players.pop();
                delete playerHands[player];
                break;
            }
        }
    }

    /// @notice Checks if an address is a player in the game
    /// @param player The address to check
    /// @return bool True if the address is a player, false otherwise
    function isPlayer(address player) public view returns (bool) {
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == player) {
                return true;
            }
        }
        return false;
    }

    /// @notice Gets the number of cards in a player's hand
    /// @param player The address of the player
    /// @return uint256 The number of cards in the player's hand
    function getPlayerHandSize(address player) public view returns (uint256) {
        return playerHands[player].length;
    }

    /// @notice Gets the number of cards left in the deck
    /// @return uint256 The number of cards in the deck
    function getDeckSize() public view returns (uint256) {
        return deck.length;
    }

    /// @notice Gets the number of players in the game
    /// @return uint256 The number of players
    function getNumberOfPlayers() public view returns (uint256) {
        return players.length;
    }
}