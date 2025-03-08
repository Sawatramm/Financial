// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract RPS {
    uint public numPlayer = 0;
    uint public reward = 0;
    uint public numInput = 0;

    uint public joinTimeout = 5 minutes;  // เวลารอ Player 1 มาร่วมเล่น
    uint public inputTimeout = 5 minutes; // เวลารอให้ส่ง input

    uint public lastActionTime;
    address[] public players;
    mapping(address => uint) public player_choice;
    mapping(address => bool) public player_played;

    function addPlayer() public payable {
        require(numPlayer < 2, "Game already has 2 players");
        if (numPlayer > 0) {
            require(msg.sender != players[0], "Same player cannot join twice");
        }

        players.push(msg.sender);
        player_played[msg.sender] = false;
        numPlayer++;
        reward += msg.value;
        lastActionTime = block.timestamp; // บันทึกเวลาล่าสุด

        if (numPlayer == 1) {
            // เริ่มจับเวลาเมื่อ Player 0 ลงขัน
            lastActionTime = block.timestamp;
        }
    }

    function input(uint choice) public {
        require(numPlayer == 2, "Not enough players");
        require(!player_played[msg.sender], "Player already played");
        require(choice >= 0 && choice <= 4, "Invalid choice"); //0 - Rock, 1 - Paper , 2 - Scissors , 3-Lizard , 4-Spock

        player_choice[msg.sender] = choice;
        player_played[msg.sender] = true;
        numInput++;

        lastActionTime = block.timestamp; // อัปเดตเวลาล่าสุด

        if (numInput == 2) {
            _checkWinnerAndPay();
        }
    }

    function _checkWinnerAndPay() private {
        uint p0Choice = player_choice[players[0]];
        uint p1Choice = player_choice[players[1]];
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);

        uint tempReward = reward;

        _resetGame();

        if ((p0Choice == 0 && (p1Choice == 2 || p1Choice == 3)) ||
            (p0Choice == 1 && (p1Choice == 0 || p1Choice == 4)) ||
            (p0Choice == 2 && (p1Choice == 1 || p1Choice == 3)) ||
            (p0Choice == 3 && (p1Choice == 1 || p1Choice == 4)) ||
            (p0Choice == 4 && (p1Choice == 0 || p1Choice == 2))) {
            account0.transfer(tempReward);
        } 
        else if ((p1Choice == 0 && (p0Choice == 2 || p0Choice == 3)) ||
                 (p1Choice == 1 && (p0Choice == 0 || p0Choice == 4)) ||
                 (p1Choice == 2 && (p0Choice == 1 || p0Choice == 3)) ||
                 (p1Choice == 3 && (p0Choice == 1 || p0Choice == 4)) ||
                 (p1Choice == 4 && (p0Choice == 0 || p0Choice == 2))) {
            account1.transfer(tempReward);
        } 
        else {
            account0.transfer(tempReward / 2);
            account1.transfer(tempReward / 2);
        }
    }

    function _resetGame() private {
        numPlayer = 0;
        numInput = 0;
        reward = 0;
        delete players;
    }

    function claimTimeout() public {
        require(numPlayer > 0, "No players joined yet");

        if (numPlayer == 1 && block.timestamp > lastActionTime + joinTimeout) {
            // ถ้า Player 1 ไม่มา Player 0 ถอนเงินคืนได้
            payable(players[0]).transfer(reward);
            _resetGame();
        } else if (numPlayer == 2 && block.timestamp > lastActionTime + inputTimeout) {
            // ถ้าผู้เล่นคนใดคนหนึ่งไม่ส่ง input อีกฝ่ายชนะทันที
            if (!player_played[players[0]]) {
                payable(players[1]).transfer(reward);
            } else if (!player_played[players[1]]) {
                payable(players[0]).transfer(reward);
            }
            _resetGame();
        }
    }
}
