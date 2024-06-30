// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import the IERC20 interface and SafeERC20 library from OpenZeppelin
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// Import the ReentrancyGuard contract from OpenZeppelin for reentrancy protection
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// Import the Ownable contract from OpenZeppelin for access control
import "@openzeppelin/contracts/access/Ownable.sol";

// SimpleDEX contract inherits from ReentrancyGuard and Ownable contracts
contract SimpleDEX is ReentrancyGuard, Ownable {
    // Use SafeERC20 for safe token transfers and approvals
    using SafeERC20 for IERC20;

    // Immutable variables for token addresses to save gas on storage reads
    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;

    // Exchange rate from tokenA to tokenB
    uint256 public rateTokenAtoTokenB;
    // Fee percentage for token swaps (in basis points, where 10000 = 100%)
    uint256 public feePercentage;
    // Flag to indicate if the contract is paused
    bool public isPaused;
    // Flag to indicate if the emergency stop is activated
    bool public emergencyStop;
    // Slippage tolerance for token swaps (in basis points, where 10000 = 100%)
    uint256 public slippageTolerance;
    // Minimum swap amount allowed
    uint256 public minSwapAmount;
    // Maximum swap amount allowed
    uint256 public maxSwapAmount;

    // Mapping to store whitelisted tokens
    mapping(address => bool) public whitelistedTokens;

    // Event emitted when a token swap occurs
    event TokenSwap(address indexed user, uint256 amountA, uint256 amountB, bool fromAToB);
    // Event emitted when a fee is collected
    event FeeCollected(address indexed user, uint256 amount);
    // Event emitted when the exchange rate is updated
    event RateUpdated(uint256 newRate);
    // Event emitted when the emergency stop is activated
    event EmergencyStopActivated();
    // Event emitted when the emergency stop is deactivated
    event EmergencyStopDeactivated();
    // Event emitted when a token is whitelisted
    event TokenWhitelisted(address indexed token);
    // Event emitted when a token is removed from the whitelist
    event TokenRemovedFromWhitelist(address indexed token);

    // Constructor function to initialize the contract
    constructor(address _tokenA, address _tokenB, uint256 _rateTokenAtoTokenB, uint256 _feePercentage) {
        // Ensure valid token addresses are provided
        require(_tokenA != address(0) && _tokenB != address(0), "Invalid token addresses");
        // Ensure the exchange rate is greater than zero
        require(_rateTokenAtoTokenB > 0, "Rate must be greater than zero");
        // Ensure the fee percentage is between 0 and 100 (inclusive)
        require(_feePercentage <= 10000, "Fee percentage must be between 0 and 100");

        // Set the token addresses
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        // Set the initial exchange rate
        rateTokenAtoTokenB = _rateTokenAtoTokenB;
        // Set the initial fee percentage
        feePercentage = _feePercentage;
        // Set the default slippage tolerance to 0.5%
        slippageTolerance = 50;
        // Set the default minimum swap amount to 1 token
        minSwapAmount = 1e18;
        // Set the default maximum swap amount to 1,000,000 tokens
        maxSwapAmount = 1e24;
        // Whitelist the initial tokens
        whitelistedTokens[_tokenA] = true;
        whitelistedTokens[_tokenB] = true;
    }

    // Function to set the exchange rate (only callable by the contract owner)
    function setRate(uint256 _rate) external onlyOwner {
        // Ensure the new rate is greater than zero
        require(_rate > 0, "Rate must be greater than zero");
        // Update the exchange rate
        rateTokenAtoTokenB = _rate;
        // Emit an event indicating the rate update
        emit RateUpdated(_rate);
    }

    // Function to swap tokenA for tokenB
    function swapTokenAForTokenB(uint256 _amount) external nonReentrant whenNotPaused whenNotEmergencyStopped {
        // Ensure the swap amount is within the allowed range
        require(_amount >= minSwapAmount && _amount <= maxSwapAmount, "Swap amount out of range");
        // Ensure both tokens are whitelisted
        require(whitelistedTokens[address(tokenA)] && whitelistedTokens[address(tokenB)], "Tokens are not whitelisted");

        // Calculate the amount of tokenB to receive based on the exchange rate
        uint256 tokenBAmount = (_amount * rateTokenAtoTokenB) / 1e18;
        // Calculate the fee amount
        uint256 feeAmount = (tokenBAmount * feePercentage) / 10000;
        // Calculate the amount of tokenB after deducting the fee
        uint256 tokenBAmountAfterFee = tokenBAmount - feeAmount;

        // Calculate the minimum amount of tokenB expected based on the slippage tolerance
        uint256 minTokenBAmount = (tokenBAmountAfterFee * (10000 - slippageTolerance)) / 10000;

        // Transfer tokenA from the user to the contract
        tokenA.safeTransferFrom(msg.sender, address(this), _amount);
        // Transfer tokenB from the contract to the user
        tokenB.safeTransfer(msg.sender, tokenBAmountAfterFee);

        // Emit events for the token swap and fee collection
        emit TokenSwap(msg.sender, _amount, tokenBAmountAfterFee, true);
        emit FeeCollected(msg.sender, feeAmount);

        // If a fee was collected, transfer it to the contract owner
        if (feeAmount > 0) {
            tokenB.safeTransfer(owner(), feeAmount);
        }

        // Ensure the received amount of tokenB is within the slippage tolerance
        require(tokenB.balanceOf(msg.sender) >= minTokenBAmount, "Slippage tolerance exceeded");
    }

    // Function to swap tokenB for tokenA
    function swapTokenBForTokenA(uint256 _amount) external nonReentrant whenNotPaused whenNotEmergencyStopped {
        // Ensure the swap amount is within the allowed range
        require(_amount >= minSwapAmount && _amount <= maxSwapAmount, "Swap amount out of range");
        // Ensure both tokens are whitelisted
        require(whitelistedTokens[address(tokenA)] && whitelistedTokens[address(tokenB)], "Tokens are not whitelisted");

        // Calculate the amount of tokenA to receive based on the exchange rate
        uint256 tokenAAmount = (_amount * 1e18) / rateTokenAtoTokenB;
        // Calculate the minimum amount of tokenA expected based on the slippage tolerance
        uint256 minTokenAAmount = (tokenAAmount * (10000 - slippageTolerance)) / 10000;

        // Transfer tokenB from the user to the contract
        tokenB.safeTransferFrom(msg.sender, address(this), _amount);
        // Transfer tokenA from the contract to the user
        tokenA.safeTransfer(msg.sender, tokenAAmount);

        // Emit an event for the token swap
        emit TokenSwap(msg.sender, _amount, tokenAAmount, false);

        // Ensure the received amount of tokenA is within the slippage tolerance
        require(tokenA.balanceOf(msg.sender) >= minTokenAAmount, "Slippage tolerance exceeded");
    }

    // Function to set the fee percentage (only callable by the contract owner)
    function setFeePercentage(uint256 _feePercentage) external onlyOwner {
        // Ensure the fee percentage is between 0 and 100 (inclusive)
        require(_feePercentage <= 10000, "Fee percentage must be between 0 and 100");
        // Update the fee percentage
        feePercentage = _feePercentage;
    }

    // Function to set the slippage tolerance (only callable by the contract owner)
    function setSlippageTolerance(uint256 _slippageTolerance) external onlyOwner {
        // Ensure the slippage tolerance is between 0 and 100 (inclusive)
        require(_slippageTolerance <= 10000, "Slippage tolerance must be between 0 and 100");
        // Update the slippage tolerance
        slippageTolerance = _slippageTolerance;
    }

    // Function to set the minimum swap amount (only callable by the contract owner)
    function setMinSwapAmount(uint256 _minSwapAmount) external onlyOwner {
        // Update the minimum swap amount
        minSwapAmount = _minSwapAmount;
    }

    // Function to set the maximum swap amount (only callable by the contract owner)
    function setMaxSwapAmount(uint256 _maxSwapAmount) external onlyOwner {
        // Update the maximum swap amount
        maxSwapAmount = _maxSwapAmount;
    }

    // Function to pause the contract (only callable by the contract owner)
    function pause() external onlyOwner {
        // Set the pause flag to true
        isPaused = true;
    }

    // Function to resume the contract (only callable by the contract owner)
    function resume() external onlyOwner {
        // Set the pause flag to false
        isPaused = false;
    }

    // Function to toggle the emergency stop (only callable by the contract owner)
    function toggleEmergencyStop() external onlyOwner {
        // Toggle the emergency stop flag
        emergencyStop = !emergencyStop;
        // Emit the appropriate event based on the emergency stop state
        if (emergencyStop) {
            emit EmergencyStopActivated();
        } else {
            emit EmergencyStopDeactivated();
        }
    }

    // Function to add a token to the whitelist (only callable by the contract owner)
    function addWhitelistedToken(address _token) external onlyOwner {
        // Ensure a valid token address is provided
        require(_token != address(0), "Invalid token address");
        // Add the token to the whitelist
        whitelistedTokens[_token] = true;
        // Emit an event indicating the token whitelisting
        emit TokenWhitelisted(_token);
    }

    // Function to remove a token from the whitelist (only callable by the contract owner)
    function removeWhitelistedToken(address _token) external onlyOwner {
        // Ensure a valid token address is provided
        require(_token != address(0), "Invalid token address");
        // Remove the token from the whitelist
        whitelistedTokens[_token] = false;
        // Emit an event indicating the token removal from the whitelist
        emit TokenRemovedFromWhitelist(_token);
    }

    // Function to withdraw tokens from the contract (only callable by the contract owner)
    function withdrawTokens(address _token, uint256 _amount) external onlyOwner {
        // Ensure the withdrawal amount is greater than zero
        require(_amount > 0, "Amount must be greater than zero");
        // Transfer the specified amount of tokens to the contract owner
        IERC20(_token).safeTransfer(owner(), _amount);
    }

    // Function to withdraw Ether from the contract (only callable by the contract owner)
    function withdrawEther(uint256 _amount) external onlyOwner {
        // Ensure the withdrawal amount is greater than zero
        require(_amount > 0, "Amount must be greater than zero");
        // Transfer the specified amount of Ether to the contract owner
        payable(owner()).transfer(_amount);
    }

    // Modifier to check if the contract is not paused
    modifier whenNotPaused() {
        // Require that the contract is not paused
        require(!isPaused, "Contract is paused");
        // Continue with the function execution
        _;
    }

    // Modifier to check if the emergency stop is not activated
    modifier whenNotEmergencyStopped() {
        // Require that the emergency stop is not activated
        require(!emergencyStop, "Emergency stop is activated");
        // Continue with the function execution
        _;
    }
}