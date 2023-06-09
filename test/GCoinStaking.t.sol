// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "forge-std/Test.sol";
import "../src/CGV.sol";
import "../src/GCoin.sol";
import "../src/Treasury.sol";
import "../src/GCoinStaking.sol";

contract MockToken is ERC20PresetMinterPauser {
    constructor(
        string memory name,
        string memory symbol
    ) ERC20PresetMinterPauser(name, symbol) {}
}

contract GCoinStakingTest is Test {
    GCoin public gcoin;
    Treasury public treasury;
    MockToken public stablecoin0;

    CGV public cgv;
    GCoinStaking public staking;
    address public stakeholder;

    struct StakeWithUnclaimed {
        uint256 amount;
        uint256 timestamp;
        uint256 duration;
        uint256 rewardMultiplier;
        uint256 claimedReward;
        uint256 unclaimedReward;
    }

    function setUp() public {
        // Set to Jan 1, 2023
        vm.warp(1672549200);

        gcoin = new GCoin();
        address[] memory arr = new address[](0);
        treasury = new Treasury(address(gcoin), msg.sender, arr, arr);
        // Set treasury address in the GCoin contract
        gcoin.setTreasury(address(treasury));

        // mint some gcoin
        stakeholder = address(111);
        stablecoin0 = new MockToken("T0", "T0");
        stablecoin0.mint(stakeholder, 100e18);
        gcoin.addStableCoin(address(stablecoin0));

        vm.startPrank(stakeholder);
        stablecoin0.approve(address(gcoin), 100e18);
        gcoin.depositStableCoin(address(stablecoin0), 100e18);
        vm.stopPrank();

        // set CGV tokens
        cgv = new CGV();

        staking = new GCoinStaking(address(gcoin), address(cgv), 10);

        // Set up treasury
        staking.setTreasury(address(treasury));
        cgv.mint(address(treasury), 1e18);

        vm.prank(address(treasury));
        cgv.approve(address(staking), 1e18);
    }

    function test_Stake() public {
        vm.startPrank(stakeholder);
        gcoin.approve(address(staking), 1e18);
        uint256 gcoinBefore = gcoin.balanceOf(stakeholder);
        staking.stake(1e18, 365 days);
        (uint256 totalStaked, uint256 outstandingCGV) = staking
            .getUserStakingInfo(stakeholder);

        // console2.log("after stake", gcoin.balanceOf(address(staking)), gcoin.balanceOf(stakeholder));
        assert(totalStaked == 1e18);
        assert(outstandingCGV == 0);
        assert(gcoin.balanceOf(stakeholder) == gcoinBefore - 1e18);

        vm.stopPrank();
    }

    function test_Stake2Wallet() public {
        address stakeholder1 = address(222);
        stablecoin0.mint(stakeholder1, 200e18);
        vm.startPrank(stakeholder1);
        // mint GCoin for stakeholder1 for 200
        stablecoin0.approve(address(gcoin), 200e18);

        gcoin.depositStableCoin(address(stablecoin0), 200e18);
        gcoin.approve(address(staking), 200e18);

        staking.stake(199e18, 365 days);
        vm.stopPrank();

        address stakeholder2 = address(333);
        stablecoin0.mint(stakeholder2, 200e18);
        vm.startPrank(stakeholder2);
        // mint GCoin for stakeholder2 for 200
        stablecoin0.approve(address(gcoin), 200e18);

        gcoin.depositStableCoin(address(stablecoin0), 200e18);
        gcoin.approve(address(staking), 200e18);

        staking.stake(199e18, 180 days);
        vm.stopPrank();

        assert(staking.getTotalLockedValue() == 398e18);
        assert(gcoin.balanceOf(address(staking)) == 398e18);
    }

    function test_StakeReward() public {
        staking.updateAnnualRewardRate(10);

        uint256 r0 = staking.calculateRewardRate(30 days);
        assert(r0 == 10);

        uint256 r1 = staking.calculateRewardRate(80 days);
        assert(r1 == 11);

        uint256 r2 = staking.calculateRewardRate(365 days);
        assert(r2 == 15);

        uint256 reward = staking.calculateReward(100e18, 365 days, r2);
        assert(reward == 15e6);
    }

    function test_WithdrawReward() public {
        staking.updateAnnualRewardRate(10);

        vm.startPrank(stakeholder);
        gcoin.approve(address(staking), 1e18);
        staking.stake(1e18, 30 days);

        skip(30 days);

        assert(
            staking.getUserStakingInfoList(stakeholder)[0].claimedReward == 0
        );
        assert(
            staking.getUserStakingInfoList(stakeholder)[0].unclaimedReward ==
                8219
        );
        assert(cgv.balanceOf(stakeholder) == 0);

        staking.withdrawRewardSpecific(0);

        assert(cgv.balanceOf(stakeholder) == 8219);
        assert(
            staking.getUserStakingInfoList(stakeholder)[0].claimedReward == 8219
        );
        assert(
            staking.getUserStakingInfoList(stakeholder)[0].unclaimedReward == 0
        );

        skip(30 days);

        assert(
            staking.getUserStakingInfoList(stakeholder)[0].unclaimedReward ==
                8219
        );
        staking.withdrawRewardSpecific(0);
        assert(cgv.balanceOf(stakeholder) == 8219 * 2);
        assert(
            staking.getUserStakingInfoList(stakeholder)[0].claimedReward ==
                8219 * 2
        );
        assert(
            staking.getUserStakingInfoList(stakeholder)[0].unclaimedReward == 0
        );

        vm.stopPrank();
    }

    function test_WithdrawRewardWithRateUpdate() public {
        staking.updateAnnualRewardRate(10);

        vm.startPrank(stakeholder);
        gcoin.approve(address(staking), 1e18);
        staking.stake(1e18, 30 days);
        vm.stopPrank();

        skip(10 days);
        staking.updateAnnualRewardRate(100);
        skip(20 days);

        vm.startPrank(stakeholder);
        assert(
            staking.getUserStakingInfoList(stakeholder)[0].claimedReward == 0
        );
        assert(
            staking.getUserStakingInfoList(stakeholder)[0].unclaimedReward ==
                8219
        );
        assert(cgv.balanceOf(stakeholder) == 0);

        staking.withdrawRewardSpecific(0);

        assert(cgv.balanceOf(stakeholder) == 8219);
        assert(
            staking.getUserStakingInfoList(stakeholder)[0].claimedReward == 8219
        );
        assert(
            staking.getUserStakingInfoList(stakeholder)[0].unclaimedReward == 0
        );
    }

    function test_WithdrawMultiple() public {
        vm.startPrank(stakeholder);
        gcoin.approve(address(staking), 100e18);
        staking.stake(1e18, 30 days);

        skip(10 days);

        staking.stake(3e18, 30 days);
        staking.stake(2e18, 30 days);
        assert(staking.getUserStakingInfoList(stakeholder).length == 3);

        staking.withdrawSpecific(0);
        assert(staking.getUserStakingInfoList(stakeholder).length == 3);

        vm.expectRevert();
        staking.withdrawSpecific(3);

        skip(20 days);

        staking.withdrawRewardSpecific(0);
        skip(1 days);

        staking.withdrawSpecific(0);
        assert(staking.getUserStakingInfoList(stakeholder).length == 2);

        skip(10 days);
        staking.withdrawAll();
        assert(staking.getUserStakingInfoList(stakeholder).length == 0);

        vm.stopPrank();
    }

    function test_WithdrawMultipleWithVariableRate() public {
        staking.updateAnnualRewardRate(10);
        vm.startPrank(stakeholder);
        uint originalGcoinBalance = gcoin.balanceOf(stakeholder);
        gcoin.approve(address(staking), 100e18);
        staking.stake(1e18, 30 days);
        vm.stopPrank();

        skip(10 days);
        staking.updateAnnualRewardRate(40);

        vm.startPrank(stakeholder);
        staking.stake(3e18, 30 days);
        staking.stake(2e18, 60 days);
        assert(staking.getUserStakingInfoList(stakeholder).length == 3);

        skip(20 days);
        staking.withdrawSpecific(0);

        skip(10 days);
        staking.withdrawRewardSpecific(1);

        uint stakeholder1Rate = staking
        .getUserStakingInfoList(stakeholder)[1].rewardMultiplier;
        assert(stakeholder1Rate == 41);

        assert(cgv.balanceOf(stakeholder) == 109314);

        skip(30 days);

        staking.withdrawAll();

        assert(cgv.balanceOf(stakeholder) == 351779);
        assert(gcoin.balanceOf(stakeholder) == originalGcoinBalance);

        vm.stopPrank();
    }
}
