// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/security/Pausable.sol";
import "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract GCoin is ERC20, Ownable, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    uint256 public mintingFee = 10; // 0.10% fee
    uint256 public redemptionFee = 100; // 1.00% fee
    uint256 public gcoinValue;

    AggregatorV3Interface public gcoinPriceFeed;
    mapping(address => ERC20) public stableCoins;

    address public treasury;

    event PriceUpdatedManual(uint256 newprice);
    event Paused();
    event Unpaused();

    constructor() ERC20("GCoin", "GC") {
        gcoinValue = 1e18; // Initial value set to 1 stable coin
    }

    function addStableCoin(address token) public onlyOwner {
        stableCoins[token] = ERC20(token);
    }

    /*
    Use for chainlink with pricefeed for greenindex
     */
    function setGCoinPriceFeed(address priceFeed) public onlyOwner {
        gcoinPriceFeed = AggregatorV3Interface(priceFeed);
    }

    function setTreasury(address _treasury) public onlyOwner {
        treasury = _treasury;
    }

    function getLatestPrice() private view returns (uint256) {
        require(
            address(gcoinPriceFeed) != address(0),
            "GCoin price feed not set"
        );
        (, int256 price, , , ) = gcoinPriceFeed.latestRoundData();
        return uint256(price);
    }

    function getGCoinOutputFromStable(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        uint256 gcoinAmount = amount
            .mul(10 ** uint256(decimals()))
            .div(10 ** uint256(stableCoins[token].decimals()))
            .mul(10 ** uint256(decimals()))
            .div(gcoinValue)
            .mul(10000 - mintingFee)
            .div(10000);
        return gcoinAmount;
    }

    function depositStableCoin(
        address token,
        uint256 amount
    ) public whenNotPaused {
        require(treasury != address(0), "Treasury address not set");
        require(
            address(stableCoins[token]) != address(0),
            "Stable coin not found"
        );
        require(
            stableCoins[token].allowance(msg.sender, address(this)) >= amount,
            "Amount not allowed"
        );

        uint256 gcoinAmount = getGCoinOutputFromStable(token, amount);

        uint256 initialTreasuryBalance = stableCoins[token].balanceOf(treasury);
        stableCoins[token].safeTransferFrom(msg.sender, treasury, amount);

        require(
            stableCoins[token].balanceOf(treasury) ==
                initialTreasuryBalance.add(amount),
            "Treasury balance did not increase correctly"
        );

        _mint(msg.sender, gcoinAmount);
    }

    /*
    how many stable coin (token) to return given amount of Gcoin
     */
    function getStableOutputFromGcoin(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        return
            amount
                .mul(10 ** uint256(stableCoins[token].decimals()))
                .div(10 ** uint256(decimals()))
                .mul(gcoinValue)
                .div(10 ** uint256(decimals()))
                .mul(10000 - redemptionFee)
                .div(10000);
    }

    function withdrawStableCoin(
        address token,
        uint256 amount
    ) public whenNotPaused {
        require(treasury != address(0), "Treasury address not set");
        require(
            address(stableCoins[token]) != address(0),
            "Stable coin not found"
        );
        _burn(msg.sender, amount);
        uint256 stableAmount = getStableOutputFromGcoin(token, amount);

        uint256 initialTreasuryBalance = stableCoins[token].balanceOf(treasury);
        stableCoins[token].safeTransferFrom(treasury, msg.sender, stableAmount);

        require(
            stableCoins[token].balanceOf(treasury) ==
                initialTreasuryBalance - stableAmount,
            "Treasury balance did not decrease correctly"
        );
    }

    function getGCoinValue() public view returns (uint256) {
        return gcoinValue;
    }

    function updateGCoinValue() public onlyOwner {
        uint256 chainlinkValue = getLatestPrice();
        gcoinValue = chainlinkValue;
    }

    function updateGCoinValueManual(uint256 manualValue) external onlyOwner {
        gcoinValue = manualValue;
        emit PriceUpdatedManual(manualValue);
    }

    function updateMintingFee(uint256 mintingFeeNew) external onlyOwner {
        mintingFee = mintingFeeNew;
    }

    function updateRedemptionFee(uint256 redemptionFeeNew) external onlyOwner {
        redemptionFee = redemptionFeeNew;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    function pause() external onlyOwner {
        _pause();
        emit Paused();
    }

    function unpause() external onlyOwner {
        _unpause();
        emit Unpaused();
    }
}
