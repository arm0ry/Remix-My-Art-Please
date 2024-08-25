// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.24;

import "@forge/Test.sol";
import "@forge/console2.sol";
import "@solady/test/utils/mocks/MockERC6909.sol";

import {RemixToken, Curve} from "../src/RemixToken.sol";

contract RemixTokenTest is Test {
    RemixToken remix;

    /// @dev Users.
    address public immutable alice = payable(makeAddr("alice"));
    address public immutable bob = payable(makeAddr("bob"));
    address public immutable charlie = payable(makeAddr("charlie"));
    address public immutable david = payable(makeAddr("david"));
    address public immutable echo = payable(makeAddr("echo"));
    address public immutable fox = payable(makeAddr("fox"));

    /// @dev Constants.
    string internal constant NAME = "NAME";
    string internal constant SYMBOL = "SYMBOL";
    string internal constant WORK = "WORK";
    uint256 internal constant MAXSUPPLY = 100;
    uint64 internal constant SCALE = 0.0001 ether;
    bytes internal constant BYTES = "BYTES";

    /// @dev Reserves.
    string internal uri;

    /// -----------------------------------------------------------------------
    /// Kali Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.
    function setUp() public payable {
        vm.prank(alice);
        remix = new RemixToken(NAME, SYMBOL, WORK, MAXSUPPLY, SCALE, 2, 1, 0);
    }

    function test_Multi_TokenMix(uint256 layerId) public payable {
        vm.assume(remix.layerId() >= layerId);
        uint256 id;
        uri = remix.tokenURI(id);
        emit log_string(uri);

        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
        vm.deal(charlie, 1 ether);
        vm.deal(echo, 1 ether);
        vm.deal(fox, 1 ether);

        support(bob, layerId);
        id = tokenMix(bob, layerId, 10, 3, 2);
        emit log_uint(id);
        uri = remix.tokenURI(id);
        emit log_string(uri);

        support(charlie, id);
        id = tokenMix(charlie, id, 10, 3, 2);
        emit log_uint(id);
        uri = remix.tokenURI(id);
        emit log_string(uri);

        id = openMix(david, id, 10, 3, 2);
        emit log_uint(id);
        uri = remix.tokenURI(id);
        emit log_string(uri);

        support(echo, id);
        id = tokenMix(echo, id, 10, 3, 2);
        emit log_uint(id);
        uri = remix.tokenURI(id);
        emit log_string(uri);

        support(fox, id);
        id = tokenMix(fox, id, 10, 3, 2);
        emit log_uint(id);
        uri = remix.tokenURI(id);
        emit log_string(uri);

        support(alice, id);
        support(alice, id);
        support(alice, id);
        support(alice, id);
        support(alice, id);
        support(alice, id);
        support(alice, id);
    }

    function openMix(
        address user,
        uint256 layerId,
        uint32 constant_a,
        uint32 constant_b,
        uint32 constant_c
    ) public payable returns (uint256) {
        uint256 id = remix.layerId();

        vm.prank(user);
        remix.mix(
            layerId,
            NAME,
            SYMBOL,
            WORK,
            MAXSUPPLY,
            SCALE,
            constant_a,
            constant_b,
            constant_c
        );

        assertEq(remix.layerId(), ++id);
        return id;
    }

    function tokenMix(
        address user,
        uint256 layerId,
        uint32 constant_a,
        uint32 constant_b,
        uint32 constant_c
    ) public payable returns (uint256) {
        uint256 id = remix.layerId();

        vm.prank(user);
        remix.mixByToken(
            layerId,
            NAME,
            SYMBOL,
            WORK,
            MAXSUPPLY,
            SCALE,
            constant_a,
            constant_b,
            constant_c
        );

        assertEq(remix.layerId(), ++id);
        return id;
    }

    function support(address user, uint256 layerId) public payable {
        uint256 balance = remix.balanceOf(user, layerId);

        uint256 price = remix.calculatePrice(layerId);
        vm.prank(user);
        remix.support{value: price}(layerId);

        assertEq(remix.balanceOf(user, layerId), ++balance);
    }

    function test_TokenMix_InsufficientBalance() public payable {
        vm.expectRevert(ERC6909.InsufficientBalance.selector);
        vm.prank(charlie);
        remix.mixByToken(0, NAME, SYMBOL, WORK, MAXSUPPLY, SCALE, 10, 3, 5);
    }

    function testReceiveETH() public payable {
        (bool sent, ) = address(remix).call{value: 5 ether}("");
        assert(!sent);
    }
}
