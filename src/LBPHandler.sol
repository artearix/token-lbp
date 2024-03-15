// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IVault, IAsset} from "balancer/interfaces/contracts/vault/IVault.sol";
import {IRouter} from "./interfaces/IRouter.sol";
import {IERC20} from "balancer/interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {ILBPFactory, ILBP} from "./interfaces/ILBPFactory.sol";
import {WeightedPoolUserData} from "balancer/interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

contract LBPHandler is Ownable {
    IVault public vault;
    IRouter public router;
    ILBPFactory public lbpFactory;
    IERC20 public tokenA;
    IERC20 public tokenB;
    address public pool;
    bytes32 public poolId;
    address public lpReceiver;

    bool public created = false;

    uint256 public endTime;

    constructor (IRouter _router, ILBPFactory _lbpFactory, address _lpReceiver, IERC20 _tokenA, IERC20 _tokenB) Ownable(msg.sender) {
        vault = IVault(ILBPFactory(_lbpFactory).getVault());
        router = _router;
        lbpFactory = _lbpFactory;
        lpReceiver = _lpReceiver;
        if (address(_tokenA) > address(_tokenB)) {
            (tokenA, tokenB) = (_tokenB, _tokenA);
        } else {
            (tokenA, tokenB) = (_tokenA, _tokenB);
        }
    }

    function createLBP(uint256 _startTime, uint256 _endTime) external onlyOwner returns (address) {
        require(!created, "LBPHandler: already created");

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = tokenA;
        tokens[1] = tokenB;

        uint256[] memory weights = new uint256[](2);
        weights[0] = 0.8 ether;
        weights[1] = 0.2 ether;

        uint256[] memory endWeights = new uint256[](2);
        endWeights[0] = 0.5 ether;
        endWeights[1] = 0.5 ether;

        pool = lbpFactory.create(
            "TOKEN LBP",
            "TOKEN/FTM 50/50",
            tokens,
            weights,
            1e12,
            address(this),
            false
        );
        poolId = ILBP(pool).getPoolId();

        IAsset[] memory assets = new IAsset[](2);
        assets[0] = IAsset(address(tokenA));
        assets[1] = IAsset(address(tokenB));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = tokenA.balanceOf(address(this));
        amounts[1] = tokenB.balanceOf(address(this));

        bytes memory userData = abi.encode(WeightedPoolUserData.JoinKind.INIT, amounts, 0);

        tokenA.approve(address(vault), amounts[0]);
        tokenB.approve(address(vault), amounts[1]);
        IVault(vault).joinPool(
            poolId,
            address(this), // sender
            address(this), // recipient
            IVault.JoinPoolRequest(assets, amounts, userData, false)
        );

        ILBP(pool).updateWeightsGradually(_startTime, _endTime, endWeights);

        endTime = _endTime;
        created = true;
        return pool;
    }

    function enableSwap() onlyOwner external {
        require(created, "LBPHandler: pool not created yet");
        ILBP(pool).setSwapEnabled(true);
    }

    function finishLBP() onlyOwner external {
        require(block.timestamp >= endTime, "LBPHandler: LBP not finished yet");

        uint256 amt = IERC20(pool).balanceOf(address(this));
        
        IAsset[] memory assets = new IAsset[](2);
        assets[0] = IAsset(address(tokenA));
        assets[1] = IAsset(address(tokenB));

        uint256[] memory minAmountsOut = new uint256[](2);
        minAmountsOut[0] = 0;
        minAmountsOut[1] = 0;

        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest({
            assets: assets,
            minAmountsOut: minAmountsOut,
            userData: abi.encode(WeightedPoolUserData.ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT, amt),
            toInternalBalance: false
        });
        
        vault.exitPool(
            poolId,
            address(this),
            payable(address(this)),
            request
        );

        uint256 amountA = IERC20(tokenA).balanceOf(address(this));
        uint256 amountB = IERC20(tokenB).balanceOf(address(this));

        // handle the tokens
        tokenA.approve(address(router), amountA);
        tokenB.approve(address(router), amountB);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            false,
            amountA,
            amountB,
            0,
            0,
            lpReceiver,
            block.timestamp
        );
    }
}
