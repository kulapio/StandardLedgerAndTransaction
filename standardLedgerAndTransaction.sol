pragma solidity ^0.6.0;

import "github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/SafeMath.sol";

/// Note: For a given bank: sum of Account balances always == Bank balance
/// We can apply formal verification here
struct Bank {
  string name; // optional
  uint256 balance;
  uint256 nonce; // prevent replay-attack
  string note; // optional
  bool active; // BOT / Other purposes
}

struct Account {
  string name; // optional
  uint256 balance;
  uint256 nonce; // prevent replay-attack
  string note; // optional
  bool active; // AML / Other purposes
  address bank; // Can be multisig, group of authorities or advanced governance models
}

// struct Transaction {
//   address fromBank;
//   address toBank;
//   address fromAccount;
//   address toAccount;
//   uint256 amount;
//   uint256 expiryTime;
//   string memo; // optional
// }

/// @title Standard Ledger & Transaction for Bank & Financial Institution.
/// Support Off-chain transaction, up to 1,000,000 transactions / second.
/// Can be use as peer-to-peer or with settlement party. 
/// @author Nattapon Nimakul - <tot@kulap.io>
contract StandardLedgerAndTransaction {
    using SafeMath for uint256;
    
    address payable public bot; // Can be multisig, group of authorities or advanced governance models
    mapping (address => Bank) public bankProfiles;
    mapping (address => Account) public accounts;
    
    modifier onlyBOT {
        require(msg.sender == bot);
        _;
    }
    
    /// @dev On-chain transaction
    function InterBankTransfer(address _sender, address _receiver, uint256 amount) public {
        Account storage sender = accounts[_sender];
        Account storage receiver = accounts[_receiver];
        require(msg.sender == sender.bank);
        
        sender.balance = sender.balance.sub(amount);
        bankProfiles[sender.bank].balance = bankProfiles[sender.bank].balance.sub(amount);
        
        receiver.balance = receiver.balance.add(amount);
        bankProfiles[receiver.bank].balance = bankProfiles[receiver.bank].balance.add(amount);
        
        // emit Transfer();
    }
    
    /// @dev On-chain internal transaction
    function InternalBankTransfer(address _sender, address _receiver, uint256 amount) public {
        Account storage sender = accounts[_sender];
        Account storage receiver = accounts[_receiver];
        require(msg.sender == sender.bank);
        require(sender.bank == receiver.bank);
        
        sender.balance = sender.balance.sub(amount);
        receiver.balance = receiver.balance.add(amount);
        
        // emit Transfer();
    }
    
    // @dev Bot -> Bank
    function BOTDepositToAccount(address _account) public onlyBOT payable {
        Account storage receiver = accounts[_account];
        uint256 amount = msg.value;
        
        receiver.balance = receiver.balance.add(amount);
        bankProfiles[receiver.bank].balance = bankProfiles[receiver.bank].balance.add(amount);
        
        // emit BotDeposit();
    }
    
    /// @dev Bank -> BOT
    function BOTWithdrawFromAccount(address _account, uint256 amount) onlyBOT public {
        Account storage account = accounts[_account];
    
        account.balance = account.balance.sub(amount);
        bankProfiles[account.bank].balance = bankProfiles[account.bank].balance.sub(amount);
        
        bot.transfer(amount); // transfer native back to BOT
        
        // emit BotWithdraw();
    }
    
    // @dev Off-chain transaction, can implement with EIP712 digital signature, https://github.com/ethereum/EIPs/blob/master/EIPS/eip-712.md
    // If sender is trusted provider - 99% finality.
    // If sender is not trusted provider - transaction should record on-chain asap, for example submitting a batch every 10 minutes.
    // Reciever must check accountNonce and bankNonce that always >= on-chain state (DvP).
    function offChainTransfer(
      address _sender,
      address _receiver,
      uint256 amount,
      bytes memory signature,
      uint256 accountNonce,
      uint256 bankNonce,
      uint256 expiryTime
    ) public {
        Account storage sender = accounts[_sender];
        Account storage receiver = accounts[_receiver];
        
        require(accountNonce == sender.nonce);
        require(bankNonce == bankProfiles[sender.bank].nonce);
        bankProfiles[sender.bank].nonce += 1;
        sender.nonce += 1;
        
        // Verify signature
        require(expiryTime > now);
        // address signer = verifySignature(signature, _sender, _reciver, amount, accountNonce, bankNonce, expiryTime);
        // require(signer == sender.bank);
        
        sender.balance = sender.balance.sub(amount);
        bankProfiles[sender.bank].balance = bankProfiles[sender.bank].balance.sub(amount);
        
        receiver.balance = receiver.balance.add(amount);
        bankProfiles[receiver.bank].balance = bankProfiles[receiver.bank].balance.add(amount);
        
        // emit OffChainTransfer();
    }
}
