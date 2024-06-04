// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from 'openzeppelin/token/ERC20/utils/SafeERC20.sol';

import {IOpsProxyFactory} from '../../interfaces/external/IOpsProxyFactory.sol';
import {IKeep3rV2} from '../../interfaces/external/IKeep3rV2.sol';
import {IKeep3rV1} from '../../interfaces/external/IKeep3rV1.sol';
import {IKeep3rHelper} from '../../interfaces/external/IKeep3rHelper.sol';
import {IAutomate} from '../../interfaces/external/IAutomate.sol';

address constant _KEEP3R_GOVERNOR = 0x0D5Dc686d0a2ABBfDaFDFb4D0533E886517d4E83;
address constant _KEEP3R_GOVERNOR_OP = 0x7d6daDb31dBeBc68c8A0b2cCfE5C1f26F24bD41d;

address constant _KP3R_WHALE = 0x2FC52C61fB0C03489649311989CE2689D93dC1a2;
address constant _DAI_WHALE = 0xDE228965da0d064b8aE171A02500602e84E8330d;
address constant _DAI_WHALE_OP = 0x1eED63EfBA5f81D95bfe37d82C8E736b974F477b;

address constant _NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

IERC20 constant _DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
IERC20 constant _DAI_OP = IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);

IOpsProxyFactory constant _OPS_PROXY_FACTORY = IOpsProxyFactory(0x44bde1bccdD06119262f1fE441FBe7341EaaC185);
IAutomate constant _AUTOMATE = IAutomate(0x2A6C106ae13B558BB9E2Ec64Bd2f1f7BEFF3A5E0);
IKeep3rV2 constant _KEEP3R_V2 = IKeep3rV2(0xeb02addCfD8B773A5FFA6B9d1FE99c566f8c44CC);
IKeep3rV1 constant _KEEP3R_V1 = IKeep3rV1(0x1cEB5cB57C4D4E2b2433641b95Dd330A33185A44);
IKeep3rHelper constant _KEEP3R_HELPER = IKeep3rHelper(0xeDDe080E28Eb53532bD1804de51BD9Cd5cADF0d4);

IAutomate constant _AUTOMATE_OP = IAutomate(0x2A6C106ae13B558BB9E2Ec64Bd2f1f7BEFF3A5E0);
IKeep3rV2 constant _KEEP3R_V2_OP = IKeep3rV2(0x745a50320B6eB8FF281f1664Fc6713991661B129);
IKeep3rV1 constant _KEEP3R_V1_OP = IKeep3rV1(0xca87472DBfB041c2e5a2672d319eA6184Ad9755e);
IKeep3rHelper constant _KEEP3R_HELPER_OP = IKeep3rHelper(0x832accE332B81262C028B2F800D1D53C8aEE12f4);
