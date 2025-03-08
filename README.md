# อธิบายโค้ดที่ป้องกันการ lock เงินไว้ใน contract
    ใช้ กลไก Timeout (หมดเวลา) เพื่อให้เงินไม่ติดอยู่ในสัญญา โดยมีฟังก์ชัน claimTimeout() ที่ช่วยแก้ปัญหานี้
    # 1. กรณี Player 0 ลงขันแล้ว แต่ไม่มี Player 1 มาร่วมเล่น
    วิธีป้องกัน 
    เมื่อ Player 0 เรียก addPlayer() เวลาล่าสุดจะถูกบันทึก (lastActionTime = block.timestamp)
    ถ้า เกิน 5 นาที (300 วินาที) แล้วยังไม่มี Player 1 เข้าร่วม
    Player 0 สามารถเรียก claimTimeout() เพื่อถอนเงินคืน
    
    uint public inputTimeout = 5 minutes;  // เวลารอให้ผู้เล่นส่ง input
    function claimTimeout() public {
        require(numPlayer > 0, "No players joined yet");

        if (numPlayer == 1 && block.timestamp > lastActionTime + joinTimeout) {
            // ถ้า Player 1 ไม่มา Player 0 ถอนเงินคืนได้
            payable(players[0]).transfer(reward);
            _resetGame();
        } 
    }
    # 2. กรณีมี Player ครบ แต่มีคนเดียวที่ส่ง input()
    วิธีป้องกัน
    เมื่อมีผู้เล่นครบ 2 คน เวลาล่าสุดจะถูกบันทึก (lastActionTime = block.timestamp)
    ถ้า เกิน 5 นาที (300 วินาที) แล้วยังมีผู้เล่นที่ไม่ส่ง input()
    ผู้เล่นที่ส่ง input() แล้วสามารถเรียก claimTimeout() เพื่อรับเงินทั้งหมด
    
    uint public inputTimeout = 5 minutes;  // เวลารอให้ผู้เล่นส่ง input
    else if (numPlayer == 2 && block.timestamp > lastActionTime + inputTimeout) {
            // ถ้าผู้เล่นคนใดคนหนึ่งไม่ส่ง input อีกฝ่ายชนะทันที
            if (!player_played[players[0]]) {
                payable(players[1]).transfer(reward);
            } else if (!player_played[players[1]]) {
                payable(players[0]).transfer(reward);
            }
            _resetGame();
        }

    # 3. ป้องกันการล็อกเงินจากข้อผิดพลาดของโค้ด
        โดยจะใช้ function _checkWinnerAndPay()
# อธิบายโค้ดส่วนที่ทำการซ่อน choice และ commit
  #1  การซ่อน choice โดยใช้ Commit
      เมื่อผู้เล่นต้องการเข้าร่วมเกม เขาต้อง สร้างค่า Commit ก่อน แล้วส่งไปยัง Smart Contract โดยใช้ฟังก์ชัน addPlayer()
      
      function addPlayer(bytes32 _commitHash) public payable
      
  #2  การเปิดเผยค่า (Reveal)
      เมื่อถึงรอบ Reveal ผู้เล่นต้องเรียกฟังก์ชัน revealChoice() เพื่อส่งค่า choice และ secret
      
      function revealChoice(uint _choice, string memory _secret) public
      
  #3  การตัดสินผลแพ้ชนะ
      หาก ผู้เล่นทั้งสองเปิดเผยค่าแล้ว (numRevealed == 2)
      เรียก _checkWinnerAndPay() เพื่อตัดสินผลและจ่ายเงินให้ผู้ชนะ
      
