// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/security/Pausable.sol";

contract GCoinStaking is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    ERC20 public gcoinToken;
    ERC20 public cgvToken;

    uint8 cgvDecimals;
    uint8 gcoinDecimals;

    // Base of 100, ie. 20% = 20
    uint256 public annualRewardRate;

    uint256 public MIN_STAKING_DURATION = 7 days;
    uint256 public MAX_STAKING_DURATION = 4 * 365 days;
    /*
    this scale 50 means 0.5, which means new_reward_rate = reward_rate + 0.5 * orig_reward_rate * time
    Total reward = new_reward_rate * time
    */
    uint256 public REWARD_SCALE = 50;

    struct Stake {
        uint256 amount;
        uint256 timestamp;
        uint256 duration;
        uint256 rewardMultiplier;
    }

    struct UserInfo {
        Stake[] stakes;
    }

    mapping(address => UserInfo) private userStakingInfo;
    EnumerableSet.AddressSet private userAddresses;

    // Events
    event Staked(address indexed user, uint256 amount, uint256 duration);
    event Withdrawn(address indexed user, uint256 amount, uint256 reward);
    event StakingPeriodUpdated(uint256 newStakingPeriod);
    event AnnualRewardRateUpdated(uint256 newAnnualRewardRate);
    event Paused();
    event Unpaused();

    constructor(
        address _gcoinToken,
        address _cgvToken,
        uint256 _annualRewardRate
    ) {
        gcoinToken = ERC20(_gcoinToken);
        cgvToken = ERC20(_cgvToken);
        annualRewardRate = _annualRewardRate;

        cgvDecimals = cgvToken.decimals();
        gcoinDecimals = gcoinToken.decimals();
    }

    // Users can stake GCoin tokens
    function stake(uint256 amount, uint256 duration) external whenNotPaused {
        require(
            duration >= MIN_STAKING_DURATION,
            "Staking duration is too short."
        );
        require(
            duration <= MAX_STAKING_DURATION,
            "Staking duration is too long."
        );

        uint256 rewardMultiplier = calculateRewardRate(duration);

        gcoinToken.safeTransferFrom(msg.sender, address(this), amount);
        UserInfo storage userInfo = userStakingInfo[msg.sender];
        userInfo.stakes.push(
            Stake({
                amount: amount,
                timestamp: block.timestamp,
                duration: duration,
                rewardMultiplier: rewardMultiplier
            })
        );
        userAddresses.add(msg.sender);
        emit Staked(msg.sender, amount, duration);
    }

    // Users can withdraw their matured stakes along with the rewards
    function withdrawAll() external nonReentrant whenNotPaused {
        UserInfo storage userInfo = userStakingInfo[msg.sender];
        uint256 totalAmount = 0;
        uint256 totalRewards = 0;
        uint256 i = 0;

        while (i < userInfo.stakes.length) {
            Stake storage currentStake = userInfo.stakes[i];
            uint256 stakedDuration = block.timestamp.sub(
                currentStake.timestamp
            );
            if (stakedDuration >= currentStake.duration) {
                uint256 reward = calculateReward(
                    currentStake.amount,
                    currentStake.duration
                );
                totalRewards = totalRewards.add(reward);
                totalAmount = totalAmount.add(currentStake.amount);

                userInfo.stakes[i] = userInfo.stakes[
                    userInfo.stakes.length - 1
                ];
                userInfo.stakes.pop();
            } else {
                i++;
            }
        }

        require(totalAmount > 0, "No staking rewards to claim.");
        require(
            cgvToken.balanceOf(address(this)) >= totalRewards,
            "Not enough CGV tokens to pay rewards. We are adding more. Please wait"
        );

        gcoinToken.safeTransfer(msg.sender, totalAmount);
        cgvToken.safeTransfer(msg.sender, totalRewards);

        emit Withdrawn(msg.sender, totalAmount, totalRewards);
    }

    // Users can withdraw their matured stakes along with the rewards
    function withdrawSpecific(
        uint256 index
    ) external nonReentrant whenNotPaused {
        UserInfo storage userInfo = userStakingInfo[msg.sender];

        Stake storage currentStake = userInfo.stakes[index];
        uint256 stakedDuration = block.timestamp.sub(currentStake.timestamp);
        if (stakedDuration >= currentStake.duration) {
            uint256 reward = calculateReward(
                currentStake.amount,
                currentStake.duration
            );
            require(
                cgvToken.balanceOf(address(this)) >= reward,
                "Not enough CGV tokens to pay rewards. We are adding more. Please wait"
            );

            gcoinToken.safeTransfer(msg.sender, currentStake.amount);
            cgvToken.safeTransfer(msg.sender, reward);

            userInfo.stakes[index] = userInfo.stakes[
                userInfo.stakes.length - 1
            ];
            userInfo.stakes.pop();
            emit Withdrawn(msg.sender, currentStake.amount, reward);
        }
    }

    /**
     * @dev Returns the quantity of CGV rewards for a given GCOIN amount and duration
     */
    function calculateReward(
        uint256 amount,
        uint256 duration
    ) public view returns (uint256) {
        return
            _convertDecimals(amount, gcoinDecimals, cgvDecimals)
                .mul(calculateRewardRate(duration))
                .mul(duration)
                .div(365 days)
                .div(100);
    }

    /**
     * @dev Returns the annual rate of CGV rewards for a given duration
     */
    function calculateRewardRate(
        uint256 duration
    ) public view returns (uint256) {
        return
            annualRewardRate +
            annualRewardRate.mul(REWARD_SCALE).mul(duration).div(365 days).div(
                100
            );
    }

    function getUserStakingInfoList(
        address user
    ) external view returns (UserInfo memory) {
        return userStakingInfo[user];
    }

    // Owner can update the staking period
    // function updateStakingPeriod(uint256 _stakingPeriod) external onlyOwner {
    //     stakingPeriod = _stakingPeriod;
    //     emit StakingPeriodUpdated(_stakingPeriod);
    // }

    /**
     * @dev Owner can update the annual reward rate
     */
    function updateAnnualRewardRate(
        uint256 _annualRewardRate
    ) external onlyOwner {
        annualRewardRate = _annualRewardRate;
        emit AnnualRewardRateUpdated(_annualRewardRate);
    }

    function pause() external onlyOwner {
        _pause();
        emit Paused();
    }

    function unpause() external onlyOwner {
        _unpause();
        emit Unpaused();
    }

    /**
     * @dev Returns the amount staked and pending rewards for a user,
     * including accrued rewards that have not yet unlocked
     */
    function getUserStakingInfo(
        address user
    ) public view returns (uint256 totalStaked, uint256 outstandingCGV) {
        UserInfo storage userInfo = userStakingInfo[user];
        totalStaked = 0;
        outstandingCGV = 0;

        for (uint256 i = 0; i < userInfo.stakes.length; i++) {
            Stake storage currentStake = userInfo.stakes[i];
            uint256 stakedDuration = block.timestamp.sub(
                currentStake.timestamp
            );
            uint256 reward = calculateReward(
                currentStake.amount,
                stakedDuration
            );
            outstandingCGV = outstandingCGV.add(reward);
            totalStaked = totalStaked.add(currentStake.amount);
        }
    }

    /**
     * @dev Returns the total pending rewards for all users,
     * including accrued rewards that have not yet unlocked
     */
    function getTotalOutstandingRewards() external view returns (uint256) {
        uint256 totalOutstandingRewards = 0;
        for (uint256 i = 0; i < userAddresses.length(); i++) {
            address user = userAddresses.at(i);
            (, uint256 outstandingCGV) = getUserStakingInfo(user);
            totalOutstandingRewards = totalOutstandingRewards.add(
                outstandingCGV
            );
        }
        return totalOutstandingRewards;
    }

    /**
     * @dev Returns the total staked gcoin for all users
     */
    function getTotalLockedValue() external view returns (uint256) {
        uint256 totalStaked = 0;
        for (uint256 i = 0; i < userAddresses.length(); i++) {
            address user = userAddresses.at(i);
            (uint256 totalStakedUser, ) = getUserStakingInfo(user);
            totalStaked = totalStaked.add(totalStakedUser);
        }
        return totalStaked;
    }

    /**
     * @dev Converts the {value} originally denominated in {from} decimals to {to} decimals
     */
    function _convertDecimals(
        uint256 value,
        uint8 from,
        uint8 to
    ) private pure returns (uint256) {
        return value.mul(10 ** to).div(10 ** from);
    }
}
