// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SimpleDEX is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;
    uint256 public rateTokenAtoTokenB;
    uint256 public feePercentage;
    bool public isPaused;
    bool public emergencyStop;
    uint256 public slippageTolerance;
    uint256 public minSwapAmount;
    uint256 public maxSwapAmount;

    mapping(address => bool) public whitelistedTokens;

    event TokenSwap(address indexed user, uint256 amountA, uint256 amountB, bool fromAToB);
    event FeeCollected(address indexed user, uint256 amount);
    event RateUpdated(uint256 newRate);
    event EmergencyStopActivated();
    event EmergencyStopDeactivated();
    event TokenWhitelisted(address indexed token);
    event TokenRemovedFromWhitelist(address indexed token);

    constructor(address _tokenA, address _tokenB, uint256 _rateTokenAtoTokenB, uint256 _feePercentage) {
        require(_tokenA != address(0) && _tokenB != address(0), "Invalid token addresses");
        require(_rateTokenAtoTokenB > 0, "Rate must be greater than zero");
        require(_feePercentage <= 10000, "Fee percentage must be between 0 and 100");

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        rateTokenAtoTokenB = _rateTokenAtoTokenB;
        feePercentage = _feePercentage;
        slippageTolerance = 50; // 0.5%
        minSwapAmount = 1e18; // 1 token
        maxSwapAmount = 1e24; // 1,000,000 tokens
        whitelistedTokens[_tokenA] = true;
        whitelistedTokens[_tokenB] = true;
    }

    function setRate(uint256 _rate) external onlyOwner {
        require(_rate > 0, "Rate must be greater than zero");
        rateTokenAtoTokenB = _rate;
        emit RateUpdated(_rate);
    }

    function swapTokenAForTokenB(uint256 _amount) external nonReentrant whenNotPaused whenNotEmergencyStopped {
        require(_amount >= minSwapAmount && _amount <= maxSwapAmount, "Swap amount out of range");
        require(whitelistedTokens[address(tokenA)] && whitelistedTokens[address(tokenB)], "Tokens are not whitelisted");

        uint256 tokenBAmount = (_amount * rateTokenAtoTokenB) / 1e18;
        uint256 feeAmount = (tokenBAmount * feePercentage) / 10000;
        uint256 tokenBAmountAfterFee = tokenBAmount - feeAmount;

        uint256 minTokenBAmount = (tokenBAmountAfterFee * (10000 - slippageTolerance)) / 10000;

        tokenA.safeTransferFrom(msg.sender, address(this), _amount);
        tokenB.safeTransfer(msg.sender, tokenBAmountAfterFee);

        emit TokenSwap(msg.sender, _amount, tokenBAmountAfterFee, true);
        emit FeeCollected(msg.sender, feeAmount);

        if (feeAmount > 0) {
            tokenB.safeTransfer(owner(), feeAmount);
        }

        require(tokenB.balanceOf(msg.sender) >= minTokenBAmount, "Slippage tolerance exceeded");
    }

    function swapTokenBForTokenA(uint256 _amount) external nonReentrant whenNotPaused whenNotEmergencyStopped {
        require(_amount >= minSwapAmount && _amount <= maxSwapAmount, "Swap amount out of range");
        require(whitelistedTokens[address(tokenA)] && whitelistedTokens[address(tokenB)], "Tokens are not whitelisted");

        uint256 tokenAAmount = (_amount * 1e18) / rateTokenAtoTokenB;
        uint256 minTokenAAmount = (tokenAAmount * (10000 - slippageTolerance)) / 10000;

        tokenB.safeTransferFrom(msg.sender, address(this), _amount);
        tokenA.safeTransfer(msg.sender, tokenAAmount);

        emit TokenSwap(msg.sender, _amount, tokenAAmount, false);

        require(tokenA.balanceOf(msg.sender) >= minTokenAAmount, "Slippage tolerance exceeded");
    }

    function setFeePercentage(uint256 _feePercentage) external onlyOwner {
        require(_feePercentage <= 10000, "Fee percentage must be between 0 and 100");
        feePercentage = _feePercentage;
    }

    function setSlippageTolerance(uint256 _slippageTolerance) external onlyOwner {
        require(_slippageTolerance <= 10000, "Slippage tolerance must be between 0 and 100");
        slippageTolerance = _slippageTolerance;
    }

    function setMinSwapAmount(uint256 _minSwapAmount) external onlyOwner {
        minSwapAmount = _minSwapAmount;
    }

    function setMaxSwapAmount(uint256 _maxSwapAmount) external onlyOwner {
        maxSwapAmount = _maxSwapAmount;
    }

    function pause() external onlyOwner {
        isPaused = true;
    }

    function resume() external onlyOwner {
        isPaused = false;
    }

    function toggleEmergencyStop() external onlyOwner {
        emergencyStop = !emergencyStop;
        if (emergencyStop) {
            emit EmergencyStopActivated();
        } else {
            emit EmergencyStopDeactivated();
        }
    }

    function addWhitelistedToken(address _token) external onlyOwner {
        require(_token != address(0), "Invalid token address");
        whitelistedTokens[_token] = true;
        emit TokenWhitelisted(_token);
    }

    function removeWhitelistedToken(address _token) external onlyOwner {
        require(_token != address(0), "Invalid token address");
        whitelistedTokens[_token] = false;
        emit TokenRemovedFromWhitelist(_token);
    }

    function withdrawTokens(address _token, uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than zero");
        IERC20(_token).safeTransfer(owner(), _amount);
    }

    function withdrawEther(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than zero");
        payable(owner()).transfer(_amount);
    }

    modifier whenNotPaused() {
        require(!isPaused, "Contract is paused");
        _;
    }

    modifier whenNotEmergencyStopped() {
        require(!emergencyStop, "Emergency stop is activated");
        _;
    }
}