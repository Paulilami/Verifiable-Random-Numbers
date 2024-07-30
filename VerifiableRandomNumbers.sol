// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract VerifiableRandomNumberGenerator is Ownable {
    using ECDSA for bytes32;
    using MerkleProof for bytes32[];
    using Counters for Counters.Counter;

    uint256 private constant MAX_NONCE = 2**256 - 1;
    
     enum SeedGenerationMethod {
        UserProvidedSeed,
        SystemEntropy,
        CombinedSeed
    }

    struct RandomnessRequest {
        address participant;
        uint256 seed;
        uint256 nonce;
        bytes32 commitment;
        bool revealed;
        bytes32[] merkleProof;
    }

    mapping(bytes32 => RandomnessRequest) public randomnessRequests;
    mapping(bytes32 => bool) public usedCommits;
    Counters.Counter private requestIdCounter;

    event RandomnessRequestCommitted(bytes32 indexed requestId, address indexed participant, bytes32 indexed commitment);
    event RandomnessRequestRevealed(bytes32 indexed requestId, uint256 randomNumber);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event AssetVerified(address indexed participant, address indexed assetAddress, bool verified);
    event SeedGenerated(address indexed participant, uint256 seed);
    event NonceGenerated(address indexed participant, uint256 nonce);

    modifier validSeed(uint256 seed) {
        require(seed != 0, "Seed cannot be zero");
        _;
    }

    modifier validNonce(uint256 nonce) {
        require(nonce <= MAX_NONCE, "Nonce exceeds maximum value");
        _;
    }

    modifier uniqueCommitment(bytes32 commitment) {
        require(!usedCommits[commitment], "Commitment already used");
        _;
    }

    function commitRandomNumber(uint256 seed, uint256 nonce, bytes32 commitment, SeedGenerationMethod method) external validSeed(seed) validNonce(nonce) uniqueCommitment(commitment) {
        uint256 generatedSeed = generateSeed(address(this), msg.sender, method, seed);
        bytes32 requestId = bytes32(requestIdCounter.current());
        requestIdCounter.increment();
        randomnessRequests[requestId] = RandomnessRequest(msg.sender, seed, nonce, commitment, false, new bytes32[](0));
        usedCommits[commitment] = true;
        emit RandomnessRequestCommitted(requestId, msg.sender, commitment);
    }

    function revealRandomNumber(uint256 seed, uint256 nonce, uint256 randomNumber, bytes32[] memory merkleProof) external {
        bytes32 requestId = keccak256(abi.encodePacked(msg.sender, seed, nonce));
        RandomnessRequest storage request = randomnessRequests[requestId];
        require(!request.revealed, "Randomness already revealed");
        require(request.participant == msg.sender, "Unauthorized");
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, seed, nonce, randomNumber));
        require(leaf.verify(request.commitment, merkleProof), "Invalid proof");
        request.revealed = true;
        request.merkleProof = merkleProof;
        emit RandomnessRequestRevealed(requestId, randomNumber);
    }

    function verifyRandomNumber(bytes32 requestId, uint256 randomNumber) external view returns (bool) {
        RandomnessRequest memory request = randomnessRequests[requestId];
        require(request.revealed, "Randomness not revealed");
        bytes32 leaf = keccak256(abi.encodePacked(request.participant, request.seed, request.nonce, randomNumber));
        return leaf.verify(request.commitment, request.merkleProof);
    }

    function verifyAsset(address assetAddress) internal view returns (bool) {
      //placeholder
    }

    function generateSeed(address address1, address address2, SeedGenerationMethod method, uint256 userProvidedSeed) internal view returns (uint256) {
        if (method == SeedGenerationMethod.UserProvidedSeed) {
            return userProvidedSeed;
        } else if (method == SeedGenerationMethod.SystemEntropy) {
            return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty)));
        } else if (method == SeedGenerationMethod.CombinedSeed) {
            return uint256(keccak256(abi.encodePacked(address1, address2, block.timestamp, block.difficulty, userProvidedSeed)));
        } else {
            revert("Invalid seed generation method");
        }
    }

    function secureHash(bytes memory data) internal view returns (bytes32) {
        return keccak512(data);
    }

    function generateNonce() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.number, block.timestamp, msg.sender)));
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_msgSender(), newOwner);
        _transferOwnership(newOwner);
    }

    enum CommitmentAlgorithm {
        HashCommitment,
        CryptographicCommitment,
        CustomCommitment
    }

    struct Commitment {
        address[] participants;
        uint256[] parameters;
        uint256 validityPeriod;
        CommitmentAlgorithm algorithm;
        bytes32 commitment;
        bool used;
    }

    mapping(bytes32 => Commitment) public commitments;

    event CommitmentCreated(bytes32 indexed commitmentId, address[] participants, uint256[] parameters, uint256 validityPeriod, CommitmentAlgorithm algorithm, bytes32 commitment);
    event CommitmentUsed(bytes32 indexed commitmentId);
    event CommitmentExpired(bytes32 indexed commitmentId);

    modifier commitmentNotUsed(bytes32 commitmentId) {
        require(!commitments[commitmentId].used, "Commitment already used");
        _;
    }

    modifier commitmentNotExpired(bytes32 commitmentId) {
        require(block.timestamp <= commitments[commitmentId].validityPeriod, "Commitment expired");
        _;
    }

    function createCommitment(
        address[] memory participants,
        uint256[] memory parameters,
        uint256 validityPeriod,
        CommitmentAlgorithm algorithm
    ) external {
        bytes32 commitmentId = keccak256(abi.encodePacked(participants, parameters, validityPeriod, algorithm, block.timestamp));
        commitments[commitmentId] = Commitment(participants, parameters, block.timestamp + validityPeriod, algorithm, bytes32(0), false);
        emit CommitmentCreated(commitmentId, participants, parameters, validityPeriod, algorithm, bytes32(0));
    }

    function useCommitment(bytes32 commitmentId, bytes32 commitment) external commitmentNotUsed(commitmentId) commitmentNotExpired(commitmentId) {
        commitments[commitmentId].commitment = commitment;
        commitments[commitmentId].used = true;
        emit CommitmentUsed(commitmentId);
    }

   function expireExpiredCommitments(bytes32[] calldata commitmentIds) external {
        for (uint256 i = 0; i < commitmentIds.length; i++) {
            bytes32 commitmentId = commitmentIds[i];
            if (commitments[commitmentId].validityPeriod < block.timestamp && !commitments[commitmentId].used) {
                expireCommitment(commitmentId);
    }
}
