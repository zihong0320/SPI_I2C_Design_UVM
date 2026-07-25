# 🗜️ SPI & I2C Master/Slave Design and UVM Verification

> **SystemVerilog 기반 SPI / I2C 프로토콜 설계 및 UVM 루프백 기능 검증**  
> Dual FPGA (Basys3) 보드 간 직렬 통신 실증 및 Synopsys VCS 환경 기반 100% Functional Coverage 달성

---

## 📌 0. Summary

### 🎯 Overview
- **SPI/I2C Specification 분석 & RTL 설계** : Protocol Specification 분석 및 SPI/I2C Master-Slave RTL 설계
- **SPI Loopback Architecture 구성 & UVM 검증** : UVM 기반 Random Testbench 환경에서의 기능 검증
- **FPGA 하드웨어 검증** : Basys3 2대를 활용한 실시간 Board-to-Board 직렬 데이터 송수신 실증 (Switch / FND / LED)

---

### 🛠️ 개발 환경 및 사용 기술

| Category | Details |
| :--- | :--- |
| **Target Board** | Xilinx Basys3 (Artix-7 FPGA) x 2 (Master / Slave) |
| **SoC Processor** | MicroBlaze |
| **Development Tools** | Vivado, VS Code, Synopsys VCS |
| **Languages** | SystemVerilog |
| **Protocols & Arch** | SPI (Mode 0), I2C, UVM, Full/Half-Duplex |

---

## 📚 1. Introduction & Background

### 1.1 SPI Protocol

<p align="center">
  <img width="50%" alt="SPI Protocol" src="https://github.com/user-attachments/assets/ddea3481-b60f-415e-8d0f-9ff99bdea73c" />
</p>

* **주요 특징**
  * Synchronous
  * Full-Duplex
  * Master-Slave (1 : N)
  * SS/CS 기반 Slave 선택
    
* **Signal Ports**:
  * `SCLK` : 동기화를 위한 Master 출력 클럭
  * `MOSI` (Master Out Slave In) : Master ➔ Slave 데이터 전송
  * `MISO` (Master In Slave Out) : Slave ➔ Master 데이터 전송
  * `SS / CS` (Slave/Chip Select) : 타겟 Slave 활성화 신호 (Active Low)


* **SPI Operating Modes (CPOL & CPHA)**
<p align="center">
  <img width="65%" alt="SPI Modes" src="https://github.com/user-attachments/assets/88a17380-5a9d-4742-bbec-cc33ca5a8d92" />
</p>

  * Master와 Slave 간의 클럭 극성(`CPOL`) 및 위상(`CPHA`) 설정이 서로 일치해야 정상적인 데이터 샘플링이 가능
    * **Mode 0 (0,0)**: Idle SCLK = Low / Rising Edge: Read(Sample), Falling Edge: Write(Shift)
    * **Mode 1 (0,1)**: Idle SCLK = Low / Rising Edge: Write(Shift), Falling Edge: Read(Sample)
    * **Mode 2 (1,0)**: Idle SCLK = High / Falling Edge: Read(Sample), Rising Edge: Write(Shift)
    * **Mode 3 (1,1)**: Idle SCLK = High / Falling Edge: Write(Shift), Rising Edge: Read(Sample)

---

### 1.2 I2C Protocol

<p align="center">
  <img width="50%" alt="I2C Protocol" src="https://github.com/user-attachments/assets/3da7a4e7-989d-4104-a415-2348f7bd1012" />
</p>

* **Characteristics**: Synchronous, Half-Duplex, 7-bit Address 기반 Multi-Master/Slave, Open-Drain 구조
* **Signal Ports**:
  * `SCL` (Serial Clock) : 클럭 동기화 신호
  * `SDA` (Serial Data) : 양방향 데이터 신호 (`inout` 포트)


