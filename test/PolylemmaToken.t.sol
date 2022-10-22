pragma solidity 0.8.13;

import "forge-std/Test.sol";
import {PolylemmaToken} from "../src/PolylemmaToken.sol";
import {IPolylemmaSeeder} from "./interfaces/IPolylesSeeder.sol";
import {IPolylemmaData} from "./interfaces/IPolylemmaData.sol";

contract PolylemmaTokenTest is Test {
    PolylemmaToken token;
    IPolylemmaSeeder seeder;
    I
    address iseeder = 0x0000000000000000000000000000000000000001;
    address idata = 0x0000000000000000000000000000000000000002;


    function setUp() public {
        token = new PolylemmaToken(msg.sender,);
    }

    function testFailMintByNonMMiner() public {
        vm.prank(address(0));
    }
}
