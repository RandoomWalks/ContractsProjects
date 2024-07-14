// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Importing necessary contracts and libraries from OpenZeppelin and LitProtocol
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@litprotocol/contracts/LitAccessControl.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// Main contract for managing a poker game
contract PokerGame is ERC721, ReentrancyGuard, LitAccessControl, VRFConsumerBaseV2 {
    using Counters for Counters.Counter; // Using Counters for managing unique game IDs

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

    // Note: The callbackGasLimit may need to be adjusted based on the complexity of your shuffleDeck function
    uint32 callbackGasLimit = 200000;

    bytes32 public constant PLAYER_ROLE = keccak256("PLAYER_ROLE");
    bytes32 public constant CURRENT_TURN_ROLE = keccak256("CURRENT_TURN_ROLE");
    bytes32 public constant DEALER_ROLE = keccak256("DEALER_ROLE");

    uint8 constant MAX_PLAYERS = 6; // Maximum number of players per game
    uint256 constant INITIAL_CHIP_COUNT = 1000; // Initial chip count for each player

    // Enum representing the possible states of the game
    enum GameState { WAITING, SHUFFLING, ACTIVE, FINISHED }

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

    modifier onlyGameCreator(uint256 gameId) {
        require(games[gameId].creator == msg.sender, "Only game creator can start the game");
        _;
    }

    constructor(uint64 subscriptionId) ERC721("PokerGame", "PKR")
        VRFConsumerBaseV2(0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D) // VRF Coordinator address (Sepolia)
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        COORDINATOR = VRFCoordinatorV2Interface(0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D);
        s_subscriptionId = subscriptionId;
        keyHash = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c; // Sepolia key hash
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

    // Additional functions for game logic, hand evaluation, and game conclusion would be implemented here
}