* **Signaling Sequence**
  <p align="center">
    <img width="70%" alt="I2C Timing Protocol" src="https://github.com/user-attachments/assets/94c99341-0db7-42b3-92b2-c987f4d9c354" />
  </p>
  
  * **START Condition**: `SCL` = High 유지 중 `SDA` Falling Edge
  * **STOP Condition**: `SCL` = High 유지 중 `SDA` Rising Edge
  * **Data Valid**: `SCL` = High 동안 `SDA` 데이터 값 유지

* **Inout Port & Bus Driver Control**
  * Half-Duplex 특성상 단일 `SDA` 라인을 공유하므로 High-Impedance (`z`) 상태 제어를 통해 입력/출력 충돌을 방지

---

## ⚙️ 2. Hardware Design

### 2.1 SPI Master / Slave Architecture

| SPI Master Block Diagram | SPI Slave Block Diagram |
| :---: | :---: |
| <img src="https://github.com/user-attachments/assets/74e9face-3062-4c21-85a4-1557a028d82f" width="100%"/> | <img src="https://github.com/user-attachments/assets/e125dd6f-ea3f-42f9-87d4-15b738fd4ec1" width="100%"/> |

* **Master Module**
  * `BTN_Debounce` : Start 버튼 입력 디바운싱을 통한 안정적인 신호 검출
  * `SPI_MASTER` : Mode 0 (`CPOL=0, CPHA=0`) 기준 동작 구현 및 수신 데이터(`rx_data`) LED 출력
  * `FND_Controller` : 송신 데이터(`tx_data`) 및 수신 데이터(`rx_data`) FND 출력
* **Slave Module**
  * `SPI_SLAVE` : Mode 0 (`CPOL=0, CPHA=0`) 기준 동작 구현 및 수신 데이터(`rx_data`) LED 출력
  * `FND_Controller` : 송신 데이터(`tx_data`) 및 수신 데이터(`rx_data`) FND 출력

<br>

<p align="center">
  <img width="80%" alt="SPI Slave FSM" src="https://github.com/user-attachments/assets/09538a6e-6510-4a05-bdaa-d90c41cb9972" /><br>
  <b>[ SPI Slave FSM State Transition (Mode 0 기준) ]</b>
</p>

---

### 2.2 I2C Master / Slave Architecture

| I2C Master Block Diagram | I2C Slave Block Diagram |
| :---: | :---: |
| <img src="https://github.com/user-attachments/assets/490c6c47-3d0c-40e2-8cb6-adca34ac185c" width="100%"/> | <img src="https://github.com/user-attachments/assets/fe589b74-2c36-45f8-9dc8-e6b4393f37bc" width="100%"/> |

* **Master Module**
  * `BTN_Debounce` : Start, Write, Read, Stop 커맨드 버튼 입력 디바운싱
  * `I2C_MASTER` : I2C 커맨드 제어 및 수신 데이터(`rx_data`) LED 출력
  * `FND_Controller` : 송신 데이터(`tx_data`) 및 수신 데이터(`rx_data`) FND 세그먼트 출력
* **Slave Module**
  * `I2C_SLAVE` : Target Address 수신/매칭 및 수신 데이터(`rx_data`) LED 출력
  * `FND_Controller` : 송신 데이터(`tx_data`) 및 수신 데이터(`rx_data`) FND 세그먼트 출력

<br>

<p align="center">
  <img width="85%" alt="I2C Slave FSM" src="https://github.com/user-attachments/assets/287ae3f9-6968-4b59-b1e3-91ffe8e2cb0a" /><br>
  <b>[ I2C Slave FSM State Transition ]</b>
</p>

---

## 🛠️ 3. Hardware Implementation & Mechanism

### 3.1 SPI Board-to-Board Implementation

<p align="center">
  <img width="80%" alt="SPI FPGA Hardware Implementation" src="https://github.com/user-attachments/assets/b72a7f52-69ec-476e-954e-b8d216a3adea" /><br>
  <b>[ SPI Master & Slave Dual Basys3 FPGA 검증 환경 ]</b>
