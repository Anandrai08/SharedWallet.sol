// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;
 
contract Owned {
    
    mapping (address => bool) owners;
    uint ownerCount;
 
    constructor() {
        owners[msg.sender] = true;
        ownerCount++;
    }
    
    event _addOwner(address indexed _from, address indexed _new, uint _numOwners);
    event _removeOwner(address indexed _from, address indexed _old, uint _numOwners);
 
    modifier onlyOwner() {
        require(owners[msg.sender], "You are not an owner");
        _;
    }
    
    function addOwner(address _new) public onlyOwner() {
        require(owners[_new] == false, "Already owner");
        owners[_new] = true;
        ownerCount++;
        emit _addOwner(msg.sender, _new, ownerCount);
    }
    
    function removeOwner(address _old) public onlyOwner() {
        require(owners[_old] == true, "Not an owner");
        require(ownerCount > 1, "Must have at least 1 owner");
        owners[_old] = false;
        ownerCount--;
        emit _removeOwner(msg.sender, _old, ownerCount);
    }
}
 
contract SharedWallet is Owned {
    uint public myAllowance;
    uint public timePeriod;
    //address public owner;
    
    struct Person {
        uint periodAllowance;
        uint currentAllowance;
        uint lastWithdraw;
        uint timePeriod;
    }
    
    //mapping(address => uint) public lastWithdraw;
    mapping(address => Person) public allowance;
    
    constructor() {
        timePeriod = 5 minutes;
    }
    
    event moneySent(address indexed _from, address indexed _to, uint _amount);
    event personAdded(address indexed _who, address indexed _bywhom, uint _allowance, uint _period);
    event allowanceChanged(address indexed _who, address indexed _bywhom, uint _newAllowance, uint _oldAllowance);
    event periodChanged(address indexed _who, address indexed _bywhom, uint _newPeriod, uint _oldPeriod);
    event allowanceChangedDefault(address indexed _bywhom, uint _newAllowance, uint _oldAllowance);
    event periodChangedDefault(address indexed _bywhom, uint _newPeriod, uint _oldPeriod);
    
    function receiveveMoney() public payable {
        emit moneySent(msg.sender,address(this),msg.value);
    }
    
    function getBalance() public view returns(uint) {
        return address(this).balance;
    }
    
    function setAllowance(uint _newAllowance) public onlyOwner {
        emit allowanceChangedDefault(msg.sender, _newAllowance, myAllowance);
        myAllowance = _newAllowance;
    }
    
    function setAllowance(address _for, uint _newAllowance) public onlyOwner {
        require(allowance[_for].lastWithdraw > 0, "Person does not exist");
        updateAllowance(_for);
        emit allowanceChanged(_for, msg.sender, _newAllowance, allowance[_for].periodAllowance);
        allowance[_for].periodAllowance = _newAllowance;
    }
    
    function setTimePeriod(uint _newTimePeriod) public onlyOwner {
        require(_newTimePeriod > 0, "Period must be > 0");
        emit periodChangedDefault(msg.sender, _newTimePeriod, timePeriod);
        timePeriod = _newTimePeriod;
    }
    
    function setTimePeriod(address _for, uint _newTimePeriod) public onlyOwner {
        require(_newTimePeriod > 0, "Period must be > 0");
        require(allowance[_for].lastWithdraw > 0, "Person does not exist");
        updateAllowance(_for);
        emit periodChanged(_for, msg.sender, _newTimePeriod, allowance[_for].timePeriod);
        allowance[_for].timePeriod = _newTimePeriod;
    }
    
    function addPerson(address _person) public onlyOwner {
        require(allowance[_person].timePeriod == 0, "Person already exists");
        Person memory _newPerson = Person(myAllowance, 0 , block.timestamp - timePeriod, timePeriod);
        allowance[_person] = _newPerson;
        updateAllowance(_person);
        emit personAdded(_person, msg.sender, myAllowance, timePeriod);
    }
    
    function addPersonWithDetail(address _person, uint _period, uint _allowance) public onlyOwner {
        require(allowance[_person].timePeriod == 0, "Person already exists");
        require(_period > 0, "Period must be more than zero");
        Person memory _newPerson = Person(_allowance, 0 , block.timestamp - timePeriod, _period);
        allowance[_person] = _newPerson;
        updateAllowance(_person);
        emit personAdded(_person, msg.sender, _allowance, _period);
    }
    
    function updateAllowance(address _for) internal {
        uint numPayments = (block.timestamp - allowance[_for].lastWithdraw - timePeriod*0) / timePeriod;
        if (numPayments > 0) {
            allowance[_for].currentAllowance += numPayments * allowance[_for].periodAllowance;
            allowance[_for].lastWithdraw += numPayments * allowance[_for].timePeriod; 
        }
    }
    
    function withdrawAlowance() public {
        require(getBalance() > 0, "No money in contract");
        require(allowance[msg.sender].timePeriod > 0, "You can't recieve money");
        require(allowance[msg.sender].currentAllowance > 0 || block.timestamp >= allowance[msg.sender].lastWithdraw + timePeriod, "Need to wait until next period");
        //uint numPayments = (block.timestamp - lastWithdraw[msg.sender] - timePeriod*0) / timePeriod;
        updateAllowance(msg.sender);
        require(getBalance() >= allowance[msg.sender].currentAllowance , "Not enough money in contract");
        uint moneyToSend = allowance[msg.sender].currentAllowance;
        //lastWithdraw[msg.sender] += numPayments * timePeriod;
        allowance[msg.sender].currentAllowance -= moneyToSend;
        assert(allowance[msg.sender].currentAllowance == 0);
        address payable _to = payable(msg.sender);
        _to.transfer(moneyToSend);
        emit moneySent(address(this),_to, moneyToSend);
    }
    
    function withdrawAlowanceTo(address payable _to, uint _amount) public {
        require(getBalance() > 0, "No money in contract");
        require(allowance[msg.sender].lastWithdraw > 0, "You can't withdraw money");
        require(allowance[msg.sender].currentAllowance > 0 || block.timestamp >= allowance[msg.sender].lastWithdraw + timePeriod, "Need to wait until next period");
        //uint numPayments = (block.timestamp - lastWithdraw[msg.sender] - timePeriod*0) / timePeriod;
        updateAllowance(msg.sender);
        require(getBalance() >= _amount , "Not enough money in contract");
        require(allowance[msg.sender].currentAllowance >= _amount, "You don't have enough money");
        uint moneyToSend = _amount;
        allowance[msg.sender].currentAllowance -= moneyToSend;
        _to.transfer(moneyToSend);
        emit moneySent(address(this),_to, moneyToSend);
    }
    
    function timeTillWithdraw() public view returns(uint) {
        uint tempTime = 0;
        uint timeNow = block.timestamp;
        uint lastTime = allowance[msg.sender].lastWithdraw;
        uint nextTime = lastTime + timePeriod;
        if (timeNow < nextTime && allowance[msg.sender].currentAllowance == 0)
            tempTime = allowance[msg.sender].lastWithdraw + timePeriod - block.timestamp;
        return tempTime;
    }
    
    function checkMyBalance() public view returns(uint) {
        return allowance[msg.sender].currentAllowance;
    }
    
    function getTime() public view returns(uint){
        return block.timestamp;
    }
    
    function windrawMoney(address payable _to, uint _amount) public onlyOwner {
        require(getBalance() >= _amount, "Not enough funds");
        _to.transfer(_amount);
        emit moneySent(address(this),_to,_amount);
    }
    
    receive () external payable {
        receiveveMoney();
    }
}
