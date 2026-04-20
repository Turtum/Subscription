// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.34;

import {
    ISubscription,
    YearCountZero,
    AddressZero,
    InsufficientBalance,
    InvalidFeeDiscount,
    InvalidFeeDiscountPeriod,
    InvalidSubscriptionFee
} from "./interfaces/ISubscription.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {IWhiteList, NotWhiteListed} from "whitelist-contracts/src/interfaces/IWhiteList.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract Subscription is ISubscription, Ownable, Initializable {
    using SafeERC20 for IERC20Metadata;

    uint256 public subscriptionFee;
    uint256 public constant SUBSCRIPTION_DURATION = 365 days;

    uint256 public feeDiscountBps;
    uint256 public feeDiscountFrom;
    uint256 public feeDiscountTo;
    uint256 internal constant BPS_DENOMINATOR = 10_000;

    address private _whiteList;
    mapping(address => uint256) public expirationTimes;
    address subscriptionFeeReceiver;

    constructor() {
        _transferOwnership(tx.origin);
    }

    function initialize(address whiteListAddress_, uint256 initSubscriptionFee) public initializer {
        if (whiteListAddress_ == address(0)) {
            revert AddressZero();
        }
        _whiteList = whiteListAddress_;
        if (initSubscriptionFee == 0) {
            revert InvalidSubscriptionFee();
        }
        subscriptionFee = initSubscriptionFee;
    }

    function setSubscriptionFee(uint256 subscriptionFee_) external override onlyOwner {
        subscriptionFee = subscriptionFee_;
    }

    function setSubscriptionFeeReceiver(address subscriptionFeeReceiver_) external override onlyOwner {
        if (subscriptionFeeReceiver_ == address(0)) {
            revert AddressZero();
        }
        subscriptionFeeReceiver = subscriptionFeeReceiver_;
    }

    function setFeeDiscount(uint256 discount, uint256 fromTimestamp, uint256 toTimestamp) external override onlyOwner {
        if (discount > BPS_DENOMINATOR) {
            revert InvalidFeeDiscount();
        }
        if (fromTimestamp > toTimestamp || block.timestamp > toTimestamp) {
            revert InvalidFeeDiscountPeriod();
        }
        feeDiscountBps = discount;
        feeDiscountFrom = fromTimestamp;
        feeDiscountTo = toTimestamp;
    }

    function subscribe(address stableCoinAddress, uint8 yearCount) external override {
        if (!IWhiteList(_whiteList).isStableCoinWhiteListed(stableCoinAddress)) {
            revert NotWhiteListed();
        }
        if (yearCount == 0) {
            revert YearCountZero();
        }
        uint256 startTimestamp = (expirationTimes[msg.sender] == 0 || expirationTimes[msg.sender] < block.timestamp)
            ? block.timestamp
            : expirationTimes[msg.sender];
        expirationTimes[msg.sender] = startTimestamp + SUBSCRIPTION_DURATION * yearCount;
        IERC20Metadata stableCoin = IERC20Metadata(stableCoinAddress);
        uint256 grossFee = subscriptionFee * 10 ** stableCoin.decimals() * yearCount;
        uint256 fee = grossFee;
        if (feeDiscountBps != 0 && block.timestamp >= feeDiscountFrom && block.timestamp <= feeDiscountTo) {
            fee = (grossFee * (BPS_DENOMINATOR - feeDiscountBps)) / BPS_DENOMINATOR;
        }
        if (stableCoin.balanceOf(msg.sender) < fee) {
            revert InsufficientBalance();
        }
        stableCoin.safeTransferFrom(msg.sender, subscriptionFeeReceiver, fee);
    }

    function getExpirationTime(address user) external view override returns (uint256) {
        return expirationTimes[user];
    }
}
