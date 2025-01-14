// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface IStEth {
    function sharesOf(address _account) external view returns (uint256);

    function transferShares(address _recipient, uint256 _sharesAmount) external returns (uint256);

    function getPooledEthByShares(uint256 _sharesAmount) external view returns (uint256);

    function getSharesByPooledEth(uint256 _stEthAmount) external view returns (uint256);

    function getCurrentStakeLimit() external view returns (uint256);

    function submit(address _referral) external payable returns (uint256);

    function transfer(address _recipient, uint256 _amount) external returns (bool);
}
