/**
 *HGB project Dna Token locks
 * code by sid-days
 * HGB project:www.hgbc.io
*/

pragma solidity ^0.4.25;

import "./SafeMath.sol";
import "./Ownable.sol";

/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender)
    public view returns (uint256);

  function transferFrom(address from, address to, uint256 value)
    public returns (bool);

  function approve(address spender, uint256 value) public returns (bool);
  event Approval(
    address indexed owner,
    address indexed spender,
    uint256 value
  );
}

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure.
 * To use this library you can add a `using SafeERC20 for ERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
  function safeTransfer(ERC20Basic token, address to, uint256 value) internal {
    require(token.transfer(to, value));
  }

  function safeTransferFrom(
    ERC20 token,
    address from,
    address to,
    uint256 value
  )
    internal
  {
    require(token.transferFrom(from, to, value));
  }

  function safeApprove(ERC20 token, address spender, uint256 value) internal {
    require(token.approve(spender, value));
  }
}

contract DNALocks is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;
    
    mapping(uint8 => uint8) internal rewardRate;
    uint256 constant MIN_AMOUNT   = 10000 ether; // MIN 10000 DNA
    uint256 constant ONE_YEAR_SECONDS = 365*24*60*60;
    // user DNA lock record
    struct Record {
        uint256 amount;
        uint256 times;
        uint8   phase;
        uint8   rewardItem;
        bool    isdraw;
    }
    mapping (address => Record[]) public records;
    address[] public holds;
    
    // ERC20 basic token contract being held
    ERC20 dnaToken;

    // Initialize the contract
    constructor(ERC20 _dnaToken) public {
        dnaToken = _dnaToken;
        rewardRate[1] = 3; // one year 3% reward
        rewardRate[2] = 4; // two years 4% reward
        rewardRate[3] = 5; // three years 5% reward
        rewardRate[4] = 6; // four years 6% reward
        rewardRate[5] = 7; // five years 7% reward
    }
    
    event Locked(address indexed _hold, uint256 _amount, uint8 _phase);
    event Released(address indexed _hold, uint256 _amount);
    
    /*
     * PUBLIC FUNCTIONS
     */
    function() payable public {
        revert();
    }
    
    /*
     * 锁仓记录
     * 最低1DNA，锁仓期1-5年
     */
    function deposit(address _hold, uint256 _amount, uint8 _phase) onlyOwner public {
        require(_amount >= MIN_AMOUNT, "less than the minimum!");
        require(_phase>=1 && _phase <= 5, "ivalid lock phase!");
        uint256 rlen = records[_hold].length;
        records[_hold].push(Record({
            amount : _amount,
            times : now,
            phase : _phase,
            rewardItem: 0,
            isdraw: false
        }));
        if (rlen == 0) {
            holds.push(_hold);   
        }
        emit Locked(_hold, _amount, _phase);
    }
    
    /*
     * 释放
     */
    function release(address _hold, uint256 _index) onlyOwner public {
        uint256 rlen = records[_hold].length;
        require(rlen > 0, "ivalid hold address!");
        require(_index >= 0 && _index < rlen, "ivalid hold index!");
        Record memory record = records[_hold][_index];
        require(!record.isdraw, "has released!");
        uint256 amount = 0;
        bool isdraw = false;
        uint8 item = record.rewardItem;
        // release reward
        if(uint256(record.rewardItem).add(1).mul(ONE_YEAR_SECONDS).add(record.times) < now) {
            amount = amount + record.amount.mul(uint256(rewardRate[record.phase])).div(100).div(uint256(record.phase));
            item = item + 1;
        }
        if(uint256(record.phase).mul(ONE_YEAR_SECONDS).add(record.times) < now) {
            amount = amount.add(record.amount);
            isdraw = true;
        }

        require(amount > 0, "none release");
        require(dnaToken.balanceOf(address(this)) >= amount, "not enough token!");
        dnaToken.safeTransfer(_hold, amount);
        if(isdraw) records[_hold][_index].isdraw = true;
        records[_hold][_index].rewardItem = item;
        emit Released(_hold, amount);
    }
    
    // Drains DNA.
    function drain() onlyOwner public {
        uint256 amount = dnaToken.balanceOf(address(this));
        require(amount > 0);
        dnaToken.safeTransfer(owner, amount);
    }
    
    function getHoldRecordsSize(address _hold) public view returns (uint256) {
        return records[_hold].length;
    }
    
    function getHoldSize() public view returns (uint256) {
        return holds.length;
    }
    
    function getBalanceOfContract() public view returns (uint256) {
        return dnaToken.balanceOf(address(this));
    }
    
    function getHoldLockedAmount(address _hold) public view returns (uint256, uint256) {
        uint256 rlen = records[_hold].length;
        uint256 lockM = 0;
        uint256 releaseM = 0;
        for (uint256 i=0; i < rlen; i++) {
            Record memory record = records[_hold][i];
            if (record.isdraw) {
                releaseM = releaseM.add(record.amount);
            }else {
                lockM = lockM.add(record.amount);
            }
        }
        return (lockM, releaseM);
    }
    
    function getHoldRecord(address _hold, uint256 _index) public view returns (uint256 amount, uint256 times, uint8 phase, uint8 item, bool isdraw) {
        require(_index < records[_hold].length, "out of bounds!");
        return (records[_hold][_index].amount, records[_hold][_index].times, records[_hold][_index].phase, records[_hold][_index].rewardItem, records[_hold][_index].isdraw);
    }
    
}