</p>

* **Master FPGA Board Interface**
  * `BTN` : Start 버튼
  * `LED` : 수신 데이터(`rx_data`) ➔ `LED[15:8]` 출력
  * `FND` : 송신 데이터(`tx_data`) ➔ Left 2-Digit, 수신 데이터(`rx_data`) ➔ Right 2-Digit
  * `SW` : 송신 데이터(`tx_data`) 설정 ➔ `SW[7:0]`
* **Slave FPGA Board Interface**
  * `LED` : 수신 데이터(`rx_data`) ➔ `LED[15:8]` 출력
  * `FND` : 송신 데이터(`tx_data`) ➔ Left 2-Digit, 수신 데이터(`rx_data`) ➔ Right 2-Digit
  * `SW` : 송신 데이터(`tx_data`) 설정 ➔ `SW[7:0]`

* **Operation Mechanism**
  * **Write**: Slave에 전달할 8-bit Data를 Master Switch로 입력 ➔ Start 버튼 ➔ Write 수행 (Slave의 FND 및 LED에 수신 데이터 출력)
  * **Read**: Master가 읽어올 8-bit Data를 Slave Switch로 입력 ➔ Start 버튼 ➔ Read 수행 (Master의 FND 및 LED에 수신 데이터 출력)

---

### 3.2 I2C Board-to-Board Implementation

<p align="center">
  <img width="85%" alt="I2C FPGA Hardware Implementation" src="https://github.com/user-attachments/assets/7cce673a-7f87-48ff-b914-2c6ac5e6af60" /><br>
  <b>[ I2C Master & Slave Dual Basys3 FPGA 검증 환경 ]</b>
</p>

* **Master FPGA Board Interface**
  * `BTN` : Command 버튼 (`cmd_start`, `cmd_write`, `cmd_read`, `cmd_stop`)
  * `LED` : 수신 데이터(`rx_data`) ➔ `LED[15:8]` 출력
  * `FND` : 송신 데이터(`tx_data`) ➔ Left 2-Digit, 수신 데이터(`rx_data`) ➔ Right 2-Digit
  * `SW` : 송신 데이터(`tx_data`) 설정 ➔ `SW[7:0]`
* **Slave FPGA Board Interface**
  * `LED` : 수신 데이터(`rx_data`) ➔ `LED[15:8]` 출력
  * `FND` : 송신 데이터(`tx_data`) ➔ Left 2-Digit, 수신 데이터(`rx_data`) ➔ Right 2-Digit
  * `SW` : 송신 데이터(`tx_data`) 설정 ➔ `SW[7:0]`

* **Operation Mechanism**
  * **Write**: Start ➔ Switch로 `{Slave Address[7-bit], 0(Write)}` 입력 ➔ Data Write ➔ Slave에 쓸 8-bit Data 입력 ➔ Write ➔ Stop
  * **Read**: Start ➔ Switch로 `{Slave Address[7-bit], 1(Read)}` 입력 ➔ Read Command ➔ Slave가 전송한 Data Read ➔ Stop

---

## 📈 4. Result & Verification

### 🎬 4.1 Demo Video (SPI Master/Slave)

https://github.com/user-attachments/assets/f85bdbf6-c75f-4c49-ae7a-770c65fcc10a

* **시연 내용**: SPI Protocol 기반 Board-to-Board 실시간 양방향(Full-Duplex) 데이터 송수신 동작 검증

---

### 🎬 4.2 Demo Video (I2C Master/Slave)

https://github.com/user-attachments/assets/898d2a62-41d5-4ec5-955b-9bda2450bc92

* **시연 내용**: Slave Address (`100` / Decimal) 매칭 확인 및 Read/Write 시퀀스 동작 검증

---

### 4.3 SPI UVM Verification (Synopsys VCS)

