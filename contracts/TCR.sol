pragma solidity ^0.4.17;
import '../installed_contracts/zeppelin/contracts/token/ERC20.sol';

contract TCR {
  mapping(bytes32 => Entry) whitelist;
  struct Entry {
    bool exists;
    uint256 dateAdded;
    uint256 dateChallenged;
    address challenger;
    string statement;
    address statementOwner;
  }

  bytes32[] whitelistKeys;

  uint256 waitPeriod = 60 * 60 * 48;
  uint256 challengePeriod = 60 * 60 * 24;
  uint8 applicationDeposit = 5;
  uint8 challengeDeposit = 5;
  ERC20 token;
  
  uint dispensionPct = 50;
  
  function TCR (address tokenAddress) {
    token = ERC20(tokenAddress);
  }

  function isApproved (bytes32 statementHash) public constant returns(bool approved) {
    if (!whitelist[statementHash].exists) return false;
    if (isChallenged(statementHash)) return false;
    if (whitelist[statementHash].dateAdded + waitPeriod >= now) return false; // TK
    return true;
  }

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

  function isChallenged (bytes32 statementHash) public constant returns (bool) {
    // whitelist[statementHash].dateChallenged;
  }

  function challenge (bytes32 statementHash) public {
    if (token.allowance(msg.sender, address(this)) < challengeDeposit) revert();
    if (token.balanceOf(msg.sender) < challengeDeposit) revert();
    if (!token.transferFrom(msg.sender, address(this), challengeDeposit)) revert();
    
    whitelist[statementHash].challenger = msg.sender;
    whitelist[statementHash].dateChallenged = now;
  }

}