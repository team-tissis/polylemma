// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import "./subcontracts/TestUtils.sol";

contract PLMTokenTest is Test, TestUtils {
    /////////////////////////////
    //   utilities for test   ///
    /////////////////////////////
    address user = address(11);
    uint256 maticForEx = 100000 ether;

    function setUp() public {
        ///@dev initializing contracts, interfaces and some parameters for test
        initializeTest();

        // initial mint of PLM
        uint256 ammount = 100000000000000;
        vm.prank(polylemmer);
        dealer.mintAdditionalCoin(ammount);

        // send ether to user address
        vm.deal(user, 10000000 ether);
        // (user)  charge MATIC and get PLMcoin
        vm.prank(user);
        dealer.charge{value: maticForEx}();
    }

    // utils
    function _mintTokensByDealer(uint256 numMint) internal {
        vm.startPrank(address(dealer));
        for (uint256 i = 0; i < numMint; i++) {
            token.mint("test-mon1");
        }
        vm.stopPrank();
    }

    function _packCharInfo(PLMToken.CharacterInfo memory _charInfo)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    _charInfo.level,
                    _charInfo.rarity,
                    _charInfo.characterTypeId,
                    _charInfo.imgId,
                    _charInfo.fromBlock,
                    _charInfo.attributeIds,
                    _charInfo.name
                )
            );
    }

    function testMint() public {
        uint256 tokenId = 1;
        bytes32 monsterName = "test-mon";
        // check impl. of first checkpoint created by mint
        vm.startPrank(address(dealer));
        token.mint(monsterName);
        assertEq(
            token.ownerOf(tokenId),
            address(dealer),
            "Owner initializing is wrong"
        );
        assertEq(
            token.getCurrentCharacterInfo(tokenId).level,
            1,
            "Invalid level initializing"
        );
        assertEq(
            keccak256(
                abi.encodePacked(token.getCurrentCharacterInfo(tokenId).name)
            ),
            keccak256(abi.encodePacked(monsterName)),
            "Invalid name initializing"
        );
    }

    function testUpdateLevel() public {
        // mint new PLMToken
    }

    function testLevelUpWithCheckPoint() public {
        uint256 tokenId = 1;

        vm.startPrank(user);
        // gacha
        coin.approve(address(dealer), dealer.getGachaFee());
        dealer.gacha("test-mon");

        // level Up
        coin.approve(address(token), token.getNecessaryExp(tokenId));
        token.updateLevel(tokenId);

        assertEq(token.getCurrentCharacterInfo(tokenId).level, 2);
    }

    function testGetPriorCheckPoint() public {
        uint256 tokenId = 1;

        vm.startPrank(user);
        // gacha
        coin.approve(address(dealer), dealer.getGachaFee());
        dealer.gacha("test-mon");

        // level Up
        currentBlock++;
        vm.roll(currentBlock);
        coin.approve(address(token), token.getNecessaryExp(tokenId));
        token.updateLevel(tokenId);

        assertEq(
            token.getPriorCharacterInfo(tokenId, currentBlock - 1).level,
            1
        );
        assertEq(token.getCurrentCharacterInfo(tokenId).level, 2);
    }

    function testUpdatelevelSeveralTime() public {
        uint256 tokenId = 1;

        vm.startPrank(user);
        // gacha
        coin.approve(address(dealer), dealer.getGachaFee());
        dealer.gacha("test-mon");

        // level Up
        currentBlock++;
        vm.roll(currentBlock);
        for (uint256 i = 0; i < 10; i++) {
            coin.approve(address(token), token.getNecessaryExp(tokenId));
            token.updateLevel(tokenId);
        }
    }

    function testImgURI() public {
        uint256 imgId = 1;
        string memory imgURI = token.getImgURI(imgId);
        console.log(imgURI);
    }

    function testTokenURI() public {
        uint256 tokenId = 1;
        vm.startPrank(user);
        coin.approve(address(dealer), dealer.getGachaFee());
        dealer.gacha("test-mon");

        // Level up and show tokenURI
        string memory tokenURI = token.tokenURI(tokenId);
        console.log(tokenURI);

        // Level up and show tokenURI
        coin.approve(address(token), token.getNecessaryExp(tokenId));
        token.updateLevel(tokenId);
        string memory tokenURI2 = token.tokenURI(tokenId);
        console.log(tokenURI2);

        // Level up and show tokenURI
        coin.approve(address(token), token.getNecessaryExp(tokenId));
        token.updateLevel(tokenId);
        string memory tokenURI3 = token.tokenURI(tokenId);
        console.log(tokenURI3);
    }

    ////////////////////////
    ///      GETTERS     ///
    ////////////////////////
    function testGetAllTokenOwned() public {
        _mintTokensByDealer(3);

        uint256[] memory validTokensOwned = new uint256[](3);
        validTokensOwned[0] = 1;
        validTokensOwned[1] = 2;
        validTokensOwned[2] = 3;

        assertEq(
            validTokensOwned,
            token.getAllTokenOwned(address(dealer)),
            "Invalid tokens"
        );
    }

    function testGetAllCharacterInfo() public {
        _mintTokensByDealer(3);

        PLMToken.CharacterInfo[]
            memory validCharacterInfos = new PLMToken.CharacterInfo[](3);

        validCharacterInfos[0] = token.getCurrentCharacterInfo(1);
        validCharacterInfos[1] = token.getCurrentCharacterInfo(2);
        validCharacterInfos[2] = token.getCurrentCharacterInfo(3);

        // TODO: 構造体をそのままkeccakできない。for loopは避けられない？？
        for (uint256 i = 0; i < 3; i++) {
            assertEq(
                _packCharInfo(validCharacterInfos[i]),
                _packCharInfo(token.getAllCharacterInfo()[i]),
                "Invalid characterInfos"
            );
        }
    }

    function testGetElapsedFromBlock() public {
        vm.roll(1);
        _mintTokensByDealer(1);

        uint256 tokenId = 1;

        vm.roll(5);
        assertEq(token.getElapsedFromBlock(tokenId), 5 - 1);
    }

    function testGetNecessaryExp() public {
        _mintTokensByDealer(1);
        uint256 tokenId = 1;

        IPLMData.CharacterInfoMinimal memory charInfoMinimal = IPLMData
            .CharacterInfoMinimal(1, 1, [1], 1);
        assertEq(charInfoMinimal.level**2, token.getNecessaryExp(tokenId));
    }

    function testGetDealer() public {
        assertEq(address(dealer), token.getDealer());
    }

    // TODO: have not implemented enough test yet
    function testGetCurrentCharacterInfo() public {
        _mintTokensByDealer(1);
        PLMToken.CharacterInfo memory charInfo = token.getCurrentCharacterInfo(
            1
        );

        console.log("level:%s,", charInfo.level);
        // "level:%s, rarity:%s, characterTypeId:%s, imgId:%s, fromBlock:%s, attributeId:%s, name:%s",
    }

    // TODO: have not implemented yet
    function testGetPriorCharacterInfo() public {
        _mintTokensByDealer(1);
        // PLMToken.CharacterInfo memory charInfo = token.getPriorCharacterInfo(
        //     1,
        //     1
        // );
    }

    function testGetImgURI() public {
        string
            memory imgURI = "https://raw.githubusercontent.com/team-tissis/polylemma-img/main/images/1.png";
        assertEq(
            keccak256(abi.encodePacked(imgURI)),
            keccak256(abi.encodePacked(token.getImgURI(1)))
        );
    }

    // TODO: need debug
    // totalSupply を-1した値が返ってきてしまう
    // function testGetPriorTotalSupply() public {
    //     vm.roll(2);
    //     _mintTokensByDealer(3);
    //     console.log(token.balanceOf(address(dealer)));
    //     assertEq(token.getPriorTotalSupply(2), 3);
    // }

    function testGetNumImg() public {
        assertEq(38, token.getNumImg());
    }

    function testGetDataAddress() public {
        assertEq(address(dataContract), token.getDataAddr());
    }
}
