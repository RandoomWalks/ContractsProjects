// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Importing necessary contracts and libraries from OpenZeppelin and LitProtocol
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@litprotocol/contracts/LitAccessControl.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// Main contract for managing a poker game
contract PokerGame is ERC721, ReentrancyGuard, LitAccessControl, VRFConsumerBaseV2, AccessControl {
    using Counters for Counters.Counter; // Using Counters for managing unique game IDs
    using ECDSA for bytes32;

    Counters.Counter private _gameIds; // Counter for game IDs

    // Chainlink VRF variables
    VRFCoordinatorV2Interface COORDINATOR;
    uint64 s_subscriptionId;
    bytes32 keyHash;
    uint32 callbackGasLimit = 100000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;

    // Mapping to store VRF requests
    mapping(uint256 => uint256) private vrfRequests;

    mapping(bytes32 => bool) private revealedCards;

    // Note: The callbackGasLimit may need to be adjusted based on the complexity of your shuffleDeck function
    uint32 callbackGasLimit = 200000;

    bytes32 public constant PLAYER_ROLE = keccak256("PLAYER_ROLE");
    bytes32 public constant CURRENT_TURN_ROLE = keccak256("CURRENT_TURN_ROLE");
    bytes32 public constant DEALER_ROLE = keccak256("DEALER_ROLE");

   // Struct to represent community cards
    struct CommunityCards {
        bytes32 flop1Commitment;
        bytes32 flop2Commitment;
        bytes32 flop3Commitment;
        bytes32 turnCommitment;
        bytes32 riverCommitment;
        Card flop1;
        Card flop2;
        Card flop3;
        Card turn;
        Card river;
        bool flopRevealed;
        bool turnRevealed;
        bool riverRevealed;
    }

    uint8 constant MAX_PLAYERS = 6; // Maximum number of players per game
    uint256 constant INITIAL_CHIP_COUNT = 1000; // Initial chip count for each player

    // Enum representing the possible states of the game
    enum GameState { WAITING, SHUFFLING, ACTIVE, REVEALING_COMMUNITY_CARDS, FINISHED }

    // Enum representing the possible actions a player can take
    enum PlayerAction { NONE, CALL, RAISE, FOLD }

    // Struct representing a player in the game
    struct Player {
        address addr; // Player's address
        uint256 chipCount; // Player's chip count
        PlayerAction lastAction; // Player's last action
        bool isActive; // Whether the player is active in the game
        bool hasPlayerRole;
        bool hasCurrentTurnRole;
    }

    // Struct representing a poker game
    struct Game {
        uint256 id; // Game ID
        GameState state; // Current state of the game
        uint8 playerCount; // Number of players in the game
        uint8 currentPlayerIndex; // Index of the current player
        uint256 pot; // Total pot amount
        uint256 highestBet; // Highest bet in the current round
        mapping(uint8 => Player) players; // Mapping of players in the game
        uint8 dealerIndex; // Index of the dealer
        uint8 smallBlindIndex; // Index of the small blind
        uint8 bigBlindIndex; // Index of the big blind
        address dealer;
        CommunityCards communityCards;
    }

    mapping(uint256 => Game) public games; // Mapping of game IDs to Game structs

    // Events for logging important actions in the game
    event GameCreated(uint256 indexed gameId, address creator); // Event for game creation
    event PlayerJoined(uint256 indexed gameId, address player); // Event for player joining
    event GameStarted(uint256 indexed gameId); // Event for game starting
    event TurnChanged(uint256 indexed gameId, address player); // Event for turn changing
    event PlayerAction(uint256 indexed gameId, address player, PlayerAction action, uint256 amount); // Event for player action
    event GameEnded(uint256 indexed gameId, address winner, uint256 pot); // Event for game ending
    // New event to signal that the deck is being shuffled
    event GameShuffling(uint256 indexed gameId);
    // New event to signal that the deck has been shuffled
    event DeckShuffled(uint256 indexed gameId);
    // Constructor for initializing the ERC721 token
    event VRFRequestFailed(uint256 indexed gameId, string reason);
    // Event for card commitment
    event CardCommitted(uint256 indexed gameId, string position, bytes32 commitment);
    // Event for card revelation
    event CardRevealed(uint256 indexed gameId, string position, uint8 rank, uint8 suit);
    event DealerAssigned(uint256 indexed gameId, address dealer);


    modifier onlyGameCreator(uint256 gameId) {
        require(games[gameId].creator == msg.sender, "Only game creator can start the game");
        _;
    }
    // Modifier to restrict access to the assigned dealer
    modifier onlyDealer(uint256 gameId) {
        require(msg.sender == games[gameId].dealer, "Only the assigned dealer can perform this action");
        _;
    }
    constructor(uint64 subscriptionId) ERC721("PokerGame", "PKR")
        VRFConsumerBaseV2(0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D) // VRF Coordinator address (Sepolia)
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        COORDINATOR = VRFCoordinatorV2Interface(0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D);
        s_subscriptionId = subscriptionId;
        keyHash = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c; // Sepolia key hash
        _setupRole(DEALER_ROLE, msg.sender); // Set the contract deployer as the initial dealer
    }

    // Function to assign a dealer to a game
    function assignDealer(uint256 gameId, address dealer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(hasRole(DEALER_ROLE, dealer), "Address is not a dealer");
        games[gameId].dealer = dealer;
        emit DealerAssigned(gameId, dealer);
    }

    // Function to create a new game
    function createGame() external returns (uint256) {
        _gameIds.increment(); // Increment the game ID counter
        uint256 newGameId = _gameIds.current(); // Get the new game ID

        Game storage newGame = games[newGameId]; // Create a new game in storage
        newGame.id = newGameId; // Set the game ID
        newGame.state = GameState.WAITING; // Set the initial state to WAITING
        newGame.playerCount = 0; // Initialize the player count to 0
        newGame.pot = 0; // Initialize the pot to 0
        newGame.highestBet = 0; // Initialize the highest bet to 0

        emit GameCreated(newGameId, msg.sender); // Emit the GameCreated event
        return newGameId; // Return the new game ID
    }

    // Function to join an existing game
    function joinGame(uint256 gameId) external nonReentrant {
        Game storage game = games[gameId]; // Get the game from storage
        require(game.state == GameState.WAITING, "Game not in waiting state"); // Ensure the game is in the WAITING state
        require(game.playerCount < MAX_PLAYERS, "Game is full"); // Ensure the game is not full

        // Add the player to the game
        game.players[game.playerCount] = Player({
            addr: msg.sender,
            chipCount: INITIAL_CHIP_COUNT,
            lastAction: PlayerAction.NONE,
            isActive: true,
            hasPlayerRole: true,
            hasCurrentTurnRole: false
        });
        game.playerCount++; // Increment the player count
        _grantRole(PLAYER_ROLE, msg.sender);

        emit PlayerJoined(gameId, msg.sender); // Emit the PlayerJoined event

        // If the game is full, start the game
        if (game.playerCount == MAX_PLAYERS) {
            startGame(gameId);
        }
    }

    // Function to request randomness from Chainlink VRF
    function requestRandomness(uint256 gameId) internal returns (uint256 requestId) {
        try COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        ) returns (uint256 _requestId) {
            vrfRequests[_requestId] = gameId;
            return _requestId;
        } catch Error(string memory reason) {
            emit VRFRequestFailed(gameId, reason);
            game.state = GameState.WAITING;  // Revert game state
        }
    }

    // Callback function used by VRF Coordinator
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 gameId = vrfRequests[requestId];
        uint256 randomness = randomWords[0];
        shuffleDeck(gameId, randomness);
        delete vrfRequests[requestId];
        continueGameSetup(gameId);
    }

    // Modified shuffleDeck function to use Chainlink VRF
    function shuffleDeck(uint256 gameId, uint256 randomness) internal {
        Deck storage deck = decks[gameId];
        for (uint8 i = 51; i > 0; i--) {
            // Use the provided randomness to generate a random index
            uint8 j = uint8(uint256(keccak256(abi.encodePacked(randomness, i))) % (i + 1));
            // Swap the current card with the randomly selected card
            Card memory temp = deck.cards[i];
            deck.cards[i] = deck.cards[j];
            deck.cards[j] = temp;
        }
        // Emit an event to signal that the deck has been shuffled
        emit DeckShuffled(gameId);
    }

    // Function to start the game
    function startGame(uint256 gameId) public onlyGameCreator(gameId) {
        Game storage game = games[gameId]; // Get the game from storage
        require(game.state == GameState.WAITING, "Game not in waiting state"); // Ensure the game is in the WAITING state
        require(game.playerCount >= 2, "Not enough players"); // Ensure there are at least 2 players

        initializeDeck(gameId);  // Initialize the deck
        game.state = GameState.SHUFFLING; // New state to indicate waiting for VRF
        requestRandomness(gameId);
        emit GameShuffling(gameId);
    }

    // New function to continue game setup after shuffling
    function continueGameSetup(uint256 gameId) internal {
        Game storage game = games[gameId];
        require(game.state == GameState.SHUFFLING, "Game not in shuffling state");

        game.state = GameState.ACTIVE;
        game.dealerIndex = 0;
        game.smallBlindIndex = (game.dealerIndex + 1) % game.playerCount;
        game.bigBlindIndex = (game.smallBlindIndex + 1) % game.playerCount;
        game.currentPlayerIndex = (game.bigBlindIndex + 1) % game.playerCount;

        address firstPlayer = game.players[game.currentPlayerIndex].addr;
        _grantRole(CURRENT_TURN_ROLE, firstPlayer);
        game.players[game.currentPlayerIndex].hasCurrentTurnRole = true;

        collectBlind(gameId, game.smallBlindIndex, 1);
        collectBlind(gameId, game.bigBlindIndex, 2);

        emit GameStarted(gameId);
        emit TurnChanged(gameId, game.players[game.currentPlayerIndex].addr);
    }

    // Internal function to collect blinds from a player
    function collectBlind(uint256 gameId, uint8 playerIndex, uint256 blindAmount) internal {
        Game storage game = games[gameId]; // Get the game from storage
        Player storage player = game.players[playerIndex]; // Get the player from the game

        require(player.chipCount >= blindAmount, "Player doesn't have enough chips for blind"); // Ensure the player has enough chips

        player.chipCount -= blindAmount; // Deduct the blind amount from the player's chip count
        game.pot += blindAmount; // Add the blind amount to the pot
        game.highestBet = (blindAmount > game.highestBet) ? blindAmount : game.highestBet; // Update the highest bet if necessary

        emit PlayerAction(gameId, player.addr, PlayerAction.CALL, blindAmount); // Emit the PlayerAction event
    }

    function grantPlayerRole(address player, uint256 gameId) internal {
        _grantRole(PLAYER_ROLE, player);
    }

    function revokePlayerRole(address player) internal {
        _revokeRole(PLAYER_ROLE, player);
    }

    function grantDealerRole(address dealer) internal {
        _grantRole(DEALER_ROLE, dealer);
    }

    // Function for a player to place a bet
    function placeBet(uint256 gameId, uint256 amount) external nonReentrant onlyRole(PLAYER_ROLE) {
        require(hasRole(PLAYER_ROLE, msg.sender), "Not a player in this game");
        require(hasRole(CURRENT_TURN_ROLE, msg.sender), "Not your turn");

        Game storage game = games[gameId]; // Get the game from storage
        require(game.state == GameState.ACTIVE, "Game not active"); // Ensure the game is in the ACTIVE state
        require(msg.sender == game.players[game.currentPlayerIndex].addr, "Not your turn"); // Ensure it is the player's turn

        Player storage currentPlayer = game.players[game.currentPlayerIndex]; // Get the current player
        require(currentPlayer.addr == msg.sender, "Player mismatch");
        require(currentPlayer.chipCount >= amount, "Not enough chips"); // Ensure the player has enough chips
        require(amount >= game.highestBet - getPlayerBet(gameId, msg.sender), "Bet too low"); // Ensure the bet is at least the highest bet

        currentPlayer.chipCount -= amount; // Deduct the bet amount from the player's chip count
        game.pot += amount; // Add the bet amount to the pot

        if (amount > game.highestBet) {
            game.highestBet = amount; // Update the highest bet if necessary
        }

        currentPlayer.lastAction = (amount > game.highestBet) ? PlayerAction.RAISE : PlayerAction.CALL; // Set the player's last action

        emit PlayerAction(gameId, msg.sender, currentPlayer.lastAction, amount); // Emit the PlayerAction event

        nextTurn(gameId); // Move to the next turn
    }

    // Function for a player to fold
    function fold(uint256 gameId) external {
        Game storage game = games[gameId]; // Get the game from storage
        require(game.state == GameState.ACTIVE, "Game not active"); // Ensure the game is in the ACTIVE state
        require(msg.sender == game.players[game.currentPlayerIndex].addr, "Not your turn"); // Ensure it is the player's turn

        Player storage currentPlayer = game.players[game.currentPlayerIndex]; // Get the current player
        currentPlayer.isActive = false; // Set the player as inactive
        currentPlayer.lastAction = PlayerAction.FOLD; // Set the player's last action to FOLD

        emit PlayerAction(gameId, msg.sender, PlayerAction.FOLD, 0); // Emit the PlayerAction event

        nextTurn(gameId); // Move to the next turn
    }

    // Internal function to move to the next turn
    function nextTurn(uint256 gameId) internal {
        Game storage game = games[gameId]; // Get the game from storage
            Player storage currentPlayer = game.players[game.currentPlayerIndex];

        _revokeRole(CURRENT_TURN_ROLE, currentPlayer.addr);
        currentPlayer.hasCurrentTurnRole = false;

        uint8 nextPlayerIndex = (game.currentPlayerIndex + 1) % game.playerCount; // Calculate the next player index

        while (!game.players[nextPlayerIndex].isActive) { // Find the next active player
            nextPlayerIndex = (nextPlayerIndex + 1) % game.playerCount;
        }

        game.currentPlayerIndex = nextPlayerIndex; // Set the current player index to the next active player
        Player storage nextPlayer = game.players[nextPlayerIndex];

        _grantRole(CURRENT_TURN_ROLE, nextPlayer.addr);
        nextPlayer.hasCurrentTurnRole = true;

        if (isRoundComplete(gameId)) {
            // Handle end of betting round logic here
            // This could involve dealing community cards, starting a new betting round, or ending the game
        }

        emit TurnChanged(gameId, game.players[game.currentPlayerIndex].addr); // Emit the TurnChanged event
    }

    // Internal function to check if the betting round is complete
    function isRoundComplete(uint256 gameId) internal view returns (bool) {
        Game storage game = games[gameId]; // Get the game from storage
        uint256 activePlayers = 0; // Count of active players
        uint256 playersActed = 0; // Count of players who have acted
        uint256 highestBet = 0; // Highest bet in the current round

        for (uint8 i = 0; i < game.playerCount; i++) { // Loop through all players
            Player storage player = game.players[i];
            if (player.isActive) {
                activePlayers++;
                if (player.lastAction != PlayerAction.NONE) {
                    playersActed++;
                }
                uint256 playerBet = getPlayerBet(gameId, player.addr);
                if (playerBet > highestBet) {
                    highestBet = playerBet;
                }
            }
        }

        return (activePlayers == playersActed) && (highestBet == game.highestBet); // Return true if all active players have acted and the highest bet is matched
    }

    // Internal function to get the total bet amount of a player
    function getPlayerBet(uint256 gameId, address playerAddress) internal view returns (uint256) {
        Game storage game = games[gameId]; // Get the game from storage
        for (uint8 i = 0; i < game.playerCount; i++) { // Loop through all players
            if (game.players[i].addr == playerAddress) {
                return INITIAL_CHIP_COUNT - game.players[i].chipCount; // Return the total bet amount
            }
        }
        revert("Player not found"); // Revert if the player is not found
    }

    function hasCurrentTurn(uint256 gameId, address player) public view returns (bool) {
        Game storage game = games[gameId];
        for (uint8 i = 0; i < game.playerCount; i++) {
            if (game.players[i].addr == player) {
                return game.players[i].hasCurrentTurnRole;
            }
        }
        return false;
    }
    function getCommunityCards(uint256 gameId) external view returns (Card[5] memory) {
        Game storage game = games[gameId];
        return [
            game.communityCards.flop1,
            game.communityCards.flop2,
            game.communityCards.flop3,
            game.communityCards.turn,
            game.communityCards.river
        ];
    }
    // Function for the dealer to commit community cards
    function commitCommunityCards(
        uint256 gameId, 
        bytes32 flop1, 
        bytes32 flop2, 
        bytes32 flop3, 
        bytes32 turn, 
        bytes32 river
    ) external onlyDealer(gameId) {
        Game storage game = games[gameId];
        require(game.state == GameState.ACTIVE, "Game not active");

        game.communityCards.flop1Commitment = flop1;
        game.communityCards.flop2Commitment = flop2;
        game.communityCards.flop3Commitment = flop3;
        game.communityCards.turnCommitment = turn;
        game.communityCards.riverCommitment = river;

        emit CardCommitted(gameId, "flop1", flop1);
        emit CardCommitted(gameId, "flop2", flop2);
        emit CardCommitted(gameId, "flop3", flop3);
        emit CardCommitted(gameId, "turn", turn);
        emit CardCommitted(gameId, "river", river);
    }

    // Function to reveal the flop
    function revealFlop(
        uint256 gameId, 
        uint8[3] memory ranks, 
        uint8[3] memory suits, 
        bytes[3] memory signatures
    ) external onlyDealer(gameId) {
        Game storage game = games[gameId];
        require(game.state == GameState.ACTIVE, "Game not active");
        require(!game.communityCards.flopRevealed, "Flop already revealed");
        game.state = GameState.REVEALING_COMMUNITY_CARDS;

        verifyAndSetCard(gameId, "flop1", ranks[0], suits[0], signatures[0]);
        verifyAndSetCard(gameId, "flop2", ranks[1], suits[1], signatures[1]);
        verifyAndSetCard(gameId, "flop3", ranks[2], suits[2], signatures[2]);
        require(game.communityCards.flop1Commitment != bytes32(0), "Flop not committed");

        game.communityCards.flopRevealed = true;
        game.state = GameState.ACTIVE;
    }

    // Function to reveal the turn
    function revealTurn(uint256 gameId, uint8 rank, uint8 suit, bytes memory signature) external onlyDealer(gameId) {
        Game storage game = games[gameId];
        require(game.state == GameState.ACTIVE, "Game not active");
        require(game.communityCards.flopRevealed, "Flop not yet revealed");
        require(!game.communityCards.turnRevealed, "Turn already revealed");


        verifyAndSetCard(gameId, "turn", rank, suit, signature);

        game.communityCards.turnRevealed = true;
    }

    // Function to reveal the river
    function revealRiver(uint256 gameId, uint8 rank, uint8 suit, bytes memory signature) external onlyDealer(gameId) {
        Game storage game = games[gameId];
        require(game.state == GameState.ACTIVE, "Game not active");
        require(game.communityCards.turnRevealed, "Turn not yet revealed");
        require(!game.communityCards.riverRevealed, "River already revealed");

        verifyAndSetCard(gameId, "river", rank, suit, signature);

        game.communityCards.riverRevealed = true;
    }

    // Internal function to verify and set a community card
    function verifyAndSetCard(uint256 gameId, string memory position, uint8 rank, uint8 suit, bytes memory signature) internal {
        Game storage game = games[gameId];
        bytes32 commitment;
        Card storage card;

        if (keccak256(abi.encodePacked(position)) == keccak256(abi.encodePacked("flop1"))) {
            commitment = game.communityCards.flop1Commitment;
            card = game.communityCards.flop1;
        } else if (keccak256(abi.encodePacked(position)) == keccak256(abi.encodePacked("flop2"))) {
            commitment = game.communityCards.flop2Commitment;
            card = game.communityCards.flop2;
        } else if (keccak256(abi.encodePacked(position)) == keccak256(abi.encodePacked("flop3"))) {
            commitment = game.communityCards.flop3Commitment;
            card = game.communityCards.flop3;
        } else if (keccak256(abi.encodePacked(position)) == keccak256(abi.encodePacked("turn"))) {
            commitment = game.communityCards.turnCommitment;
            card = game.communityCards.turn;
        } else if (keccak256(abi.encodePacked(position)) == keccak256(abi.encodePacked("river"))) {
            commitment = game.communityCards.riverCommitment;
            card = game.communityCards.river;
        } else {
            revert("Invalid position");
        }

        bytes32 hash = keccak256(abi.encodePacked(rank, suit));
        require(hash.toEthSignedMessageHash().recover(signature) == game.dealer, "Invalid signature");
        require(commitment == hash, "Commitment does not match revealed card");
        require(!revealedCards[cardHash], "Card already revealed");
        revealedCards[cardHash] = true;
        
        card.rank = rank;
        card.suit = suit;


        emit CardRevealed(gameId, position, rank, suit);
    }

    // Additional functions for game logic, hand evaluation, and game conclusion would be implemented here
}
