//SPDX-License-Identifier: GPL-3

pragma solidity ^0.8.5;


abstract contract Initializable {
    
    bool private _initialized;

    
    bool private _initializing;

    
    modifier initializer() {
        require(_initializing || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }
}

abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
    uint256[50] private __gap;
}

abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    
    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
        _transferOwnership(_msgSender());
    }

    
    function owner() public view virtual returns (address) {
        return _owner;
    }

    
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    uint256[49] private __gap;
}

interface IERC20Upgradeable {
    
    function totalSupply() external view returns (uint256);

    
    function balanceOf(address account) external view returns (uint256);

    
    function transfer(address recipient, uint256 amount) external returns (bool);

    
    function allowance(address owner, address spender) external view returns (uint256);

    
    function approve(address spender, uint256 amount) external returns (bool);

    
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    
    event Transfer(address indexed from, address indexed to, uint256 value);

    
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IADIAT {
    function mint(address to, uint256 amount) external;
}

contract WLv3 is OwnableUpgradeable {
  address private dai;
  address private aDiat;
  address private diatomDao;
  mapping(address => bool) private approvedBuyers;
  mapping(address => uint256) private claimable;
  bool private _paused;
  bool private _migratingToV3;
  bool private _migratedToV3;

  function capacity(address _account) external view returns (uint256) {
    return claimable[_account];
  }

  function approved(address _account) external view returns (bool) {
    return approvedBuyers[_account];
  }

  function initialize(
    address _dai,
    address _aDiat,
    address _diatomDao
  ) public initializer {
    dai = _dai;
    aDiat = _aDiat;
    diatomDao = _diatomDao;
    __Ownable_init();
  }

  function addapprovedBuyers(address[] calldata buyers) external onlyOwner {
    for (uint256 i; i < buyers.length; i++) {
      
      approvedBuyers[buyers[i]] = true;
      claimable[buyers[i]] = 80 * 1e18;
    }
  }

  function swap(uint256 _amount) external {
    require(!paused(), "Contract is paused");
    require(approvedBuyers[_msgSender()] == true, "buyer not approved");
    require(
      claimable[_msgSender()] >= (_amount / 25),
      "claimable lower than requested"
    );
    require(
      IERC20Upgradeable(dai).allowance(_msgSender(), address(this)) >= _amount,
      "Dai allowance too low"
    );
    _swapDaiToAdiat(_amount);
  }

  function _swapDaiToAdiat(uint256 _amount) internal {
    uint256 aDiatAmount = _amount / 25;
    claimable[_msgSender()] -= aDiatAmount;
    bool daiTransfer = IERC20Upgradeable(dai).transferFrom(
      _msgSender(),
      diatomDao,
      _amount
    );
    require(daiTransfer, "Dai transfer failed");
    IADIAT(aDiat).mint(_msgSender(), aDiatAmount);
  }

  function revokeBuyers(address[] calldata buyers) external onlyOwner {
    for (uint256 i; i < buyers.length; i++) {
      
      delete approvedBuyers[buyers[i]];
      delete claimable[buyers[i]];
    }
  }

  modifier migraterToV3() {
    require(_migratingToV3 || !_migratedToV3, "Contract already migrated to V3");

    bool isTopLevelCall = !_migratingToV3;
    if (isTopLevelCall) {
      _migratingToV3 = true;
      _migratedToV3 = true;
    }

    _;

    if (isTopLevelCall) {
      _migratingToV3 = false;
    }
  }

  function migrateToV3() external migraterToV3 {
    _paused = false;
  }

  function _pause() internal virtual {
    _paused = true;
  }

  function _unpause() internal virtual {
    _paused = false;
  }

  function paused() public view virtual returns (bool) {
    return _paused;
  }

  function pause() external onlyOwner {
    require(!_paused, "Contract already paused");
    _pause();
  }

  function unPause() external onlyOwner {
    require(_paused, "Contract not paused");
    _unpause();
  }
}