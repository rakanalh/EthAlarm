pragma solidity ^0.4.9;

import './DateTimeAPI.sol';

contract EthAlarm {
    struct Alarm {
        address sender;
        uint256 amount;
        int8 timezone;
        uint8 hour;
        uint8 minute;
    }

    event AlarmCreated(bytes32 alarmID);
    event AlarmCheckInSuccess(bytes32 alarmID);
    event AlarmCheckInFailure(bytes32 alarmID);

    address owner;
    uint256 lostAmounts;
    address dateTimeAddress = 0x0;
    mapping(bytes32 => Alarm) alarms;
    DateTimeAPI dateTimeAPI;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor(address _dateTimeAPIAddress) public {
        owner = msg.sender;
        setDateTimeAPIAddress(_dateTimeAPIAddress);
    }

    function setDateTimeAPIAddress(address _dateTimeAPIAddress) public onlyOwner {
        dateTimeAddress = _dateTimeAPIAddress;
        dateTimeAPI = DateTimeAPI(dateTimeAddress);
    }

    function getDateTimeAPIAddress() public view onlyOwner returns (address) {
        return dateTimeAddress;
    }

    function getLostAmounts() public view onlyOwner returns (uint256) {
        return lostAmounts;
    }

    function transferLostAmounts(address _myaddress) public onlyOwner {
        _myaddress.transfer(lostAmounts);
    }

    function createAlarm(int8 _timezone, uint8 _hour, uint8 _minute) public payable returns (bytes32) {
        require(msg.value > 0);
        require(_hour >= 0 && _hour < 24);
        require(_minute >= 0 && _minute < 60);

        bytes32 alarmID = keccak256(abi.encodePacked(msg.sender, _timezone, _hour, _minute));
        alarms[alarmID] = Alarm(msg.sender, msg.value, _timezone, _hour, _minute);
        emit AlarmCreated(alarmID);
        return alarmID;
    }

    function checkIn(bytes32 _alarmID) public {
        uint8 blockHour;
        uint8 blockMinute;
        (blockHour, blockMinute) = getBlockTime();

        Alarm memory alarm = alarms[_alarmID];

        require(msg.sender != 0x0 && alarm.sender == msg.sender);

        int8 alarmHour = int8(blockHour) + alarm.timezone;
        uint8 rangeMinuteStart = blockMinute - 10;
        uint8 rangeMinuteEnd = blockMinute + 10;

        if(rangeMinuteStart < 0) {
            rangeMinuteStart = 0;
        }
        if(rangeMinuteEnd > 59) {
            rangeMinuteStart = 59;
        }

        if(int8(alarm.hour) == alarmHour && alarm.minute >= rangeMinuteStart && alarm.minute <= rangeMinuteEnd) {
            alarm.sender.transfer(alarm.amount);
            emit AlarmCheckInSuccess(_alarmID);
            return;
        }

        delete alarms[_alarmID];
        lostAmounts += alarm.amount;
        emit AlarmCheckInFailure(_alarmID);
    }

    function getBlockTime() private view returns (uint8, uint8) {
        uint8 hour = dateTimeAPI.getHour(now);
        uint8 minute = dateTimeAPI.getMinute(now);
        return (hour, minute);
    }
}
