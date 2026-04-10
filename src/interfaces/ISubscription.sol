// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.34;

error YearCountZero();
error AddressZero();
error InsufficientBalance();
error SubscriptionFeeIncreaseTooLarge();
error SubscriptionFeeAdjustmentTooSoon();
error InvalidFeeDiscount();
error InvalidFeeDiscountPeriod();

interface ISubscription {
    /**
     * @notice Set the subscription fee.
     * @dev Set the subscription fee.
     * @param subscriptionFee The subscription fee.
     */
    function setSubscriptionFee(uint256 subscriptionFee) external;

    /**
     * @notice Set the subscription fee receiver.
     * @dev Set the subscription fee receiver.
     * @param subscriptionFeeReceiver The address of the subscription fee receiver.
     */
    function setSubscriptionFeeReceiver(address subscriptionFeeReceiver) external;

    /**
     * @notice Set a temporary fee discount window. Does not affect the annual `setSubscriptionFee` cooldown.
     * @param discount Reduction in basis points (10000 = 100% off). Must be <= 10000.
     * @param fromTimestamp Inclusive start; discount applies when block.timestamp is in [fromTimestamp, toTimestamp].
     * @param toTimestamp Inclusive end.
     */
    function setFeeDiscount(uint256 discount, uint256 fromTimestamp, uint256 toTimestamp) external;

    /**
     * @notice Subscribe to a subscription.
     * @dev Subscribe to a subscription.
     * @param stableCoinAddress The address of the stable coin.
     * @param yearCount The number of years to subscribe.
     */
    function subscribe(address stableCoinAddress, uint8 yearCount) external;

    /**
     * @notice Check the expired time of the subscription.
     * @dev Check the expired time of the subscription.
     * @param user The address to check the expired time of the subscription.
     * @return uint256 The expired time of the subscription.
     */
    function getExpirationTime(address user) external view returns (uint256);
}
