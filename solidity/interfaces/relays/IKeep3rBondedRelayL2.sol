// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {IKeep3rRelayL2} from './IKeep3rRelayL2.sol';
import {IKeep3rBondedRelay} from './IKeep3rBondedRelay.sol';

interface IKeep3rBondedRelayL2 is IKeep3rRelayL2, IKeep3rBondedRelay {}
