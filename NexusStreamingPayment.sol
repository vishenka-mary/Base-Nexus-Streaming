// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

contract NexusStreamingPayment {
    enum StreamStatus { Active, Paused, Canceled, Completed }

    struct Stream {
        address sender;
        address recipient;
        uint256 deposit;
        uint256 ratePerSecond;
        uint256 startTime;
        uint256 stopTime;
        uint256 lastClaimTime;
        uint256 claimedAmount;
        StreamStatus status;
    }

    address payable public immutable protocolGovernor;
    string public protocolTag;
    uint256 public streamCount;
    uint256 public protocolFeeBasisPoints; // 100 = 1%
    uint256 public accumulatedFees;

    mapping(uint256 => Stream) public streams;

    event StreamCreated(uint256 indexed streamId, address indexed sender, address indexed recipient, uint256 deposit);
    event TokensClaimed(uint256 indexed streamId, address indexed recipient, uint256 amount);
    event StreamPaused(uint256 indexed streamId);
    event StreamResumed(uint256 indexed streamId);
    event StreamCanceled(uint256 indexed streamId, uint256 refundedToSender, uint256 paidToRecipient);
    event StreamToppedUp(uint256 indexed streamId, uint256 addedAmount);
    event ProtocolConfigUpdated(string newTag, uint256 newFee);
    event FeesHarvested(address indexed receiver, uint256 amount);

    modifier onlyGovernor() {
        require(msg.sender == protocolGovernor, "NexusStream: Access denied");
        _;
    }

    constructor() {
        protocolGovernor = payable(msg.sender);
        protocolTag = "Nexus Base Real-Time Cashflow";
        protocolFeeBasisPoints = 100; // 1%
    }

    // 1. Создание потока платежей
    function createStream(
        address recipient,
        uint256 durationSeconds
    ) external payable returns (uint256) {
        require(msg.value > 0, "NexusStream: Zero deposit");
        require(recipient != address(0), "NexusStream: Zero recipient");
        require(durationSeconds >= 60, "NexusStream: Min duration 60s");

        uint256 fee = (msg.value * protocolFeeBasisPoints) / 10000;
        uint256 streamDeposit = msg.value - fee;
        accumulatedFees += fee;

        uint256 rate = streamDeposit / durationSeconds;
        require(rate > 0, "NexusStream: Deposit too small for duration");

        streamCount++;
        streams[streamCount] = Stream({
            sender: msg.sender,
            recipient: recipient,
            deposit: streamDeposit,
            ratePerSecond: rate,
            startTime: block.timestamp,
            stopTime: block.timestamp + durationSeconds,
            lastClaimTime: block.timestamp,
            claimedAmount: 0,
            status: StreamStatus.Active
        });

        emit StreamCreated(streamCount, msg.sender, recipient, streamDeposit);
        return streamCount;
    }

    // 2. Дополнительное пополнение баланса потока
    function topUpStream(uint256 streamId) external payable {
        Stream storage s = streams[streamId];
        require(s.sender == msg.sender, "NexusStream: Only sender can top up");
        require(s.status == StreamStatus.Active, "NexusStream: Stream not active");
        require(msg.value > 0, "NexusStream: Zero top up");

        s.deposit += msg.value;
        emit StreamToppedUp(streamId, msg.value);
    }

    // 3. Вывод накопившихся средств получателем
    function claimFromStream(uint256 streamId) external {
        Stream storage s = streams[streamId];
        require(s.recipient == msg.sender, "NexusStream: Only recipient can claim");
        require(s.status == StreamStatus.Active || s.status == StreamStatus.Paused, "NexusStream: Invalid status");

        uint256 currentTime = block.timestamp > s.stopTime ? s.stopTime : block.timestamp;
        require(currentTime > s.lastClaimTime, "NexusStream: Zero time passed");

        uint256 elapsedTime = currentTime - s.lastClaimTime;
        uint256 payout = elapsedTime * s.ratePerSecond;

        if (payout > (s.deposit - s.claimedAmount)) {
            payout = s.deposit - s.claimedAmount;
        }

        s.lastClaimTime = currentTime;
        s.claimedAmount += payout;

        if (s.claimedAmount >= s.deposit || block.timestamp >= s.stopTime) {
            s.status = StreamStatus.Completed;
        }

        (bool sent, ) = payable(msg.sender).call{value: payout}("");
        require(sent, "NexusStream: Transfer failed");

        emit TokensClaimed(streamId, msg.sender, payout);
    }

    // 4. Поставить поток на паузу
    function pauseStream(uint256 streamId) external {
        Stream storage s = streams[streamId];
        require(s.sender == msg.sender, "NexusStream: Only sender can pause");
        require(s.status == StreamStatus.Active, "NexusStream: Not active");

        s.status = StreamStatus.Paused;
        emit StreamPaused(streamId);
    }

    // 5. Возобновить поток
    function resumeStream(uint256 streamId) external {
        Stream storage s = streams[streamId];
        require(s.sender == msg.sender, "NexusStream: Only sender can resume");
        require(s.status == StreamStatus.Paused, "NexusStream: Not paused");

        s.status = StreamStatus.Active;
        emit StreamResumed(streamId);
    }

    // 6. Отмена потока с расчетом остатка отправителю
    function cancelStream(uint256 streamId) external {
        Stream storage s = streams[streamId];
        require(s.sender == msg.sender, "NexusStream: Only sender can cancel");
        require(s.status == StreamStatus.Active || s.status == StreamStatus.Paused, "NexusStream: Completed or canceled");

        uint256 remainingDeposit = s.deposit - s.claimedAmount;
        s.status = StreamStatus.Canceled;
        s.deposit = 0;

        (bool sent, ) = payable(s.sender).call{value: remainingDeposit}("");
        require(sent, "NexusStream: Refund failed");

        emit StreamCanceled(streamId, remainingDeposit, s.claimedAmount);
    }

    // 7. Обновление параметров протокола
    function configureProtocol(string calldata newTag, uint256 newFee) external onlyGovernor {
        require(newFee <= 500, "NexusStream: Fee cap is 5%");
        protocolTag = newTag;
        protocolFeeBasisPoints = newFee;
        emit ProtocolConfigUpdated(newTag, newFee);
    }

    // 8. Сбор протокольных комиссий
    function harvestProtocolFees() external onlyGovernor {
        uint256 fees = accumulatedFees;
        require(fees > 0, "NexusStream: Zero fees");

        accumulatedFees = 0;
        (bool sent, ) = protocolGovernor.call{value: fees}("");
        require(sent, "NexusStream: Fee transfer failed");

        emit FeesHarvested(protocolGovernor, fees);
    }

    // Чтение информации о потоке
    function getStreamDetails(uint256 streamId) external view returns (
        address sender,
        address recipient,
        uint256 deposit,
        uint256 ratePerSecond,
        uint256 claimedAmount,
        StreamStatus status
    ) {
        Stream memory s = streams[streamId];
        return (s.sender, s.recipient, s.deposit, s.ratePerSecond, s.claimedAmount, s.status);
    }
}