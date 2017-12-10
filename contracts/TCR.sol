
pragma solidity ^0.4.17;
import '../installed_contracts/zeppelin/contracts/token/ERC20.sol';

// ACTORS
// Lister     = person who submitted an item to the list
// Challenger = person who has challenged an item in the list
// Voter      = person who has challenged an item on the list
// voteYes    = a vote in favor of the challenge
// voteNo     = a vote against the challenge 

contract TCR {

  // DATA STRUCTURES

  // A mapping of statement hashes to statements and their metadata
  mapping(bytes32 => Entry) whitelist;
  // Array of keys to whitelist for iteration
  bytes32[] whitelistKeys;
  
  struct Entry {
    bool exists;
    
    address lister;
    string statement;
    uint256 dateAdded;
    
    mapping(uint256 => Challenge) challenges;
    uint256[] challengeKeys;
  }

  struct Challenge {
    bool exists;

    address challenger;
    uint256 dateChallenged;
    
    bool challengerDispensed;
    bool listerDispensed;
    
    mapping(address => Vote) votes;
    address[] voteKeys;
    
    uint256 votesYes;
    uint256 votesNo;
  }

  struct Vote {
    uint256 amount;
    bool dispensed;
    bool votedYes;
    bool exists;
  }
 

  // PARAMETERS
  
  uint256 waitPeriod = (60 * 60) * 48;
  uint256 challengePeriod = (60 * 60) * 24;
  uint8 applicationDeposit = 5;
  uint8 challengeDeposit = 5;
  ERC20 token;
  
  uint256 dispensionPercent = 50;
  uint256 precisionMultiplier = 1000 * 100; // does this even make sense?


  // CONSTRUCTOR

  function TCR (address tokenAddress) public {
    token = ERC20(tokenAddress);
  }

  
  // CONSTANT FUNCTIONS
  
  // Check whether entry is approved
  function isApproved (bytes32 statementHash) public constant returns(bool approved) {
    Entry storage entry = whitelist[statementHash];

    // Check if entry exists
    if (!entry.exists) return false;

    // Check if application period has ended
    if (entry.dateAdded + waitPeriod >= now) return false; // double check timing math eventually
    
    // Check if entry is currently being challenged
    if (isChallenged(statementHash)) return false;
    
    // If the entry has been challenged, the challenge succeeded, and that challenge is relevant to the current entry (in the case of re-application)
    uint256 mostRecentChallengeDate = entry.challengeKeys[entry.challengeKeys.length - 1];
    Challenge storage challenge = entry.challenges[mostRecentChallengeDate];

    if ((challenge.voteKeys.length > 0) && (challenge.votesNo > challenge.votesYes) && (mostRecentChallengeDate > entry.dateAdded)) return false;

    return true;
  }

  // Check whether entry is challenged 
  function isChallenged (bytes32 statementHash) public constant returns (bool) {
    Entry storage entry = whitelist[statementHash];

    // If there are no challenges, return false
    if (entry.challengeKeys.length == 0) return false;
  
    // Check if most recent challenge start date is currently within the challenge period
    uint256 mostRecentChallengeDate = entry.challengeKeys[entry.challengeKeys.length - 1];
    return (mostRecentChallengeDate + challengePeriod) > now;
  }

  function getListLength () public constant returns (uint256 whitelistKeysLength) {
    return whitelistKeys.length;
  }

  function getEntry (uint8 index) public constant returns (bytes32 statementHash,
    string statement,
    address lister,
    uint256 dateAdded,
    uint256 challengeKeysLength,
    bool exists
  ) {

    bytes32 _statementHash = whitelistKeys[index];
    Entry storage entry = whitelist[_statementHash];
    
    return (_statementHash,
            entry.statement,
            entry.lister,
            entry.dateAdded,
            entry.challengeKeys.length,
            entry.exists
    );
  }

  function getChallenge (uint8 index, bytes32 statementHash) public constant returns (
    address challenger,
    uint256 dateChallenged,
    bool challengerDispensed,
    bool listerDispensed,
    uint256 votesYes,
    uint256 votesNo, 
    uint256 votesLength,
    bool exists
    ) {
    
    Entry storage entry = whitelist[statementHash]; 
    uint256 challengeDate = entry.challengeKeys[index];
    Challenge storage challenge = entry.challenges[challengeDate];

    return (challenge.challenger,
            challenge.dateChallenged,
            challenge.challengerDispensed,
            challenge.listerDispensed,
            challenge.votesYes,
            challenge.votesNo,
            challenge.voteKeys.length,
            challenge.exists
    );
  }

  function getVotes (bytes32 statementHash, uint256 challengeDate) public constant returns (uint256 amount, bool dispensed, bool votedYes, bool exists) {
    Entry storage entry = whitelist[statementHash];
    Challenge storage challenge = entry.challenges[challengeDate];
    Vote storage vote = challenge.votes[msg.sender];

    return (vote.amount,
            vote.dispensed,
            vote.votedYes,
            vote.exists
    );
  }


  // TRANSACTIONAL FUNCTIONS

  // Apply to add a statement to the whitelist
  function applyToList (string statement) public {
    // If msg.sender has enough funds
    if (token.allowance(msg.sender, address(this)) < applicationDeposit) revert();
    if (token.balanceOf(msg.sender) < applicationDeposit) revert();
    if (!token.transferFrom(msg.sender, address(this), applicationDeposit)) revert();

    bytes32 statementHash = keccak256(statement);

    whitelist[statementHash].exists = true;
    whitelist[statementHash].dateAdded = now;
    whitelist[statementHash].statement = statement;
    whitelist[statementHash].lister = msg.sender;

    whitelistKeys.push(statementHash); // index mapping
  }

  // Initiate a challenge
  function initiateChallenge (bytes32 statementHash) public {

    if (token.allowance(msg.sender, address(this)) < challengeDeposit) revert();
    if (token.balanceOf(msg.sender) < challengeDeposit) revert();
    if (!token.transferFrom(msg.sender, address(this), challengeDeposit)) revert();
    
    uint256 dateChallenged = now;

    whitelist[statementHash].challengeKeys.push(dateChallenged);

    whitelist[statementHash].challenges[dateChallenged].exists = true;
    whitelist[statementHash].challenges[dateChallenged].challenger = msg.sender;
    whitelist[statementHash].challenges[dateChallenged].dateChallenged = dateChallenged;

  }

  function castVote (bytes32 statementHash, bool votedYes, uint256 amount) public {
    if (!isChallenged(statementHash)) revert();

    Entry storage entry = whitelist[statementHash];
    uint256 mostRecentChallengeDate = entry.challengeKeys[entry.challengeKeys.length - 1];
    Challenge storage challenge = entry.challenges[mostRecentChallengeDate];
    
    if (challenge.votes[msg.sender].exists) revert();
    
    if (token.allowance(msg.sender, address(this)) < amount) revert();
    if (token.balanceOf(msg.sender) < amount) revert();
    if (!token.transferFrom(msg.sender, address(this), amount)) revert(); 

    Vote memory vote; // storage or memory?

    vote.exists = true;
    vote.votedYes = votedYes;
    vote.amount = amount;
    vote.dispensed = false;

    whitelist[statementHash].challenges[mostRecentChallengeDate].votes[msg.sender] = vote;
  }

  // For a given challenge, pay out to the voters, challenger, and/or listers
  function dispense (bytes32 statementHash, uint256 challengeDate) public {
    if (challengeDate + challengePeriod >= now) revert(); 
    
    Entry storage entry = whitelist[statementHash];
    
    Challenge storage challenge = entry.challenges[challengeDate];
    
    Vote storage vote = challenge.votes[msg.sender];

    // VOTE YES

    if (challenge.votesYes >= challenge.votesNo) {

      // VOTER
      uint256 totalRewardYes = challengeDeposit + challenge.votesNo;
      uint256 listerReward = (totalRewardYes * dispensionPercent) / 100; // divide by 100 for percentage multiplication, replace with variable for precision?

      // if voter vote was yes, withdraw if senders vote was not yet dispnsed
      if (vote.exists && !vote.dispensed && vote.votedYes) {
        
        uint256 voterRewardProportionYes = (precisionMultiplier * vote.amount) / challenge.votesYes;
        uint256 voterRewardYes = vote.amount + ((voterRewardProportionYes * (totalRewardYes - listerReward)) / precisionMultiplier);

        if (token.transfer(msg.sender, voterRewardYes)) { 
          whitelist[statementHash].challenges[challengeDate].votes[msg.sender].dispensed = true;
        }
      }

      // LISTER
      
      // if sender was lister and the challenge was unsuccessful, withdraw
      if (!challenge.listerDispensed && (entry.lister == msg.sender)) {
        
        if (token.transfer(msg.sender, listerReward)) { 
          whitelist[statementHash].challenges[challengeDate].listerDispensed = true;
        }

      }
    }

    // NO
    
    if (challenge.votesYes < challenge.votesNo) {

      uint256 totalRewardNo = applicationDeposit + challenge.votesYes;
      uint256 challengerReward = (totalRewardNo * dispensionPercent) / 100; // divide by 100 for percentage multiplication, replace with variable for precision?

      // VOTER
      
      // withdraw if senders vote was not yet dispensed, vote was no, and winning vote was no 
      if (vote.exists && !vote.dispensed && !vote.votedYes) {
        
        // calculate how much to withdraw, transfer, and mark as paid
        uint256 voterRewardProportionNo = (precisionMultiplier * vote.amount) / challenge.votesYes;
        uint256 voterRewardNo = vote.amount + ((voterRewardProportionNo * (totalRewardNo - challengerReward)) / precisionMultiplier);

        if (token.transfer(msg.sender, voterRewardNo)) { 
          whitelist[statementHash].challenges[challengeDate].votes[msg.sender].dispensed = true;
        }
      }
      
      // CHALLENGER

      // withdraw if challenge was not yet dispensed, sender was the challenger, and the challenge was successful
      if (!challenge.challengerDispensed && (challenge.challenger == msg.sender)) {
        if (token.transfer(msg.sender, challengerReward)) { 
          whitelist[statementHash].challenges[challengeDate].challengerDispensed = true;
        }
      }
    } 
  }
}