# อธิบายโค้ดส่วนที่จัดการกับความล่าช้าที่ผู้เล่นไม่ครบทั้งสองคนเสียที
    เพิ่มระบบ Time Limit → ใช้ตัวแปร startTime และ timeout กำหนดระยะเวลารอ
    ถ้าผู้เล่นไม่ทำตามขั้นตอนภายในเวลาที่กำหนด → อีกฝ่ายสามารถ Claim Win หรือ Refund ได้
    1️ ใช้ startTime และ timeout
        uint public startTime; //เวลาที่เริ่มเกม (กำหนดเมื่อผู้เล่นครบ 2 คน)
        uint public timeout = 10 minutes; //เวลาที่ให้แต่ละรอบ เช่น 10 นาที
    2 ใช้ ฟังก์ชัน claimTimeout()
      อีกฝ่ายสามารถ Claim ชนะ และรับเงินไปได้
        function claimTimeout() public {
        require(numPlayer == 2, "Not enough players");
        require(block.timestamp > startTime + timeout, "Time limit not reached");

        if (!players[playerList[0]].hasRevealed) {
            payable(playerList[1]).transfer(reward);
        } else if (!players[playerList[1]].hasRevealed) {
            payable(playerList[0]).transfer(reward);
        } else {
            revert("Both players have revealed their choices");
        }

        _resetGame();
    3️ ฟังก์ชัน refundIfNoOpponent()
      สามารถขอเงินคืนหลังจากหมดเวลารอ
      function refundIfNoOpponent() public {
            require(numPlayer == 1, "Cannot refund if 2 players joined");
            require(block.timestamp > startTime + timeout, "Waiting period not over");

            payable(playerList[0]).transfer(reward);
            _resetGame();
        }
# อธิบายโค้ดส่วนทำการ reveal และนำ choice มาตัดสินผู้ชนะ
    1️ การทำงานของฟังก์ชัน revealChoice()
      เมื่อผู้เล่นทั้งสอง Commit ค่า Choice ของตัวเองแล้ว
      ต้องทำการ Reveal (เปิดเผยค่า) เพื่อให้ Smart Contract ตรวจสอบความถูกต้อง
    2️ อธิบายโค้ด revealChoice()
        2.1 เช็คว่าเกมมีผู้เล่นครบ 2 คนแล้วหรือไม่
            require(numPlayer == 2, "Need 2 players"); 
        2.2 เช็คว่าอยู่ในช่วงเวลาที่กำหนด (Timeout Protection)
            require(block.timestamp <= startTime + timeout, "Reveal phase timed out"); 
        2.3 เช็คว่าผู้เล่นยังไม่ได้ Reveal มาก่อน
            require(!players[msg.sender].hasRevealed, "Already revealed");
        2.4 ตรวจสอบว่าค่า Choice และ Secret ที่ส่งมาตรงกับค่า Commit หรือไม่
            require(players[msg.sender].commitHash == keccak256(abi.encodePacked(_choice, _secret)), "Invalid choice or secret");
        2.5 บันทึกค่า Choice ลงในระบบ
            players[msg.sender].choice = _choice;
            players[msg.sender].hasRevealed = true;
            numRevealed++;
        2.6 เมื่อทั้งสองคน Reveal แล้ว → เรียก _checkWinnerAndPay() เพื่อคำนวณผลแพ้ชนะ
            if (numRevealed == 2) {
                    _checkWinnerAndPay();
            }
    3️ ฟังก์ชัน _checkWinnerAndPay()
      ใช้ตัดสินผลแพ้ชนะ และแจกเงินรางวัลให้กับผู้เล่น
    4 อธิบายโค้ด _checkWinnerAndPay()
        4.1 ดึงค่า Choice ของผู้เล่นมาใช้ตัดสิน
            uint p0Choice = players[playerList[0]].choice;
            uint p1Choice = players[playerList[1]].choice;
        4.2 เก็บ Address ของผู้เล่นทั้งสองเป็นตัวแปร
            address payable account0 = payable(playerList[0]);
            address payable account1 = payable(playerList[1]);
        4.3 ป้องกัน Reentrancy Attack โดยเก็บค่ารางวัลไว้ในตัวแปรแยก
            uint tempReward = reward;
            _resetGame();
        4.4 ตรวจสอบว่าใครเป็นผู้ชนะ ตามกฎของ Rock-Paper-Scissors-Lizard-Spock
            bool p0win = (
                         (p0Choice == 0 && (p1Choice == 2 || p1Choice == 3)) || 
                         (p0Choice == 1 && (p1Choice == 0 || p1Choice == 4)) ||
                         (p0Choice == 2 && (p1Choice == 1 || p1Choice == 3)) ||
                         (p0Choice == 3 && (p1Choice == 1 || p1Choice == 4)) ||
                         (p0Choice == 4 && (p1Choice == 0 || p1Choice == 2))
                         );  
        4.5 แจกเงินรางวัลให้ผู้ชนะ หรือแบ่งครึ่งถ้าเสมอ
            if (p0win) {
                        account0.transfer(tempReward);
            } else if (p1win) {
                        account1.transfer(tempReward);
            } else {
                    account0.transfer(tempReward / 2);
                    account1.transfer(tempReward / 2);
            }
    
