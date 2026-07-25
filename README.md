# SPI_I2C_Master/Slave_Design_UVM
SPI 설계 및 UVM 검증, I2C 설계

## 0. Summary

### Overview
- SPI(Serial Peripheral Interface) Specification 분석 및 Master/Slave RTL 설계
- SPI Master와 SPI Slave를 Loopback으로 UVM 검증
- I2C(Inter-Integrated Circuit) Specification 분석 및 Master/Slave RTL 설계

### 개발 환경 및 사용 기술
- Target Board : Basys3 2개(Master, Slave)
- SoC Processor : MicroBlaze
- Tools : Vivado, Vscode
- Language : SystemVerilog
- Protocols : SPI, I2C, UVM

## 1. Introduction & Background
### 1.1 SPI Protocol
<img width="561" height="271" alt="image" src="https://github.com/user-attachments/assets/ddea3481-b60f-415e-8d0f-9ff99bdea73c" />


### 1.2 I2C Protocol
<img width="561" height="265" alt="image" src="https://github.com/user-attachments/assets/3da7a4e7-989d-4104-a415-2348f7bd1012" />
