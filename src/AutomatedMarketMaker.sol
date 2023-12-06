// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {PropertyToken} from "./PropertyToken.sol";

contract AutomatedMarketMaker {
    // Error messages
    error AutomatedMarketMaker__InvalidAmount(uint256 amount);
    error AutomatedMarketMaker__InsufficientEth(uint256 amount);
    error AutomatedMarketMaker__InsufficientTokens(uint256 amount);
    error AutomatedMarketMaker__InvalidLiquidity(uint256 tokens, uint256 ethAmount);
    error AutomatedMarketMaker__SharesNotGreaterThanZero(uint256 shares);
    error AutomatedMarketMaker__AmountToWithdrawNotGreaterThanZero(uint256 amountTokens, uint256 amountEth);
    error AutomatedMarketMaker__NotEnoughShares(uint256 shares);
    error AutomatedMarketMaker__PoolAlreadyExists(address propertyTokenAddress);
    error AutomatedMarketMaker__PoolDoesNotExist(address propertyTokenAddress);

    struct Pool {
        PropertyToken propertyToken;
        uint256 reservePropertyToken;
        uint256 reserveEth;
    }

    mapping(address => Pool) public pools;
    mapping(address => mapping(address => uint256)) public balanceOf;
    mapping(address => uint256) public totalSupply;

    constructor() {}

    function createPool(address _propertyTokenAddress) external {
        if (address(pools[_propertyTokenAddress].propertyToken) != address(0)) {
            revert AutomatedMarketMaker__PoolAlreadyExists(_propertyTokenAddress);
        }
        PropertyToken pt = PropertyToken(_propertyTokenAddress);
        pools[_propertyTokenAddress] = Pool(pt, 0, 0);
    }

    function swapTokensForEth(address _propertyTokenAddress, uint256 _amount)
        external
        payable
        returns (uint256 amountOut)
    {
        Pool storage pool = pools[_propertyTokenAddress];
        if (address(pool.propertyToken) == address(0)) {
            revert AutomatedMarketMaker__PoolDoesNotExist(_propertyTokenAddress);
        }

        if (_amount <= 0) {
            revert AutomatedMarketMaker__InvalidAmount(_amount);
        }

        // pull in tokens from the sender
        bool transferSuccesful = pool.propertyToken.transferFrom(msg.sender, address(this), _amount);
        if (!transferSuccesful) {
            revert AutomatedMarketMaker__InsufficientTokens(_amount);
        }

        // calculate the amount of eth to send back to the sender include a 1% fee
        uint256 amountInMinusFee = (_amount * 990) / 1000;

        amountOut = (pool.reserveEth * amountInMinusFee) / (pool.reservePropertyToken + amountInMinusFee);
        payable(msg.sender).transfer(amountOut);

        uint256 poolEthBalance = pool.reserveEth - amountOut;

        // update the reserves
        _updateReserves(_propertyTokenAddress, pool.propertyToken.balanceOf(address(this)), poolEthBalance);
    }

    function swapEthForTokens(address _propertyTokenAddress) external payable returns (uint256 amountOut) {
        Pool storage pool = pools[_propertyTokenAddress];
        if (address(pool.propertyToken) == address(0)) {
            revert AutomatedMarketMaker__PoolDoesNotExist(_propertyTokenAddress);
        }

        if (msg.value <= 0) {
            revert AutomatedMarketMaker__InvalidAmount(msg.value);
        }

        // pull eth from the sender
        // payable(address(this)).transfer(msg.value);

        uint256 amountInMinusFee = (msg.value * 990) / 1000;

        amountOut = (pool.reservePropertyToken * amountInMinusFee) / (pool.reserveEth + amountInMinusFee);

        // transfer tokens to the sender
        pool.propertyToken.transfer(msg.sender, amountOut);

        uint256 poolEthBalance = pool.reserveEth + msg.value;

        // update the reserves
        _updateReserves(_propertyTokenAddress, pool.propertyToken.balanceOf(address(this)), poolEthBalance);
    }

    function addLiquidity(address _propertyTokenAddress, uint256 _amountTokens)
        external
        payable
        returns (uint256 shares)
    {
        Pool storage pool = pools[_propertyTokenAddress];
        if (address(pool.propertyToken) == address(0)) {
            revert AutomatedMarketMaker__PoolDoesNotExist(_propertyTokenAddress);
        }

        if (pool.reserveEth > 0 || pool.reservePropertyToken > 0) {
            if (pool.reserveEth * _amountTokens != pool.reservePropertyToken * msg.value) {
                revert AutomatedMarketMaker__InvalidLiquidity(_amountTokens, msg.value);
            }
        }
        // pull in tokens and eth from the sender
        bool transferSuccesful = pool.propertyToken.transferFrom(msg.sender, address(this), _amountTokens);
        if (!transferSuccesful) {
            revert AutomatedMarketMaker__InsufficientTokens(_amountTokens);
        }
        // payable(address(this)).transfer(msg.value);

        // mint shares
        // f(x, y) = value of liquidity = sqrt(x * y)
        if (totalSupply[_propertyTokenAddress] == 0) {
            shares = _sqrt(_amountTokens * msg.value);
        } else {
            shares = _min(
                _amountTokens * totalSupply[_propertyTokenAddress] / pool.propertyToken.balanceOf(address(this)),
                msg.value * totalSupply[_propertyTokenAddress] / pool.reserveEth
            );
        }

        if (shares <= 0) {
            revert AutomatedMarketMaker__SharesNotGreaterThanZero(shares);
        }
        _mint(_propertyTokenAddress, msg.sender, shares);

        uint256 poolEthBalance = pool.reserveEth + msg.value;

        // update the reserves
        _updateReserves(_propertyTokenAddress, pool.propertyToken.balanceOf(address(this)), poolEthBalance);
    }

    function removeLiquidity(address _propertyTokenAddress, uint256 _shares)
        external
        payable
        returns (uint256 amountTokens, uint256 amountEth)
    {
        if (_shares <= 0) {
            revert AutomatedMarketMaker__SharesNotGreaterThanZero(_shares);
        }

        Pool storage pool = pools[_propertyTokenAddress];
        if (address(pool.propertyToken) == address(0)) {
            revert AutomatedMarketMaker__PoolDoesNotExist(_propertyTokenAddress);
        }

        // check if the sender has enough shares
        if (balanceOf[_propertyTokenAddress][msg.sender] < _shares) {
            revert AutomatedMarketMaker__NotEnoughShares(_shares);
        }

        uint256 balToken = pool.propertyToken.balanceOf(address(this));
        uint256 balEth = pool.reserveEth;

        amountTokens = (_shares * balToken) / totalSupply[_propertyTokenAddress];
        amountEth = (_shares * balEth) / totalSupply[_propertyTokenAddress];

        if (amountTokens <= 0 || amountEth <= 0) {
            revert AutomatedMarketMaker__AmountToWithdrawNotGreaterThanZero(amountTokens, amountEth);
        }

        // transfer tokens and eth to the sender
        pool.propertyToken.transfer(msg.sender, amountTokens);
        payable(msg.sender).transfer(amountEth);

        // burn shares
        _burn(_propertyTokenAddress, msg.sender, _shares);

        uint256 poolEthBalance = pool.reserveEth - amountEth;

        // update the reserves
        _updateReserves(_propertyTokenAddress, pool.propertyToken.balanceOf(address(this)), poolEthBalance);
    }

    // function that takes in a token amount and returns the equivalent amount of eth
    function getEstimatedEthForTokens(address _propertyTokenAddress, uint256 _amountTokens)
        external
        view
        returns (uint256 amountEth)
    {
        if (_amountTokens <= 0) {
            revert AutomatedMarketMaker__InvalidAmount(_amountTokens);
        }

        Pool storage pool = pools[_propertyTokenAddress];
        if (address(pool.propertyToken) == address(0)) {
            revert AutomatedMarketMaker__PoolDoesNotExist(_propertyTokenAddress);
        }

        uint256 amountInMinusFee = (_amountTokens * 990) / 1000;
        amountEth = (pool.reserveEth * amountInMinusFee) / (pool.reservePropertyToken + amountInMinusFee);
    }

    // function that takes in an eth amount and returns the equivalent amount of tokens
    function getEstimatedTokensForEth(address _propertyTokenAddress, uint256 _amountEth)
        external
        view
        returns (uint256 amountTokens)
    {
        if (_amountEth <= 0) {
            revert AutomatedMarketMaker__InvalidAmount(_amountEth);
        }

        Pool storage pool = pools[_propertyTokenAddress];
        if (address(pool.propertyToken) == address(0)) {
            revert AutomatedMarketMaker__PoolDoesNotExist(_propertyTokenAddress);
        }

        uint256 amountInMinusFee = (_amountEth * 990) / 1000;
        amountTokens = (pool.reservePropertyToken * amountInMinusFee) / (pool.reserveEth + amountInMinusFee);
    }

    function _updateReserves(address _propertyTokenAddress, uint256 _tokenReserve, uint256 _ethReserve) private {
        pools[_propertyTokenAddress].reserveEth = _ethReserve;
        pools[_propertyTokenAddress].reservePropertyToken = _tokenReserve;
    }

    function _mint(address _propertyTokenAddress, address _to, uint256 _amount) private {
        totalSupply[_propertyTokenAddress] += _amount;
        balanceOf[_propertyTokenAddress][_to] += _amount;
    }

    function _burn(address _propertyTokenAddress, address _from, uint256 _amount) private {
        totalSupply[_propertyTokenAddress] -= _amount;
        balanceOf[_propertyTokenAddress][_from] -= _amount;
    }

    function _sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x > y ? y : x;
    }
}
