pragma solidity 0.8.13;

import "./BaseTest.sol";

contract GaugeTest is BaseTest {
    function _setUp() public override {
        // ve
        VELO.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAXTIME);
        vm.startPrank(address(owner2));
        VELO.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAXTIME);
        vm.stopPrank();
        vm.startPrank(address(owner3));
        VELO.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAXTIME);
        vm.stopPrank();
        vm.warp(block.timestamp + 1);

        skipToNextEpoch(1);
    }

    event Deposit(address indexed from, address indexed to, uint256 amount);
    event Withdraw(address indexed from, uint256 amount);

    function testCannotDepositWithRecipientZeroAmount() public {
        vm.expectRevert("Gauge: zero amount");
        gauge.deposit(0, address(owner2));
    }

    function testCannotDepositWithRecipientWithKilledGauge() public {
        voter.killGauge(address(gauge));

        vm.expectRevert("Gauge: not alive");
        gauge.deposit(PAIR_1, address(owner2));
    }

    function testDepositWithRecipient() public {
        assertEq(gauge.totalSupply(), 0);

        // deposit to owner3 from owner
        uint256 pre = pair.balanceOf(address(owner));
        pair.approve(address(gauge), PAIR_1);
        vm.expectEmit(true, false, false, true, address(gauge));
        emit Deposit(address(owner), address(owner3), PAIR_1);
        gauge.deposit(PAIR_1, address(owner3));
        uint256 post = pair.balanceOf(address(owner));

        assertEq(gauge.totalSupply(), PAIR_1);
        assertEq(gauge.earned(address(owner3)), 0);
        assertEq(gauge.balanceOf(address(owner3)), PAIR_1);
        assertEq(pre - post, PAIR_1);

        skip(1 hours);
        _addLiquidityToPool(address(owner2), address(router), address(FRAX), address(USDC), true, TOKEN_1, USDC_1);

        skip(1 hours);
        // deposit to owner4 from owner2
        pre = pair.balanceOf(address(owner2));
        vm.prank(address(owner2));
        pair.approve(address(gauge), PAIR_1);
        vm.expectEmit(true, false, false, true, address(gauge));
        emit Deposit(address(owner2), address(owner4), PAIR_1);
        vm.prank(address(owner2));
        gauge.deposit(PAIR_1, address(owner4));
        post = pair.balanceOf(address(owner2));

        assertEq(gauge.totalSupply(), PAIR_1 * 2);
        assertEq(gauge.earned(address(owner4)), 0);
        assertEq(gauge.balanceOf(address(owner4)), PAIR_1);
        assertEq(pre - post, PAIR_1);
    }

    function testCannotDepositZeroAmount() public {
        vm.expectRevert("Gauge: zero amount");
        gauge.deposit(0);
    }

    function testCannotDepositWithKilledGauge() public {
        voter.killGauge(address(gauge));

        vm.expectRevert("Gauge: not alive");
        gauge.deposit(PAIR_1);
    }

    function testDeposit() public {
        assertEq(gauge.totalSupply(), 0);

        uint256 pre = pair.balanceOf(address(owner));
        pair.approve(address(gauge), PAIR_1);
        vm.expectEmit(true, false, false, true, address(gauge));
        emit Deposit(address(owner), address(owner), PAIR_1);
        gauge.deposit(PAIR_1);
        uint256 post = pair.balanceOf(address(owner));

        assertEq(gauge.totalSupply(), PAIR_1);
        assertEq(gauge.earned(address(owner)), 0);
        assertEq(gauge.balanceOf(address(owner)), PAIR_1);
        assertEq(pre - post, PAIR_1);

        skip(1 hours);
        _addLiquidityToPool(address(owner2), address(router), address(FRAX), address(USDC), true, TOKEN_1, USDC_1);

        skip(1 hours);
        pre = pair.balanceOf(address(owner2));
        vm.prank(address(owner2));
        pair.approve(address(gauge), PAIR_1);
        vm.expectEmit(true, false, false, true, address(gauge));
        emit Deposit(address(owner2), address(owner2), PAIR_1);
        vm.prank(address(owner2));
        gauge.deposit(PAIR_1);
        post = pair.balanceOf(address(owner2));

        assertEq(gauge.totalSupply(), PAIR_1 * 2);
        assertEq(gauge.earned(address(owner2)), 0);
        assertEq(gauge.balanceOf(address(owner2)), PAIR_1);
        assertEq(pre - post, PAIR_1);
    }

    function testWithdrawWithDepositWithNoRecipient() public {
        pair.approve(address(gauge), PAIR_1);
        gauge.deposit(PAIR_1);

        _addLiquidityToPool(address(owner2), address(router), address(FRAX), address(USDC), true, TOKEN_1, USDC_1);

        vm.prank(address(owner2));
        pair.approve(address(gauge), PAIR_1);
        vm.prank(address(owner2));
        gauge.deposit(PAIR_1);
        assertEq(gauge.balanceOf(address(owner2)), PAIR_1);

        skip(1 hours);

        uint256 pre = pair.balanceOf(address(owner));
        vm.expectEmit(true, false, false, true, address(gauge));
        emit Withdraw(address(owner), PAIR_1);
        gauge.withdraw(PAIR_1);
        uint256 post = pair.balanceOf(address(owner));

        assertEq(gauge.totalSupply(), PAIR_1);
        assertEq(gauge.earned(address(owner)), 0);
        assertEq(gauge.balanceOf(address(owner)), 0);
        assertEq(post - pre, PAIR_1);

        skip(1 hours);

        pre = pair.balanceOf(address(owner2));
        vm.expectEmit(true, false, false, true, address(gauge));
        emit Withdraw(address(owner2), PAIR_1);
        vm.prank(address(owner2));
        gauge.withdraw(PAIR_1);
        post = pair.balanceOf(address(owner2));

        assertEq(gauge.totalSupply(), 0);
        assertEq(gauge.earned(address(owner2)), 0);
        assertEq(gauge.balanceOf(address(owner2)), 0);
        assertEq(post - pre, PAIR_1);
    }

    function testWithdrawWithDepositWithRecipient() public {
        pair.approve(address(gauge), PAIR_1);
        gauge.deposit(PAIR_1);

        _addLiquidityToPool(address(owner2), address(router), address(FRAX), address(USDC), true, TOKEN_1, USDC_1);

        vm.prank(address(owner2));
        pair.approve(address(gauge), PAIR_1);
        vm.prank(address(owner2));
        gauge.deposit(PAIR_1, address(owner3));
        assertEq(gauge.balanceOf(address(owner2)), 0);
        assertEq(gauge.balanceOf(address(owner3)), PAIR_1);

        skip(1 hours);

        uint256 pre = pair.balanceOf(address(owner));
        vm.expectEmit(true, false, false, true, address(gauge));
        emit Withdraw(address(owner), PAIR_1);
        gauge.withdraw(PAIR_1);
        uint256 post = pair.balanceOf(address(owner));

        assertEq(gauge.totalSupply(), PAIR_1);
        assertEq(gauge.earned(address(owner)), 0);
        assertEq(gauge.balanceOf(address(owner)), 0);
        assertEq(post - pre, PAIR_1);

        skip(1 hours);

        pre = pair.balanceOf(address(owner3));
        vm.expectEmit(true, false, false, true, address(gauge));
        emit Withdraw(address(owner3), PAIR_1);
        vm.prank(address(owner3));
        gauge.withdraw(PAIR_1);
        post = pair.balanceOf(address(owner3));

        assertEq(gauge.totalSupply(), 0);
        assertEq(gauge.earned(address(owner3)), 0);
        assertEq(gauge.balanceOf(address(owner3)), 0);
        assertEq(post - pre, PAIR_1);
    }

    function testGetRewardWithMultipleDepositors() public {
        // add deposits
        pair.approve(address(gauge), PAIR_1);
        gauge.deposit(PAIR_1);

        _addLiquidityToPool(address(owner2), address(router), address(FRAX), address(USDC), true, TOKEN_1, USDC_1);

        vm.prank(address(owner2));
        pair.approve(address(gauge), PAIR_1);
        vm.prank(address(owner2));
        gauge.deposit(PAIR_1);

        uint256 reward = TOKEN_1;
        _addRewardToGauge(address(voter), address(gauge), reward);

        skip(1 weeks / 2);

        assertApproxEqRel(gauge.earned(address(owner)), reward / 4, 1e6);
        assertApproxEqRel(gauge.earned(address(owner2)), reward / 4, 1e6);

        uint256 pre = VELO.balanceOf(address(owner));
        gauge.getReward(address(owner));
        uint256 post = VELO.balanceOf(address(owner));

        assertApproxEqRel(post - pre, reward / 4, 1e6);

        skip(1 weeks / 2);

        assertApproxEqRel(gauge.earned(address(owner)), reward / 4, 1e6);
        assertApproxEqRel(gauge.earned(address(owner2)), reward / 2, 1e6);

        pre = VELO.balanceOf(address(owner));
        gauge.getReward(address(owner));
        post = VELO.balanceOf(address(owner));

        assertApproxEqRel(post - pre, reward / 4, 1e6);

        pre = VELO.balanceOf(address(owner2));
        vm.prank(address(owner2));
        gauge.getReward(address(owner2));
        post = VELO.balanceOf(address(owner2));

        assertApproxEqRel(post - pre, reward / 2, 1e6);
    }

    function testGetRewardWithMultipleDepositorsAndEarlyWithdrawal() public {
        // add deposits
        pair.approve(address(gauge), PAIR_1);
        gauge.deposit(PAIR_1);

        _addLiquidityToPool(address(owner2), address(router), address(FRAX), address(USDC), true, TOKEN_1, USDC_1);

        vm.prank(address(owner2));
        pair.approve(address(gauge), PAIR_1);
        vm.prank(address(owner2));
        gauge.deposit(PAIR_1);

        uint256 reward = TOKEN_1;
        _addRewardToGauge(address(voter), address(gauge), reward);

        skip(1 weeks / 2);

        assertApproxEqRel(gauge.earned(address(owner)), reward / 4, 1e6);
        assertApproxEqRel(gauge.earned(address(owner2)), reward / 4, 1e6);

        uint256 pre = VELO.balanceOf(address(owner));
        gauge.getReward(address(owner));
        uint256 post = VELO.balanceOf(address(owner));

        assertApproxEqRel(post - pre, reward / 4, 1e6);

        // owner withdraws early after claiming
        gauge.withdraw(PAIR_1);

        skip(1 weeks / 2);

        // reward / 2 left to be disbursed to owner2 over the remainder of the week
        assertApproxEqRel(gauge.earned(address(owner)), 0, 1e6);
        assertApproxEqRel(gauge.earned(address(owner2)), (3 * reward) / 4, 1e6);

        pre = VELO.balanceOf(address(owner2));
        vm.prank(address(owner2));
        gauge.getReward(address(owner2));
        post = VELO.balanceOf(address(owner2));

        assertApproxEqRel(post - pre, (3 * reward) / 4, 1e6);
    }

    function testEarnedWithStaggeredDepositsAndWithdrawals() public {
        // add deposits
        pair.approve(address(gauge), PAIR_1);
        gauge.deposit(PAIR_1);

        uint256 reward = TOKEN_1;
        _addRewardToGauge(address(voter), address(gauge), reward);

        skip(1 days);

        // single deposit, 1/7th of epoch
        assertApproxEqRel(gauge.earned(address(owner)), reward / 7, 1e6);
        gauge.getReward(address(owner));

        _addLiquidityToPool(address(owner2), address(router), address(FRAX), address(USDC), true, TOKEN_1, USDC_1);
        vm.prank(address(owner2));
        pair.approve(address(gauge), PAIR_1);
        vm.prank(address(owner2));
        gauge.deposit(PAIR_1);

        skip(1 days);
        // two deposits, equal in size, 1/7th of epoch
        uint256 expectedReward = reward / 7 / 2;
        assertApproxEqRel(gauge.earned(address(owner)), expectedReward, 1e6);
        assertApproxEqRel(gauge.earned(address(owner2)), expectedReward, 1e6);
        gauge.getReward(address(owner));
        vm.prank(address(owner2));
        gauge.getReward(address(owner2));

        pair.approve(address(gauge), PAIR_1);
        gauge.deposit(PAIR_1);

        skip(1 days);
        // two deposits, owner with twice the size of owner2, 1/7th of epoch
        expectedReward = reward / 7 / 3;
        assertApproxEqRel(gauge.earned(address(owner)), expectedReward * 2, 1e6);
        assertApproxEqRel(gauge.earned(address(owner2)), expectedReward, 1e6);
        gauge.getReward(address(owner));
        vm.prank(address(owner2));
        gauge.getReward(address(owner2));

        vm.prank(address(owner2));
        gauge.withdraw(PAIR_1 / 2);

        skip(1 days);
        // two deposits, owner with four times the size of owner 2, 1/7th of epoch
        expectedReward = reward / 7 / 5;
        assertApproxEqRel(gauge.earned(address(owner)), expectedReward * 4, 1e6);
        assertApproxEqRel(gauge.earned(address(owner2)), expectedReward, 1e6);
    }

    function testEarnedWithStaggeredDepositsAndWithdrawalsWithoutIntermediateClaims() public {
        // add deposits
        pair.approve(address(gauge), PAIR_1);
        gauge.deposit(PAIR_1);

        uint256 reward = TOKEN_1;
        _addRewardToGauge(address(voter), address(gauge), reward);

        skip(1 days);

        // single deposit, 1/7th of epoch
        uint256 ownerBal = reward / 7;
        assertApproxEqRel(gauge.earned(address(owner)), reward / 7, 1e6);

        _addLiquidityToPool(address(owner2), address(router), address(FRAX), address(USDC), true, TOKEN_1, USDC_1);
        vm.prank(address(owner2));
        pair.approve(address(gauge), PAIR_1);
        vm.prank(address(owner2));
        gauge.deposit(PAIR_1);

        skip(1 days);
        // two deposits, equal in size, 1/7th of epoch
        ownerBal += (reward / 7) / 2;
        uint256 owner2Bal = (reward / 7) / 2;
        assertApproxEqRel(gauge.earned(address(owner)), ownerBal, 1e6);
        assertApproxEqRel(gauge.earned(address(owner2)), owner2Bal, 1e6);

        pair.approve(address(gauge), PAIR_1);
        gauge.deposit(PAIR_1);

        skip(1 days);
        // two deposits, owner with twice the size of owner2, 1/7th of epoch
        ownerBal += ((reward / 7) / 3) * 2;
        owner2Bal += (reward / 7) / 3;
        assertApproxEqRel(gauge.earned(address(owner)), ownerBal, 1e6);
        assertApproxEqRel(gauge.earned(address(owner2)), owner2Bal, 1e6);

        vm.prank(address(owner2));
        gauge.withdraw(PAIR_1 / 2);

        skip(1 days);
        // two deposits, owner with four times the size of owner 2, 1/7th of epoch
        ownerBal += ((reward / 7) / 5) * 4;
        owner2Bal += (reward / 7) / 5;
        assertApproxEqRel(gauge.earned(address(owner)), ownerBal, 1e6);
        assertApproxEqRel(gauge.earned(address(owner2)), owner2Bal, 1e6);
    }

    function testGetRewardWithOverlappingRewards() public {
        // add deposits
        pair.approve(address(gauge), PAIR_1);
        gauge.deposit(PAIR_1);

        _addLiquidityToPool(address(owner2), address(router), address(FRAX), address(USDC), true, TOKEN_1, USDC_1);

        vm.prank(address(owner2));
        pair.approve(address(gauge), PAIR_1);
        vm.prank(address(owner2));
        gauge.deposit(PAIR_1);

        skip(1 weeks / 2);

        // reward added late in epoch
        uint256 reward = TOKEN_1;
        _addRewardToGauge(address(voter), address(gauge), reward);
        uint256 expectedRewardRate = TOKEN_1 / DURATION;
        assertApproxEqRel(gauge.rewardRate(), expectedRewardRate, 1e6);

        skipToNextEpoch(1);
        // half the epoch has passed
        uint256 expectedReward = reward / 2 / 2;
        assertApproxEqRel(gauge.earned(address(owner)), expectedReward, 1e6);
        assertApproxEqRel(gauge.earned(address(owner2)), expectedReward, 1e6);
        // two deposits, owner with half the size of owner 2
        gauge.withdraw(PAIR_1 / 2);
        gauge.getReward(address(owner));

        uint256 reward2 = TOKEN_1 * 2;
        expectedRewardRate = (reward / 2) / DURATION + (reward2) / DURATION;
        _addRewardToGauge(address(voter), address(gauge), reward2);
        assertApproxEqRel(gauge.rewardRate(), expectedRewardRate, 1e6);

        skipToNextEpoch(1);
        uint256 remainingRewards = TOKEN_1 / 2 + TOKEN_1 * 2;
        assertApproxEqRel(gauge.earned(address(owner)), remainingRewards / 3, 1e6);
        assertApproxEqRel(gauge.earned(address(owner2)), (remainingRewards * 2) / 3 + expectedReward, 1e6);

        uint256 pre = VELO.balanceOf(address(owner));
        vm.prank(address(owner));
        gauge.getReward(address(owner));
        uint256 post = VELO.balanceOf(address(owner));
        assertApproxEqRel(post - pre, remainingRewards / 3, 1e6);

        pre = VELO.balanceOf(address(owner2));
        vm.prank(address(owner2));
        gauge.getReward(address(owner2));
        post = VELO.balanceOf(address(owner2));

        assertApproxEqRel(post - pre, (remainingRewards * 2) / 3 + expectedReward, 1e6);
    }

    function testGetRewardWithNonOverlappingRewards() public {
        // add deposits
        pair.approve(address(gauge), PAIR_1);
        gauge.deposit(PAIR_1);

        _addLiquidityToPool(address(owner2), address(router), address(FRAX), address(USDC), true, TOKEN_1, USDC_1);

        vm.prank(address(owner2));
        pair.approve(address(gauge), PAIR_1);
        vm.prank(address(owner2));
        gauge.deposit(PAIR_1);

        uint256 reward = TOKEN_1;
        _addRewardToGauge(address(voter), address(gauge), reward);
        uint256 expectedRewardRate = TOKEN_1 / DURATION;
        assertApproxEqRel(gauge.rewardRate(), expectedRewardRate, 1e6);

        skipToNextEpoch(1);
        uint256 expectedReward = reward / 2;
        assertApproxEqRel(gauge.earned(address(owner)), expectedReward, 1e6);
        assertApproxEqRel(gauge.earned(address(owner2)), expectedReward, 1e6);

        skip(1 days);
        uint256 reward2 = TOKEN_1 * 2;
        _addRewardToGauge(address(voter), address(gauge), reward2);
        expectedRewardRate = (TOKEN_1 * 2) / DURATION;
        assertApproxEqRel(gauge.rewardRate(), expectedRewardRate, 1e6);

        skipToNextEpoch(1 days + 1);
        expectedReward = (reward + reward2) / 2;
        assertApproxEqRel(gauge.earned(address(owner)), expectedReward, 1e6);
        assertApproxEqRel(gauge.earned(address(owner2)), expectedReward, 1e6);
    }

    function testNotifyRewardAmountWithNonZeroAmount() public {
        uint256 reward = TOKEN_1;

        deal(address(VELO), address(voter), reward);
        vm.startPrank(address(voter));
        VELO.approve(address(gauge), reward);
        Gauge(gauge).notifyRewardAmount(reward);
        vm.stopPrank();

        // TODO: test it correctly transfers fees

        uint256 epochStart = _getEpochStart(block.timestamp);
        assertApproxEqRel(gauge.rewardRate(), reward / DURATION, 1e6);
        assertApproxEqRel(gauge.rewardRateByEpoch(epochStart), reward / DURATION, 1e6);
        assertEq(VELO.balanceOf(address(gauge)), TOKEN_1);
        assertEq(gauge.lastUpdateTime(), block.timestamp);
        assertEq(gauge.periodFinish(), block.timestamp + DURATION);
    }

    function testCannotNotifyRewardAmountWithZeroAmount() public {
        vm.prank(address(voter));
        vm.expectRevert("Gauge: zero amount");
        gauge.notifyRewardAmount(0);
    }

    function testCannotNotifyRewardAmountIfNotVoter() public {
        vm.expectRevert("Gauge: only voter can notify reward");
        gauge.notifyRewardAmount(TOKEN_1);
    }

    function testCannotGetRewardIfNotOwnerOrVoter() public {
        // add deposits
        pair.approve(address(gauge), PAIR_1);
        gauge.deposit(PAIR_1);

        uint256 reward = TOKEN_1;
        _addRewardToGauge(address(voter), address(gauge), reward);

        vm.expectRevert("Gauge: unpermissioned");
        vm.prank(address(owner2));
        gauge.getReward(address(owner));

        skip(1 days);

        uint256 pre = VELO.balanceOf(address(owner));
        gauge.getReward(address(owner));
        uint256 post = VELO.balanceOf(address(owner));

        assertApproxEqRel(post - pre, reward / 7, 1e6);

        skip(1 days);

        pre = VELO.balanceOf(address(owner));
        vm.prank(address(voter));
        gauge.getReward(address(owner));
        post = VELO.balanceOf(address(owner));

        assertApproxEqRel(post - pre, reward / 7, 1e6);
    }
}