#### 4.3-1 UVM Architecture
<p align="center">
  <img width="60%" alt="UVM Architecture" src="https://github.com/user-attachments/assets/94fd5795-9b5d-4b79-adc7-56a5c5e990ec" /><br>
  <b>[ UVM Testbench Architecture for SPI Loopback System ]</b>
</p>

* SPI Master와 SPI Slave를 단일 Top Loopback 모듈로 통합 구축 후 UVM Random Constraint 시뮬레이션 수행

---

#### 4.3-2 Simulation Result & Functional Coverage

| UVM Random Test Result Log | Coverage Definition Script |
| :---: | :---: |
| <img src="https://github.com/user-attachments/assets/8a6c8c99-ae53-4c83-8ddb-53be02492ee0" width="100%"/> | <img src="https://github.com/user-attachments/assets/23746421-3d4c-4309-8342-72d33a81d72b" width="85%"/> |
| **Random Test Result (1,999회 PASS)** | **SystemVerilog Coverage Script** |
* **Random Read/Write Test**: 총 **1,999회 Random Transaction 성공 (100% PASS)**

<br>

| **VCS Mode 0 Coverage Result** | **VCS TX Data Coverage (100%)** |
| :---: | :---: |
| <img src="https://github.com/user-attachments/assets/de99223f-96d1-422b-9943-d9169e5e21f5" width="100%"/> | <img src="https://github.com/user-attachments/assets/a549dfbb-3c40-47bd-8647-e6e4677e6267" width="100%"/> |
| **Synopsys VCS Mode 0 Constraint** | **Synopsys VCS Functional Coverage 100%** |
* **Functional Coverage**:
  * `CPOL`, `CPHA`: Mode 0 (`2'b00`) Constraint 설정
  * `TX Data`: Boundary Value (`8'h00`, `8'hFF`) 및 Mid Values (`8'h01` ~ `8'hFE`) 100% 커버리지 달성

---

## 🚨 5. TroubleShooting

### 🚨 UVM Loopback 검증 중 Data Mismatch (All Fail) 발생 현상

| Random Test Fail Log | Data Shift Analysis |
| :---: | :---: |
| <img src="https://github.com/user-attachments/assets/c4b539c9-d229-4400-aa72-9d2ca594f7b4" width="100%"/> | <img src="https://github.com/user-attachments/assets/a46d6154-cc49-49d2-b9f0-f79c3832f965" width="100%"/> |

* **문제 상황 (Problem)**
  * SPI Loopback UVM 검증 환경 실행 시 Master ➔ Slave 전송 데이터에 대해 Scoreboard 비교 결과 **모든 Transaction에서 Mismatch (FAIL) 발생**

* **원인 분석 (Root Cause)**
  * Full-Duplex 동작 검증 시, Slave에 미리 데이터를 Write해두지 않은 상태에서 Write와 Read를 동시 수행함에 따라 Scoreboard에서 `tx_data`와 `rx_data`의 **비교 타이밍 시점 오류** 발생 (데이터 비교가 1-clock cycle씩 지연 출력됨)

* **문제 해결 (Solution)**
  * Slave에서 수신된 `rx_data`를 비교할 때, 현재 전송 중인 `tx_data`가 아닌 이전 클럭에 저장된 `prev_tx_data`와 비교하도록 Scoreboard 및 Monitor 연동 로직 수정

* **고찰 (Retrospective)**
  * Full-Duplex 동작 방식 분석에만 집중하여 Slave 내부 버퍼에 Prior Data가 작성되어 있어야 Read가 정상 수행된다는 하드웨어 시퀀스를 초기 시나리오 설계 단계에서 누락했음을 파악함.
  * UVM Testbench 환경 구성 시 하드웨어의 클럭 단위 Latency와 데이터 파이프라인 구조를 고려한 꼼꼼한 Sequence 시나리오 설계의 중요성을 깨달음
