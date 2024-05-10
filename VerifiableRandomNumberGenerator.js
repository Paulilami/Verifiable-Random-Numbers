import React, { useState, useEffect } from 'react';
import Web3 from 'web3';
import abi from '/VerifiableRandomNumberGeneratorABI.json';

const web3 = new Web3(window.ethereum);

const VerifiableRandomNumberGenerator = () => {
  const [contractAddress, setContractAddress] = useState(''); 
  const [walletAddress, setWalletAddress] = useState('');
  const [seed, setSeed] = useState('');
  const [nonce, setNonce] = useState('');
  const [commitment, setCommitment] = useState('');
  const [randomNumber, setRandomNumber] = useState('');
  const [merkleProof, setMerkleProof] = useState([]);
  const [requestId, setRequestId] = useState('');

  useEffect(() => {
    const contract = new web3.eth.Contract(abi, contractAddress);
    contract.events.RandomnessRequestCommitted({}, (error, event) => {
      if (!error) {
        setRequestId(event.returnValues.requestId);
      }
    });
    contract.events.RandomnessRequestRevealed({}, (error, event) => {
      if (!error) {
        setRandomNumber(event.returnValues.randomNumber);
      }
    });
  }, [contractAddress]);

  const handleCommitRandomNumber = async () => {
    const contract = new web3.eth.Contract(abi, contractAddress);
    const method = '-SECRET-'; //blurred
    const txCount = await web3.eth.getTransactionCount(walletAddress);
    const tx = {
      from: walletAddress,
      to: contractAddress,
      value: '0',
      gas: '200000',
      gasPrice: web3.utils.toWei('20', 'gwei'),
      nonce: web3.utils.toHex(txCount),
      data: contract.methods.commitRandomNumber(seed, nonce, commitment, method).encodeABI(),
    };
    await web3.eth.sendTransaction(tx);
  };

  const handleRevealRandomNumber = async () => {
    const contract = new web3.eth.Contract(abi, contractAddress);
    const txCount = await web3.eth.getTransactionCount(walletAddress);
    const tx = {
      from: walletAddress,
      to: contractAddress,
      value: '0',
      gas: '200000',
      gasPrice: web3.utils.toWei('20', 'gwei'),
      nonce: web3.utils.toHex(txCount),
      data: contract.methods.revealRandomNumber(seed, nonce, randomNumber, merkleProof).encodeABI(),
    };
    await web3.eth.sendTransaction(tx);
  };

  return (
    <div>
      <h1>Verifiable Random Number Generator</h1>
      <form>
        <label>Wallet Address:</label>
        <input type="text" value={walletAddress} onChange={(e) => setWalletAddress(e.target.value)} />
        <br />
        <label>Seed:</label>
        <input type="number" value={seed} onChange={(e) => setSeed(e.target.value)} />
        <br />
        <label>Nonce:</label>
        <input type="number" value={nonce} onChange={(e) => setNonce(e.target.value)} />
        <br />
        <label>Commitment:</label>
        <input type="text" value={commitment} onChange={(e) => setCommitment(e.target.value)} />
        <br />
        <button onClick={handleCommitRandomNumber}>Commit Random Number</button>
        <br />
        <label>Random Number:</label>
        <input type="number" value={randomNumber} onChange={(e) => setRandomNumber(e.target.value)} />
        <br />
        <label>Merkle Proof:</label>
        <input type="text" value={merkleProof} onChange={(e) => setMerkleProof(e.target.value.split(','))} />
        <br />
        <button onClick={handleRevealRandomNumber}>Reveal Random Number</button>
      </form>
      <p>Request ID: {requestId}</p>
      <p>Random Number: {randomNumber}</p>
    </div>
  );
};

export default VerifiableRandomNumberGenerator;
