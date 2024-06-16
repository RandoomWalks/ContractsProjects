// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title Simple Decentralized Exchange (DEX)
 * @dev A simplified version of a DEX allowing users to swap between two tokens (TokenA and TokenB).
 */
contract SimpleDEX {
    using SafeMath for uint256;

    address public owner;
    IERC20 public tokenA;
    IERC20 public tokenB;
    uint256 public rateTokenAtoTokenB = 100; // Example rate: 1 TokenA = 100 TokenB
    uint256 public feePercentage; // Fee percentage, e.g., 1 means 1%
    bool public isPaused;

    bool private locked;

    event TokenSwap(address indexed user, uint256 amountA, uint256 amountB, bool fromAToB);
    event FeeCollected(address indexed user, uint256 amount);
    event TokenADeposited(address indexed user, uint256 amount);
    event TokenBDeposited(address indexed user, uint256 amount);
    event TokenAWithdrawn(address indexed user, uint256 amount);
    event TokenBWithdrawn(address indexed user, uint256 amount);
    event RateUpdated(uint256 newRate);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action.");
        _;
    }

    modifier noReentrant() {
        require(!locked, "Reentrant call detected.");
        locked = true;
        _;
        locked = false;
    }

    modifier whenNotPaused() {
        require(!isPaused, "Contract is paused.");
        _;
    }

    constructor(address _tokenA, address _tokenB, uint256 _feePercentage) {
        owner = msg.sender;
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        feePercentage = _feePercentage;
    }

    /**
     * @dev Allows the owner to set the exchange rate from TokenA to TokenB.
     * @param _rate New rate for swapping TokenA to TokenB.
     */
    function setRate(uint256 _rate) external onlyOwner {
        require(_rate > 0, "Rate must be greater than zero.");
        rateTokenAtoTokenB = _rate;
        emit RateUpdated(_rate);
    }

    /**
     * @dev Swaps an amount of TokenA held by the caller to TokenB according to the current rate.
     * The caller must have approved this contract to spend the relevant amount of TokenA.
     * @param _amount The amount of TokenA to swap for TokenB.
     */
    function swapTokenAForTokenB(uint256 _amount) external noReentrant whenNotPaused {
        require(_amount > 0, "Amount must be greater than zero.");

        uint256 tokenBAmountBeforeFee = _amount.mul(rateTokenAtoTokenB).div(10**18); // Adjust precision as needed
        uint256 feeAmount = tokenBAmountBeforeFee.mul(feePercentage).div(100);
        uint256 tokenBAmount = tokenBAmountBeforeFee.sub(feeAmount);

        require(tokenB.balanceOf(address(this)) >= tokenBAmount, "Not enough TokenB in DEX for the swap.");

        bool sentA = tokenA.transferFrom(msg.sender, address(this), _amount);
        require(sentA, "Failed to transfer TokenA from user to DEX.");

        bool sentB = tokenB.transfer(msg.sender, tokenBAmount);
        require(sentB, "Failed to transfer TokenB from DEX to user.");

        emit TokenSwap(msg.sender, _amount, tokenBAmount, true);
        emit FeeCollected(msg.sender, feeAmount);

        // Transfer fee to owner
        if (feeAmount > 0) {
            bool sentFee = tokenB.transfer(owner, feeAmount);
            require(sentFee, "Failed to transfer fee to owner.");
        }
    }

    /**
     * @dev Swaps an amount of TokenB held by the caller to TokenA according to the current rate.
     * The caller must have approved this contract to spend the relevant amount of TokenB.
     * @param _amount The amount of TokenB to swap for TokenA.
     */
    function swapTokenBForTokenA(uint256 _amount) external noReentrant whenNotPaused {
        require(_amount > 0, "Amount must be greater than zero.");

        uint256 tokenAAmount = _amount.mul(10**18).div(rateTokenAtoTokenB); // Adjust precision as needed
        require(tokenA.balanceOf(address(this)) >= tokenAAmount, "Not enough TokenA in DEX for the swap.");

        bool sentB = tokenB.transferFrom(msg.sender, address(this), _amount);
        require(sentB, "Failed to transfer TokenB from user to DEX.");

        bool sentA = tokenA.transfer(msg.sender, tokenAAmount);
        require(sentA, "Failed to transfer TokenA from DEX to user.");

        emit TokenSwap(msg.sender, _amount, tokenAAmount, false);
    }

    /**
     * @dev Allows the owner to withdraw any ERC20 tokens accidentally sent to this contract.
     * @param _token Address of the ERC20 token to withdraw.
     * @param _amount Amount of tokens to withdraw.
     */
    function withdrawToken(address _token, uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than zero.");
        IERC20 token = IERC20(_token);
        bool sent = token.transfer(owner, _amount);
        require(sent, "Failed to withdraw tokens.");
    }

    /**
     * @dev Allows the owner to withdraw any Ether accidentally sent to this contract.
     * This function is for safety in case Ether is sent directly to the contract address.
     */
    function withdrawEther(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than zero.");
        payable(owner).transfer(_amount);
    }

    /**
     * @dev Allows the owner to update the fee percentage.
     * @param _feePercentage New fee percentage, e.g., 1 means 1%.
     */
    function setFeePercentage(uint256 _feePercentage) external onlyOwner {
        require(_feePercentage >= 0  && _feePercentage <= 100, "Fee percentage must be between 0 and 100.");
        feePercentage = _feePercentage;
    }

    /**
     * @dev Allows users to deposit TokenA into the contract.
     * @param _amount The amount of TokenA to deposit.
     */
    function depositTokenA(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than zero.");
        bool sent = tokenA.transferFrom(msg.sender, address(this), _amount);
        require(sent, "Failed to deposit TokenA.");
        emit TokenADeposited(msg.sender, _amount);
    }

    /**
     * @dev Allows the owner to withdraw TokenA from the contract.
     * @param _amount The amount of TokenA to withdraw.
     */
    function withdrawTokenA(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than zero.");
        bool sent = tokenA.transfer(owner, _amount);
        require(sent, "Failed to withdraw TokenA.");
        emit TokenAWithdrawn(msg.sender, _amount);
    }

    /**
     * @dev Allows users to deposit TokenB into the contract.
     * @param _amount The amount of TokenB to deposit.
     */
    function depositTokenB(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than zero.");
        bool sent = tokenB.transferFrom(msg.sender, address(this), _amount);
        require(sent, "Failed to deposit TokenB.");
        emit TokenBDeposited(msg.sender, _amount);
    }

    /**
     * @dev Allows the owner to withdraw TokenB from the contract.
     * @param _amount The amount of TokenB to withdraw.
     */
    function withdrawTokenB(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than zero.");
        bool sent = tokenB.transfer(owner, _amount);
        require(sent, "Failed to withdraw TokenB.");
        emit TokenBWithdrawn(msg.sender, _amount);
    }

    /**
     * @dev Allows the owner to pause contract operations.
     * This function can be used in case of emergencies or maintenance.
     */
    function pause() external onlyOwner {
        isPaused = true;
    }

    /**
     * @dev Allows the owner to resume contract operations.
     */
    function resume() external onlyOwner {
        isPaused = false;
    }

    /**
     * @dev Allows the owner to withdraw any Ether accidentally sent to this contract.
     * This function is for safety in case Ether is sent directly to the contract address.
     * @param _amount The amount of Ether to withdraw.
     */
    function withdrawEther(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than zero.");
        payable(owner).transfer(_amount);
    }

    /**
     * @dev Allows the owner to update the fee percentage.
     * @param _feePercentage New fee percentage, e.g., 1 means 1%.
     */
    function setFeePercentage(uint256 _feePercentage) external onlyOwner {
        require(_feePercentage >= 0 && _feePercentage <= 100, "Fee percentage must be between 0 and 100.");
        feePercentage = _feePercentage;
    }
}

