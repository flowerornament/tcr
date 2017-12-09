pragma solidity ^0.4.17;
import '../installed_contracts/zeppelin/contracts/token/ERC20.sol';

contract TCR {

  // A mapping of statement hashes to statements and their metadata
  mapping(bytes32 => Entry) whitelist;
  struct Entry {
    string statement;
    address statementOwner;
    uint256 dateAdded;
    uint256 dateChallenged;
    address challenger;
    bool challengerPaid;
    bool exists;
    mapping(address => Vote) votes;
    address[] votesArray;
    uint256 votesYes;
    uint256 votesNo;
  }

  struct Vote {
    uint256 amount;
    bool dispensed;
    bool vote;
    bool exists;
  }

  // Array of keys to whitelist for iteration
  bytes32[] whitelistKeys;

  // Parameters
  uint256 waitPeriod = 60 * 60 * 48;
  uint256 challengePeriod = 60 * 60 * 24;
  uint8 applicationDeposit = 5;
  uint8 challengeDeposit = 5;
  ERC20 token;
  
  uint dispensionPct = 50;


  // Constructor
  function TCR (address tokenAddress) {
    token = ERC20(tokenAddress);
  }

  // Check whether a statement is approved
  function isApproved (bytes32 statementHash) public constant returns(bool approved) {
    if (!whitelist[statementHash].exists) return false;
    if (isChallenged(statementHash)) return false;
    if (whitelist[statementHash].dateAdded + waitPeriod >= now) return false; // TK
    return true;
  }

  // Apply to add a statement to the whitelist
  function applyToList (string statement) public {
    if (token.allowance(msg.sender, address(this)) < applicationDeposit) revert();
    if (token.balanceOf(msg.sender) < applicationDeposit) revert();
    if (!token.transferFrom(msg.sender, address(this), applicationDeposit)) revert();

    bytes32 statementHash = sha3(statement);
    whitelist[statementHash].exists = true;
    whitelist[statementHash].dateAdded = now;
    whitelist[statementHash].statement = statement;
    whitelist[statementHash].statementOwner = msg.sender;

    whitelistKeys.push(statementHash); // index mapping
  }

  function getListLength () public constant returns (uint256) {
    return whitelistKeys.length;
  }

  function getList (uint8 index) public constant returns (bytes32, string, address, uint256, uint256, address, bool) {
    bytes32 statementHash = whitelistKeys[index];
    return (statementHash,
            whitelist[statementHash].statement,
            whitelist[statementHash].statementOwner,
            whitelist[statementHash].dateAdded,
            whitelist[statementHash].dateChallenged,
            whitelist[statementHash].challenger,
            whitelist[statementHash].exists
    );
  }

  // 
  function isChallenged (bytes32 statementHash) public constant returns (bool) {
    return (whitelist[statementHash].dateChallenged + challengePeriod) > now;
  }

  // Initiate a challenge
  function challenge (bytes32 statementHash) public {
    if (token.allowance(msg.sender, address(this)) < challengeDeposit) revert();
    if (token.balanceOf(msg.sender) < challengeDeposit) revert();
    if (!token.transferFrom(msg.sender, address(this), challengeDeposit)) revert();
    
    whitelist[statementHash].challenger = msg.sender;
    whitelist[statementHash].dateChallenged = now;
  }

  function tallyVotes (bytes32 statementHash) public constant returns (uint256, uint256, uint256) {
    if (isChallenged(statementHash)) revert();
    return (whitelist[statementHash].votesYes,
            whitelist[statementHash].votesNo,
            whitelist[statementHash].votesArray.length);
  }

  function returnVote (bytes32 statementHash) public returns (uint256, bool, bool) {
    return (
      whitelist[statementHash].votes[msg.sender].amount,
      whitelist[statementHash].votes[msg.sender].dispensed,
      whitelist[statementHash].votes[msg.sender].vote
    );
  }

  function dispense (byte32 statementHash) public {
    if (ischallenged(statementHash)) revert();
    if (!whitelist[statementHash].vote[msg.sender].exists) revert();
    if (whitelist[statementHash].vote[msg.sender].dispensed) revert();
    
    if (whitelist[statementHash].vote[msg.sender].vote && whitelist[statementHash].votesYes >= whitelist[statementHash].votesNo) withdraw(statementHash); // house wins
    if (!whitelist[statementHash].vote[msg.sender].vote && whitelist[statementHash].votesYes < whitelist[statementHash].votesNo) withdraw(statementHash);
    
    if (whitelist[statementHash].challenger == msg.sender && whitelist[statementHash].votesYes < whitelist[statementHash].votesNo) withdraw(statementHash);
  }

  function withdraw (bytes32 statementHash) internal {
    if (whitelist[stateHash].challenger == msg.sender) {
      if (whitelist[statementHash].challengerPaid) revert();
      if (whitelist[statementHash].votesYes >= whitelist[statementHash].votesNo) revert();
      uint256 payout = calculateChallengerPayout(statementHash);
    } 
  }

  function calculateChallengerPayout (bytes32 statementHash) returns (uint256) {
    return (applicationDeposit * (challengerPct / 100)) + challengerDeposit; // add safeMath
  }

  // TODO: add safeMath
  // TODO: different payout depending on whether challenger won or lost
  // TODO: payout proportional to amount staked

  function calculateVoterPayout (bytes32 statementHash) returns (uint256) {
    return (applicationDeposit * (1-(challengerPct / 100)) + challengerDeposit; // add safeMath TK
  }

}