// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./IERC20.sol";
import "./Fairlaunch.sol";
import "./InvestmentsInfo.sol";
import "./InvestmentsLiquidityLock.sol";

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

contract FairlaunchFactory {
    using SafeMath for uint256;

    event PresaleCreated(uint256 Id, address presalecontractaddress, address liquiditylockaddress);

    IUniswapV2Factory private constant QuickSwapFactory =
    IUniswapV2Factory(address(0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32));
    address private constant wmaticAddress = address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);

    InvestmentsInfo public immutable SSS;

    constructor(address _InfoAddress) public {
        SSS = InvestmentsInfo(_InfoAddress);
    }

    struct PresaleInfo {
        address tokenAddress;
        uint256 tokenQuantity;
        uint256 softCapInWei;
        uint256 openTime;
        uint256 closeTime;
    }

    struct PresaleUniswapInfo {
        uint256 lpTokensLockDurationInDays;
        uint256 liquidityPercentageAllocation;
    }

    // copied from https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/libraries/UniswapV2Library.sol
    // calculates the CREATE2 address for a pair without making any external calls
    function uniV2LibPairFor(
        address factory,
        address tokenA,
        address tokenB
    ) internal pure returns (address pair) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        pair = address(
            uint256(
                keccak256(
                    abi.encodePacked(
                        hex"ff",
                        factory,
                        keccak256(abi.encodePacked(token0, token1)),
                        hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f" // init code hash
                    )
                )
            )
        );
    }

    function initializeFairlaunch(
        Fairlaunch _flaunch,
        uint256 _totalTokens,
        uint256 _totalTokensinPool,
        PresaleInfo calldata _info,
        PresaleUniswapInfo calldata _uniInfo
    ) internal {
        _flaunch.setAddressInfo(msg.sender, _info.tokenAddress);
        _flaunch.setGeneralInfo(
            _totalTokens,
            _totalTokensinPool,
            _info.softCapInWei,
            _info.openTime,
            _info.closeTime
        );
        _flaunch.setUniswapInfo(
            _uniInfo.lpTokensLockDurationInDays,
            _uniInfo.liquidityPercentageAllocation
        );
    }

    function createPresale(
        PresaleInfo calldata _info,
        PresaleUniswapInfo calldata _uniInfo
    ) external //payable 
    {
        //require(msg.value == 2.5 ether, "msg.value less than 2.5 BNB. Send 2.5 BNB to create presale.");
        IERC20 token = IERC20(_info.tokenAddress);

        Fairlaunch flaunch = new Fairlaunch(address(this), SSS.owner());

        address existingPairAddress = QuickSwapFactory.getPair(address(token), wmaticAddress);
        require(existingPairAddress == address(0)); // token should not be listed in PancakeSwap

        //uint256 maxEthPoolTokenAmount = _info.hardCapInWei.mul(_uniInfo.liquidityPercentageAllocation).div(100);
        //uint256 maxLiqPoolTokenAmount = maxEthPoolTokenAmount.mul(1e18).div(_uniInfo.listingPriceInWei);

        uint256 maxTokensToBeSold = _info.tokenQuantity.mul(_uniInfo.liquidityPercentageAllocation).mul(95).div(10000);
        uint256 requiredTokenAmount = _info.tokenQuantity.add(maxTokensToBeSold);
        token.transferFrom(msg.sender, address(flaunch), requiredTokenAmount);

        initializeFairlaunch(flaunch, _info.tokenQuantity, maxTokensToBeSold, _info, _uniInfo);

        address pairAddress = uniV2LibPairFor(address(QuickSwapFactory), address(token), wmaticAddress);
        InvestmentsLiquidityLock liquidityLock = new InvestmentsLiquidityLock(
                IERC20(pairAddress),
                msg.sender,
                address(flaunch),
                _info.closeTime + (_uniInfo.lpTokensLockDurationInDays * 1 days)
            );

        uint256 Id = SSS.addPresaleAddress(address(flaunch));
        flaunch.setInfo(address(liquidityLock), Id);

        emit PresaleCreated(Id, address(flaunch), address(liquidityLock));
        //payable(SSS.owner()).transfer(msg.value);
    }
}
