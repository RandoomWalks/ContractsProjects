// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Simple Decentralized Exchange (DEX)
 * @dev A simplified version of a DEX allowing users to swap between two tokens (TokenA and TokenB).
 */
contract SimpleDEX {
    address public owner;
    IERC20 public tokenA;
    IERC20 public tokenB;
    uint public rateTokenAtoTokenB = 100; // Example rate: 1 TokenA = 100 TokenB

    constructor(address _tokenA, address _tokenB) {
        owner = msg.sender;
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action.");
        _;
    }

    /**
     * @dev Allows the owner to set the exchange rate from TokenA to TokenB.
     * @param _rate New rate for swapping TokenA to TokenB.
     */
    function setRate(uint _rate) public onlyOwner {
        require(_rate > 0, "Rate must be greater than 0.");
        rateTokenAtoTokenB = _rate;
    }

    /**
     * @dev Swaps an amount of TokenA held by the caller to TokenB according to the current rate.
     * The caller must have approved this contract to spend the relevant amount of TokenA.
     * @param _amount The amount of TokenA to swap for TokenB.
     */
    function swapTokenAForTokenB(uint _amount) public {
        require(_amount > 0, "Amount must be greater than 0.");
        uint tokenBAmount = _amount * rateTokenAtoTokenB;
        require(tokenB.balanceOf(address(this)) >= tokenBAmount, "Not enough TokenB in DEX for the swap.");

        bool sentA = tokenA.transferFrom(msg.sender, address(this), _amount);
        require(sentA, "Failed to transfer TokenA from user to DEX.");
        
        bool sentB = tokenB.transfer(msg.sender, tokenBAmount);
        require(sentB, "Failed to transfer TokenB from DEX to user.");
    }

    /**
     * @dev Swaps an amount of TokenB held by the caller to TokenA according to the current rate.
     * The caller must have approved this contract to spend the relevant amount of TokenB.
     * @param _amount The amount of TokenB to swap for TokenA.
     */
    function swapTokenBForTokenA(uint _amount) public {
        require(_amount > 0, "Amount must be greater than 0.");
        uint tokenAAmount = _amount / rateTokenAtoTokenB;
        require(tokenA.balanceOf(address(this)) >= tokenAAmount, "Not enough TokenA in DEX for the swap.");

        bool sentB = tokenB.transferFrom(msg.sender, address(this), _amount);
        require(sentB, "Failed to transfer TokenB from user to DEX.");
        
        bool sentA = tokenA.transfer(msg.sender, tokenAAmount);
        require(sentA, "Failed to transfer TokenA from DEX to user.");
    }
}

// Simplified ERC20 interface
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}
