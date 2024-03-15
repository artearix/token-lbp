// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {IERC20} from "balancer/interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {LBPHandler} from "../src/LBPHandler.sol";
import {ILBPFactory} from "../src/interfaces/ILBPFactory.sol";
import {IRouter} from "../src/interfaces/IRouter.sol";

contract HandlerTest is Test {
    uint256 fantomFork;
    MockERC20 tokenA;
    MockERC20 tokenB;

    ILBPFactory lbpFactory = ILBPFactory(0x2C774732c93CE393eC8125bDA49fb3737Ae6F473);
    IRouter router = IRouter(0x33da53f731458d6Bc970B0C5FCBB0b3Db4AAa470);

    LBPHandler lbpHandler;

    function setUp() public {
        fantomFork = vm.createFork(vm.envString("FTM_RPC"));
        vm.selectFork(fantomFork);

        tokenA = new MockERC20("Token", "TKN");
        tokenB = new MockERC20("USDC", "USDC");

        lbpHandler = new LBPHandler(
            router,
            lbpFactory,
            address(this),
            IERC20(address(tokenA)),
            IERC20(address(tokenB))
        );
    }

    function test_works() public {
        tokenA.mint(address(lbpHandler), 8 ether);
        tokenB.mint(address(lbpHandler), 2 ether);

        address pool = lbpHandler.createLBP(block.timestamp, block.timestamp + 1 days);
        lbpHandler.enableSwap();

        vm.expectRevert("LBPHandler: LBP not finished yet");
        lbpHandler.finishLBP();

        vm.warp(block.timestamp + 1 days);

        emit log_named_decimal_uint("BPT balance of handler before", IERC20(pool).balanceOf(address(lbpHandler)), 18);

        lbpHandler.finishLBP();

        emit log_named_decimal_uint("BPT balance of handler after", IERC20(pool).balanceOf(address(lbpHandler)), 18);

        address newPair = router.pairFor(address(tokenA), address(tokenB), false);

        emit log_named_decimal_uint("receiver's balance of new lp tokens", IERC20(newPair).balanceOf(address(this)), 18);
        emit log_named_decimal_uint("new pair's balance A", tokenA.balanceOf(newPair), 18);
        emit log_named_decimal_uint("new pair's balance B", tokenB.balanceOf(newPair), 18);
    }
}
