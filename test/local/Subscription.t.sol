// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.34;

import "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {Subscription} from "../../src/Subscription.sol";
import {IWhiteList, NotWhiteListed} from "../../lib/whitelist-contracts/src/interfaces/IWhiteList.sol";
import {WhiteList} from "../../lib/whitelist-contracts/src/WhiteList.sol";
import {MockERC20} from "../../lib/solmate/src/test/utils/mocks/MockERC20.sol";
import {
    YearCountZero,
    AddressZero,
    InsufficientBalance,
    InvalidSubscriptionFee,
    InvalidFeeDiscount,
    InvalidFeeDiscountPeriod
} from "../../src/interfaces/ISubscription.sol";

contract SubscriptionTest is Test {
    address public user;
    Subscription public subscription;
    address public feeReceiver;
    address public whiteList;
    MockERC20 public mockStableCoin;
    MockERC20 public mockStableCoin2;

    function setUp() public {
        user = makeAddr("alice");
        feeReceiver = makeAddr("feeReceiver");
        whiteList = address(new WhiteList());
        mockStableCoin = new MockERC20("StableCoin", "USDT", 6);
        mockStableCoin2 = new MockERC20("StableCoin2", "USDC", 6);
        subscription = new Subscription();
        vm.startPrank(tx.origin);
        subscription.transferOwnership(tx.origin);
        subscription.initialize(whiteList, 100);
        subscription.setSubscriptionFeeReceiver(feeReceiver);
        vm.stopPrank();

        address[] memory stableCoins = new address[](2);
        stableCoins[0] = address(mockStableCoin);
        stableCoins[1] = address(mockStableCoin2);
        WhiteList wl = WhiteList(whiteList);
        vm.startPrank(tx.origin);
        wl.grantRole(wl.STABLE_COIN_MANAGER_ROLE(), tx.origin);
        IWhiteList(whiteList).addStableCoins(stableCoins);
        vm.stopPrank();
    }

    function test_InitializeFailedWhenWhiteListIsZeroAddress() public {
        Subscription sub = new Subscription();
        vm.expectRevert(AddressZero.selector);
        sub.initialize(address(0), 100);
    }

    function test_InitializeFailedWhenSubscriptionFeeZero() public {
        Subscription sub = new Subscription();
        vm.expectRevert(InvalidSubscriptionFee.selector);
        sub.initialize(whiteList, 0);
    }

    function test_SetSubscriptionFeeReceiverFailedWhenAddressZero() public {
        vm.prank(tx.origin);
        vm.expectRevert(AddressZero.selector);
        subscription.setSubscriptionFeeReceiver(address(0));
    }

    function test_SetSubscriptionFeeReceiverFailedWhenNotOwner() public {
        vm.prank(user);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        subscription.setSubscriptionFeeReceiver(makeAddr("newReceiver"));
    }

    function test_SetSubscriptionFee_Decrease_NoCap() public {
        vm.prank(tx.origin);
        subscription.setSubscriptionFee(50);
        assertEq(subscription.subscriptionFee(), 50);
    }

    function test_SetFeeDiscount_InvalidBps_Reverts() public {
        vm.prank(tx.origin);
        vm.expectRevert(InvalidFeeDiscount.selector);
        subscription.setFeeDiscount(10_001, block.timestamp, block.timestamp + 1 days);
    }

    function test_SetFeeDiscount_InvalidPeriod_Reverts() public {
        vm.prank(tx.origin);
        vm.expectRevert(InvalidFeeDiscountPeriod.selector);
        subscription.setFeeDiscount(100, block.timestamp + 1, block.timestamp);
    }

    function test_Subscribe_WithFeeDiscount_PaysLess() public {
        uint256 grossFee = subscription.subscriptionFee() * (10 ** mockStableCoin.decimals()) * 1;
        uint256 expectedFee = (grossFee * (10_000 - 1_000)) / 10_000;
        vm.prank(tx.origin);
        subscription.setFeeDiscount(1000, block.timestamp, block.timestamp + 365 days);
        deal(address(mockStableCoin), user, expectedFee);
        vm.prank(user);
        mockStableCoin.approve(address(subscription), expectedFee);
        vm.prank(user);
        subscription.subscribe(address(mockStableCoin), 1);
        assertEq(mockStableCoin.balanceOf(feeReceiver), expectedFee);
    }

    function test_Subscribe_AfterFeeDiscountWindow_FullPrice() public {
        uint256 grossFee = subscription.subscriptionFee() * (10 ** mockStableCoin.decimals()) * 1;
        vm.prank(tx.origin);
        subscription.setFeeDiscount(1000, block.timestamp, block.timestamp + 1 days);
        vm.warp(block.timestamp + 2 days);
        deal(address(mockStableCoin), user, grossFee);
        vm.prank(user);
        mockStableCoin.approve(address(subscription), grossFee);
        vm.prank(user);
        subscription.subscribe(address(mockStableCoin), 1);
        assertEq(mockStableCoin.balanceOf(feeReceiver), grossFee);
    }

    function test_SubscribeFailedWhenStableCoinNotWhiteListed() public {
        address invalidStableCoin = makeAddr("invalidStableCoin");
        uint256 fee = subscription.subscriptionFee() * (10 ** mockStableCoin.decimals()) * 1;
        deal(address(mockStableCoin), user, fee);
        vm.prank(user);
        mockStableCoin.approve(address(subscription), fee);
        vm.prank(user);
        vm.expectRevert(NotWhiteListed.selector);
        subscription.subscribe(invalidStableCoin, 1);
    }

    function test_SubscribeFailedWhenYearCountZero() public {
        uint256 fee = subscription.subscriptionFee() * (10 ** mockStableCoin.decimals()) * 1;
        deal(address(mockStableCoin), user, fee);
        vm.prank(user);
        mockStableCoin.approve(address(subscription), fee);
        vm.prank(user);
        vm.expectRevert(YearCountZero.selector);
        subscription.subscribe(address(mockStableCoin), 0);
    }

    function test_SubscribeFailedWhenBalanceNotEnough() public {
        uint256 fee = subscription.subscriptionFee() * (10 ** mockStableCoin.decimals()) * 1;
        deal(address(mockStableCoin), user, fee - 1);
        vm.prank(user);
        mockStableCoin.approve(address(subscription), fee - 1);
        vm.prank(user);
        vm.expectRevert(InsufficientBalance.selector);
        subscription.subscribe(address(mockStableCoin), 1);
    }

    function test_SubscribeSuccess() public {
        uint256 fee = subscription.subscriptionFee() * (10 ** mockStableCoin.decimals()) * 1;
        deal(address(mockStableCoin), user, fee);
        vm.prank(user);
        mockStableCoin.approve(address(subscription), fee);
        vm.prank(user);
        subscription.subscribe(address(mockStableCoin), 1);

        assertEq(subscription.getExpirationTime(user), block.timestamp + 365 days);
        assertEq(mockStableCoin.balanceOf(feeReceiver), fee);
        assertEq(mockStableCoin.balanceOf(user), 0);
    }

    function test_SubscribeSuccess_MultipleYears() public {
        uint8 yearCount = 2;
        uint256 fee = subscription.subscriptionFee() * (10 ** mockStableCoin.decimals()) * yearCount;
        deal(address(mockStableCoin), user, fee);
        vm.prank(user);
        mockStableCoin.approve(address(subscription), fee);
        vm.prank(user);
        subscription.subscribe(address(mockStableCoin), yearCount);

        assertEq(subscription.getExpirationTime(user), block.timestamp + 365 days * yearCount);
        assertEq(mockStableCoin.balanceOf(feeReceiver), fee);
        assertEq(mockStableCoin.balanceOf(user), 0);
    }

    function test_SubscribeSuccess_RenewalBeforeExpiry() public {
        uint256 fee = subscription.subscriptionFee() * (10 ** mockStableCoin.decimals()) * 1;
        deal(address(mockStableCoin), user, fee * 2);
        vm.prank(user);
        mockStableCoin.approve(address(subscription), fee * 2);
        vm.prank(user);
        subscription.subscribe(address(mockStableCoin), 1);

        uint256 expirationAfterFirst = subscription.getExpirationTime(user);
        vm.warp(block.timestamp + 100 days);

        vm.prank(user);
        subscription.subscribe(address(mockStableCoin), 1);

        assertEq(subscription.getExpirationTime(user), expirationAfterFirst + 365 days);
        assertEq(mockStableCoin.balanceOf(feeReceiver), fee * 2);
    }

    function test_SubscribeSuccess_AfterExpiry() public {
        uint256 fee = subscription.subscriptionFee() * (10 ** mockStableCoin.decimals()) * 1;
        deal(address(mockStableCoin), user, fee * 2);
        vm.prank(user);
        mockStableCoin.approve(address(subscription), fee * 2);
        vm.prank(user);
        subscription.subscribe(address(mockStableCoin), 1);

        vm.warp(block.timestamp + 366 days);

        vm.prank(user);
        subscription.subscribe(address(mockStableCoin), 1);

        assertEq(subscription.getExpirationTime(user), block.timestamp + 365 days);
        assertEq(mockStableCoin.balanceOf(feeReceiver), fee * 2);
    }

    function test_GetExpirationTime() public {
        assertEq(subscription.getExpirationTime(user), 0);

        uint256 fee = subscription.subscriptionFee() * (10 ** mockStableCoin.decimals()) * 1;
        deal(address(mockStableCoin), user, fee);
        vm.prank(user);
        mockStableCoin.approve(address(subscription), fee);
        vm.prank(user);
        subscription.subscribe(address(mockStableCoin), 1);

        assertEq(subscription.getExpirationTime(user), block.timestamp + 365 days);
    }

    function test_SubscribeSuccess_DifferentStableCoins() public {
        uint256 fee1 = subscription.subscriptionFee() * (10 ** mockStableCoin.decimals()) * 1;
        uint256 fee2 = subscription.subscriptionFee() * (10 ** mockStableCoin2.decimals()) * 1;
        deal(address(mockStableCoin), user, fee1);
        deal(address(mockStableCoin2), user, fee2);
        vm.prank(user);
        mockStableCoin.approve(address(subscription), fee1);
        vm.prank(user);
        mockStableCoin2.approve(address(subscription), fee2);

        vm.prank(user);
        subscription.subscribe(address(mockStableCoin), 1);
        vm.prank(user);
        subscription.subscribe(address(mockStableCoin2), 1);

        assertEq(mockStableCoin.balanceOf(feeReceiver), fee1);
        assertEq(mockStableCoin2.balanceOf(feeReceiver), fee2);
    }

    function test_GetSubscriptionInitCode() public pure {
        bytes memory bytecode = type(Subscription).creationCode;
        console.logBytes32(keccak256(bytecode));
    }
}
