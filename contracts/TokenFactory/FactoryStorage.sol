/**
 * @dev This contract stores all variables and functions that can never
 * be upgraded when the ContractFactory is upgraded. Information about the contracts
 * owned by addresses is stored here, along with a modifier/function combo which
 * updates the owner of a contract when ownership has been transferred.
 *
 * We can use this data to track token collections and the addresses that own them.
 * This may come in handy later if we run into legal issues around piracy of
 * exclusive content. We will be able to determine which addresses to punish/restrict
 * when content disputes arise.
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FactoryStorage {
  // Fires when a new contract is created;
  event contractCreated(address creatorAddress, address contractAddress, uint256 contractID);

  // Fires when an upgrade has successfully passed;
  event contractUpgraded(address newAddress);

  // Fires when DAO accepts new contract;
  event contractAccepted(bool isAccepted, address contractAddress);

  // Stores information about the contract creation event;
  struct contractCreation {
    uint256 contractID; // ID of contract
    address contractAddress; // Address of new contract
    address creatorAddress; // Address of contract creator
    uint32 contractType; // Number corresponding to contract type
    uint256 creationTime; // Block time of contract creation
  }

  // Mapping of all contracts created by an address;
  // creatorAddress => contractAddresses
  mapping(address => address[]) contractsCreatedBy;

  // Mapping of a contract's owner's address;
  // contractAddress => creatorAddress
  mapping(address => address) contractOwnedBy;

  // Mapping to show if address has created contracts;
  // Used for incrementing totalCreators;
  mapping(address => bool) isContractCreator;

  // Mapping of contractID to contractCreation struct;
  mapping(uint256 => contractCreation) contractID;

  // Number of total unique creator addresses;
  uint256 public totalCreators;

  // Counter for contract IDs;
  uint256 contractIDCounter;

  // Array of all addresses created by this factory;
  address[] contractClones;

  // Contract address of the DAO contract;
  // Initially belongs to dev wallet;
  address DAOContract;

  // Address of the developers' multi-sig wallet;
  // Initially belongs to contract dev;
  address devWallet;

  constructor() {
    DAOContract = msg.sender;
    devWallet = msg.sender;
  }

  function getAllContracts(address _creatorAddress) public view returns (address[] memory) {
    return contractsCreatedBy[_creatorAddress];
  }

  function numberContractsCreated(address _creatorAddress)
    public
    view
    returns (uint256 contractsCreated)
  {
    return contractsCreatedBy[_creatorAddress].length;
  }

  // Stores information about contract creation event
  function _storeInfo(address newContract, uint32 contractType) internal {
    // Push new contract to list of all contracts created by this factory
    contractClones.push(newContract);
    // Push new contract to list of all contracts created by creator
    contractsCreatedBy[msg.sender].push(newContract);
    // Assign ownership of new contract to creator
    contractOwnedBy[newContract] = msg.sender;

    // Flag address as being a contract creator, if not already
    if (!isContractCreator[msg.sender]) {
      isContractCreator[msg.sender] = true;
      totalCreators++; // Add to total count of all creators
    }

    // Create and store contractCreation struct in contractID mapping
    contractCreation memory newContractCreation = contractCreation(
      contractIDCounter,
      newContract,
      msg.sender,
      contractType,
      block.timestamp
    );

    contractID[contractIDCounter] = newContractCreation;

    // Increment the ID counter uint
    contractIDCounter++;
    emit contractCreated(msg.sender, newContract, newContractCreation.creationTime);
  }

  // Modifier restricting access only to a smart contract;
  /*
   * Use in function to update owner of contract, but only
   * contract can call the function. Include an external
   * function call to this contract to update the owner.
   */
  modifier onlyContract(address _contract) {
    require(msg.sender == _contract, "Only child contract can call function");
    _;
  }

  // Restricts access to the DAO contract;
  modifier onlyDAO() {
    require(msg.sender == DAOContract, "Only DAO contract can call this function");
    _;
  }

  // Updates the owner of a contract
  // Only the smart contract being updated for can call this function;
  function updateOwner(address _newOwner, address _contract)
    external
    onlyContract(_contract)
    returns (bool)
  {
    contractOwnedBy[_contract] = _newOwner;
    return true;
  }
}
