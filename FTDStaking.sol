

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract FTDStaking {
    struct User {
        address userAddress;
        address referralAddress;
        uint256 registrationTime;
        uint256 referralCount;
        bool isStaked;
        uint256 stakedAmount;
        uint256 stakeStartTime;
    }

    mapping(address => User) public users;
    IERC20 public ftdToken;

    // Referral rewards percentages
    uint256[10] public referralRewards = [1000, 500, 400, 300, 200, 100, 70, 50, 30, 20]; // 10%, 5%, 4%, 3%, 2%, 1%, 0.7%, 0.5%, 0.3%, 0.2%
    
    uint256 public constant MINIMUM_STAKE = 1 * 1e18; // Minimum stake amount (1 FTD)
    uint256 public constant DAILY_REWARD_RATE = 50; // 0.50% per day (50 basis points)
    
    event UserRegistered(address indexed userAddress, address indexed referralAddress, uint256 registrationTime);
    event ReferralRewardClaimed(address indexed userAddress, uint256 amount);
    event Stake(address indexed userAddress, uint256 amount);
    event ClaimRewards(address indexed userAddress, uint256 amount);

    constructor(address _ftdToken) {
        ftdToken = IERC20(_ftdToken);
    }

    function register(address _referralAddress) external {
        require(users[msg.sender].userAddress == address(0), "User already registered");

        users[msg.sender] = User({
            userAddress: msg.sender,
            referralAddress: _referralAddress,
            registrationTime: block.timestamp,
            referralCount: 0,
            isStaked: false,
            stakedAmount: 0,
            stakeStartTime: 0
        });

        // Increment referral count for the referrer
        if (_referralAddress != address(0)) {
            users[_referralAddress].referralCount += 1;
        }

        emit UserRegistered(msg.sender, _referralAddress, block.timestamp);
    }

    function isRegistered(address _userAddress) external view returns (bool) {
        return users[_userAddress].userAddress != address(0);
    }

    function stake(uint256 _amount) external {
        require(_amount >= MINIMUM_STAKE, "Minimum stake is 1 FTD");
        require(users[msg.sender].userAddress != address(0), "User not registered");
        require(!users[msg.sender].isStaked, "Already staked");

        ftdToken.transferFrom(msg.sender, address(this), _amount);

        users[msg.sender].isStaked = true;
        users[msg.sender].stakedAmount = _amount;
        users[msg.sender].stakeStartTime = block.timestamp;

        emit Stake(msg.sender, _amount);

        // Handle multi-level referral rewards
        address currentReferrer = users[msg.sender].referralAddress;
        uint256 remainingAmount = _amount;

        for (uint256 i = 0; i < referralRewards.length; i++) {
            if (currentReferrer == address(0)) break;

            uint256 reward = (remainingAmount * referralRewards[i]) / 10000; // Calculate reward
            ftdToken.transfer(currentReferrer, reward); // Transfer reward to referrer

            remainingAmount -= reward; // Deduct rewarded amount from remaining

            currentReferrer = users[currentReferrer].referralAddress; // Move to the next level
        }
    }

    function claimRewards() external {
        require(users[msg.sender].isStaked, "No active stake");

        uint256 stakingDuration = block.timestamp - users[msg.sender].stakeStartTime;
        uint256 dailyReward = (users[msg.sender].stakedAmount * DAILY_REWARD_RATE) / 10000;
        uint256 totalStakingRewards = (stakingDuration / 1 days) * dailyReward;

        uint256 totalPayout = totalStakingRewards; // Only staking rewards here

        // Transfer staking rewards
        if (totalPayout > 0) {
            ftdToken.transfer(msg.sender, totalPayout);
            emit ClaimRewards(msg.sender, totalPayout);
        }
    }

    function claimReferralRewards() external {
        require(users[msg.sender].userAddress != address(0), "User not registered");

        uint256 referralReward = users[msg.sender].referralCount * referralRewards[0] / 10000; // Calculate based on the first level reward
        if (referralReward > 0) {
            ftdToken.transfer(msg.sender, referralReward);
            users[msg.sender].referralCount = 0; // Reset referral count after claiming
            emit ReferralRewardClaimed(msg.sender, referralReward);
        }
    }
    
    // function getUserInfo(address _userAddress) external view returns (User memory) {
    //     require(users[_userAddress].userAddress != address(0), "User not registered");
    //     return users[_userAddress];
    // }
}
