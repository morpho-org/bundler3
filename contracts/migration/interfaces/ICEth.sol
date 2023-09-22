// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.6.2;

interface ICEth {
    function repayBorrowBehalf(address borrower) external payable;

    function balanceOf(address) external view returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function redeem(uint256 redeemTokens) external returns (uint256);

    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

    function borrow(uint256 borrowAmount) external returns (uint256);

    function mint() external payable;
}
