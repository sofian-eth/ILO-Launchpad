// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./IERC20.sol";
import "./Ownable.sol";
import "./SSSlock.sol";
import "./SSSTimelock.sol";

contract SSSlockfactory is Ownable{

    struct info {
        address tokenAddress;
        address beneficiary;
        uint256 totaldays;
        uint256 quantity;
    }

    address[] private lockAddresses;

    function addlockAddress(address _presale) internal returns (uint256) {
        lockAddresses.push(_presale);
        return lockAddresses.length - 1;
    }

    function getlockCount() external view returns (uint256) {
        return lockAddresses.length;
    }

    function getlockAddress(uint256 Id) external view returns (address) {
        return lockAddresses[Id];
    }

    function createLock(info calldata _info) external payable{
        require(msg.value == 1 ether, "Not sufficient msg value. Please send 1 BNB");
        IERC20 token = IERC20(_info.tokenAddress);
        
        SSSlock tlock = new SSSlock(IERC20(_info.tokenAddress), msg.sender, block.timestamp + _info.totaldays * 1 days);

        token.transferFrom(msg.sender, address(tlock), _info.quantity);
        
        addlockAddress(address(tlock));
        
        payable(owner()).transfer(msg.value);
    }

}
