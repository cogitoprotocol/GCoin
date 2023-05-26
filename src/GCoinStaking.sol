// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/security/Pausable.sol";

contract GCoinStaking is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    IERC20 public gcoinToken;
    IERC20 public cgvToken;
    uint256 public annualRewardRate;

    uint256 public MIN_STAKING_DURATION = 180 days;
    uint256 public MAX_STAKING_DURATION = 4 * 365 days;
    uint256 public REWARD_SCALE = 50;



    struct Stake {
        uint256 amount;
        uint256 timestamp;
        uint256 duration;
        uint256 rewardMultiplier;
    }

    struct UserInfo {
        Stake[] stakes;
        uint256 totalStaked;
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
        gcoinToken = IERC20(_gcoinToken);
        cgvToken = IERC20(_cgvToken);
        annualRewardRate = _annualRewardRate;
    }

    // Users can stake GCoin tokens
    function stake(uint256 amount, uint256 duration) external whenNotPaused {
        require(duration >= MIN_STAKING_DURATION, "Staking duration is too short.");
        require(duration <= MAX_STAKING_DURATION, "Staking duration is too long.");

        uint256 rewardMultiplier = duration.mul(REWARD_SCALE).div(365 days);


        gcoinToken.safeTransferFrom(msg.sender, address(this), amount);
        UserInfo storage userInfo = userStakingInfo[msg.sender];
        userInfo.stakes.push(Stake({
            amount: amount,
            timestamp: block.timestamp,
            duration: duration,
            rewardMultiplier: rewardMultiplier
        }));

        userInfo.totalStaked = userInfo.totalStaked.add(amount);
        userAddresses.add(msg.sender);

        emit Staked(msg.sender, amount, duration);
    }

    // Users can withdraw their matured stakes along with the rewards
    function withdraw() external nonReentrant whenNotPaused {
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
                uint256 reward = currentStake
                    .amount
                    .mul(annualRewardRate)
                    .div(100)
                    .mul(stakedDuration)
                    .div(365 days);
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

        userInfo.totalStaked = userInfo.totalStaked.sub(totalAmount);
        gcoinToken.safeTransfer(msg.sender, totalAmount);
        cgvToken.safeTransfer(msg.sender, totalRewards);

        emit Withdrawn(msg.sender, totalAmount, totalRewards);
    }


    // Users can withdraw their matured stakes along with the rewards
    function withdrawSpecific(uint256 index) external nonReentrant whenNotPaused {
        UserInfo storage userInfo = userStakingInfo[msg.sender];

        Stake storage currentStake = userInfo.stakes[index];
        uint256 stakedDuration = block.timestamp.sub(
            currentStake.timestamp
        );
        if (stakedDuration >= currentStake.duration) {
            // uint256 reward = currentStake
            //     .amount
            //     .mul(annualRewardRate)
            //     .div(100)
            //     .mul(stakedDuration)
            //     .div(365 days);

            uint256 reward = calculateReward(currentStake.amount, currentStake.duration);
            require(
                cgvToken.balanceOf(address(this)) >= reward,
                "Not enough CGV tokens to pay rewards. We are adding more. Please wait"
            );


            gcoinToken.safeTransfer(msg.sender, currentStake.amount);
            cgvToken.safeTransfer(msg.sender, reward);
            userInfo.totalStaked = userInfo.totalStaked.sub(currentStake.amount);

            userInfo.stakes[index] = userInfo.stakes[
                userInfo.stakes.length - 1
            ];
            userInfo.stakes.pop();
            emit Withdrawn(msg.sender, currentStake.amount, reward);
        }
    }

    // need more calculation
    function calculateReward(uint256 amount, uint256 duration) public view returns (uint256) {
        return amount.mul(annualRewardRate)
                    .div(100)
                    .mul(duration)
                    .div(365 days)
                    .mul(100+REWARD_SCALE*duration)
                    .div(100);
    }

    function getUserStakingInfoList(address user)
        external
        view
        returns (UserInfo memory)
    {
        return userStakingInfo[user];
    }

    // Owner can update the staking period
    // function updateStakingPeriod(uint256 _stakingPeriod) external onlyOwner {
    //     stakingPeriod = _stakingPeriod;
    //     emit StakingPeriodUpdated(_stakingPeriod);
    // }

    // Owner can update the annual reward rate
    function updateAnnualRewardRate(uint256 _annualRewardRate)
        external
        onlyOwner
    {
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

    function getUserStakingInfo(address user)
        public
        view
        returns (uint256 totalStaked, uint256 outstandingCGV)
    {
        UserInfo storage userInfo = userStakingInfo[user];
        totalStaked = userInfo.totalStaked;
        outstandingCGV = 0;

        for (uint256 i = 0; i < userInfo.stakes.length; i++) {
            Stake storage currentStake = userInfo.stakes[i];
            uint256 stakedDuration = block.timestamp.sub(
                currentStake.timestamp
            );
            if (stakedDuration >= currentStake.duration) {
                uint256 reward = calculateReward(currentStake.amount, currentStake.duration);
                outstandingCGV = outstandingCGV.add(reward);
            }
        }
    }

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
}
