// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import {RealityETH_v3_0} from "../staticlib/RealityETH-3.0.sol";

contract KaiSign {
    uint256 public minBond;
    address public realityETH;
    address public arbitrator;
    uint256 public templateId;
    uint32 public timeout;

    enum Status {
        Submitted,
        Accepted,
        Rejected
    }

    struct ERC7730Spec {
        uint64 createdTimestamp;
        Status status;
        string ipfs;
        bytes32 questionId;
    }

    constructor(address _realityETH, address _arbitrator, uint256 _minBond, uint32 _timeout) {
        realityETH = _realityETH;
        arbitrator = _arbitrator;
        minBond = _minBond;
        timeout = _timeout;
        templateId =
            RealityETH_v3_0(realityETH).createTemplate('{"title": "Is the ERC7730 spec %s correct?", "type": "bool"}');
    }

    mapping(bytes32 => ERC7730Spec) public specs;

    function createSpec(string calldata ipfs) external {
        bytes32 specID = keccak256(bytes(ipfs));
        require(specs[specID].createdTimestamp == 0, "Already proposed");
        specs[specID] = ERC7730Spec(uint64(block.timestamp), Status.Submitted, ipfs, bytes32(0));
    }

    function proposeSpecByHash(bytes32 specID) public payable {
        require(specs[specID].createdTimestamp > 0, "Not proposed yet");
        bytes32 questionId = RealityETH_v3_0(realityETH).askQuestionWithMinBond(
            templateId, specs[specID].ipfs, arbitrator, timeout, 0, 0, minBond
        );
        specs[specID].questionId = questionId;
        // Put in the first answer with a bond
        // Any subsequent challenges can happen in the oracle app
        RealityETH_v3_0(realityETH).submitAnswerFor{value: msg.value}(questionId, bytes32(uint256(1)), 0, msg.sender);
    }

    function proposeSpec(string calldata ipfs) external payable {
        proposeSpecByHash(keccak256(bytes(ipfs)));
    }

    function handleResultByHash(bytes32 specID) public {
        // This will revert if it's not complete yet
        bytes32 result = RealityETH_v3_0(realityETH).resultFor(specs[specID].questionId);
        specs[specID].status = (uint256(result) == uint256(1)) ? Status.Accepted : Status.Rejected;
    }

    function handleResult(string calldata ipfs) external {
        handleResultByHash(keccak256(bytes(ipfs)));
    }

    function getCreatedTimestamp(bytes32 id) external view returns (uint64) {
        return specs[id].createdTimestamp;
    }

    function getStatus(bytes32 id) external view returns (Status) {
        return specs[id].status;
    }

    function getIPFS(bytes32 id) external view returns (string memory) {
        return specs[id].ipfs;
    }

    function getQuestionId(bytes32 id) external view returns (bytes32) {
        return specs[id].questionId;
    }

    function isAcceptedByHash(bytes32 id) external view returns (bool) {
        return specs[id].status == Status.Accepted;
    }

    function isAccepted(string calldata ipfs) external view returns (bool) {
        bytes32 id = keccak256(bytes(ipfs));
        return specs[id].status == Status.Accepted;
    }
}
