pragma solidity ^0.4.17;
import '../installed_contracts/zeppelin/contracts/token/StandardToken.sol';

contract TestToken is StandardToken {
  uint256 INITIAL_SUPPLY = 1000000;
  uint256 decimals = 0;
  string public name = "TestToken";
  string public symbol = "T";

  function TestToken () {
    totalSupply = INITIAL_SUPPLY;
    balances[msg.sender] = INITIAL_SUPPLY;
  }

  function mint (address recipient, uint256 amount) public {
    totalSupply = totalSupply.add(amount);
    balances[recipient] = balances[recipient].add(amount);
  }
  
}