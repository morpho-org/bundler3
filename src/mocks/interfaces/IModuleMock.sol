// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IBaseModule} from "../../interfaces/IBaseModule.sol";
import {Call} from "../../interfaces/IBundler.sol";

event Initiator(address);

event CurrentModule(address);

interface IModuleMock is IBaseModule {
    function isProtected() external payable;
    function doRevert(string memory reason) external pure;
    function emitInitiator() external;
    function callbackBundler(Call[] calldata calls) external;
    function callbackBundlerWithMulticall() external;
    function emitCurrentModule() external;
}
