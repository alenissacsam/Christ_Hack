// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./OrganizationLogic.sol";
import "./OrganizationView.sol";

contract OrganizationRegistryProxy is OrganizationLogic, OrganizationView {
    function initializeAll(address certificateManager_, address verificationLogger_, address trustScore_)
        external
        initializer
    {
        OrganizationLogic.initializeLogic(certificateManager_, trustScore_, verificationLogger_);
    }
}
