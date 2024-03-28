// import "ds-test/test.sol";
// import "../src/scratch/MyContract.sol";
import "forge-std/Vm.sol";
import "forge-std/Test.sol";

contract SimpleBankContract2 {
    mapping(address => uint256) public BankBalance; //  Mappings are by default stored in storage.
    address public immutable owner;

    // indexed keyword is used in event declarations to indicate that the corresponding parameters should be indexed in the event logs.
    // indexed parameters enable efficient filtering and searching of events when querying the blockchain.
    event OwnershipTransferred(
        address indexed prevOwner,
        address indexed newOwner
    );
    event TransferEvent(uint256 uVal, string message, address newOwner);
    event WithdrawEvent(uint256 uVal, address Owner);
    event DepositEvent(uint256 uVal, address Owner, string sCxt);

    function depositBalance() public payable {
        require(msg.value > 0, "Deposit amount must be greater than 0"); //  //  prevent zero-value transactions which would still cost users gas.

        address userID = msg.sender;
        uint256 depositAmnt = msg.value; // msg.value contains the amount of wei (ether / 1e18) sent in the transaction.

        BankBalance[userID] += depositAmnt;
        emit DepositEvent(
            depositAmnt,
            msg.sender,
            "deposit - depositBalance()"
        );
    }

    // external avoids copy args to memory , passes directly from caller's memory,
    // external funcs cannot be modified by derived contracts.
    function getUserBalance() external view returns (uint256) {
        // require(BankBalance[msg.sender] != 0, "Invalid balance for user !"); // default is 0

        return BankBalance[msg.sender];
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance; // this is a keyword that refers to the current instance of the contract.
    }

    function withdrawlBalance(uint256 withdrawAmnt) public {
        require(
            withdrawAmnt <= BankBalance[msg.sender],
            "Not enough to withdraw !"
        );
        // payable address, which allows you to send ether to them from your contract.
        BankBalance[msg.sender] -= withdrawAmnt;
        payable(msg.sender).transfer(withdrawAmnt); //  sends amount Wei from the contract to the recipient address.
        emit WithdrawEvent(withdrawAmnt, msg.sender);
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // TODO: receive() ,fallback() usage?
    //     // Function to receive ether, msg.data must be empty
    //     // Fallback function is called when msg.data is not empty

    // // Function to receive Ether. msg.data must be empty
    receive() external payable {
        emit DepositEvent(
            msg.value,
            msg.sender,
            "deposit - receive() msg.data is empty "
        );
    }

    // The msg.data contains the function identifier (first 4 bytes of the keccak256 hash of the function signature) followed by the encoded arguments. T
    fallback() external payable {
        emit DepositEvent(
            msg.value,
            msg.sender,
            "deposit - receive() msg.data not empty "
        );
    }
}

// calling a known function of a contract, you can interact with it directly using the contract's ABI generated by Forge.
contract SimpleBankContract2Test is Test {
    // Vm vm = Vm(VM_ADDRESS);
    SimpleBankContract2 simpleContract;

    function setUp() public {
        simpleContract = new SimpleBankContract2();
    }

    // function testDoSomething() public {
    //     // Example arguments
    //     uint256 arg1 = 123;
    //     address arg2 = address(0x123);

    //     // Set up the call (e.g., set the sender)
    // Use vm.prank when you need to test how your contract behaves with transactions initiated by specific addresses, especially when testing access controls, permissions, or sender-specific logic.

    //     vm.prank(address(0x456));

    //     // Call the function directly
    //     simpleContract.doSomething(arg1, arg2);

    //     // Your assertions here
    // }

    function testReceiveFunction() public {
        // Send Ether with empty msg.data to trigger receive()
        (bool success, ) = address(simpleContract).call{value: 1 ether}(""); //  plain Ether transfer, aiming to trigger the receive() function.
        assertTrue(success, "Failed to send Ether to trigger receive()");
    }

    function testFallbackFunction() public {
        // Send Ether with non-empty msg.data to trigger fallback()
        (bool success, ) = address(simpleContract).call{value: 1 ether}(
            "0x1234"
        ); //  simulates a scenario where either the call doesn't match any function or msg.data is deliberately non-empty, aiming to trigger the fallback() function.
        assertTrue(success, "Failed to send Ether to trigger fallback()");
    }
}
