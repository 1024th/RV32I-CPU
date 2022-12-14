# RV32I-CPU

A RISC-V CPU written in Verilog. Tomasulo's algorithm is applied to support out-of-order execution.

## Modules

- IFetch: Instruction Fetcher with ICache and Branch Predictor.
  - ICache: 16 cache lines, each line contains 16 instructions.  
    Total size: 16\*16\*4=1024 Bytes.  
    Read the entire cache line from memory if cache misses.
  - Branch Predictor: Maintain a 2-bit saturating counter for each entry.  
    Use 8 bits of pc to index into one of 256 counters.
  - Do not issue instruction if RS/LSB/ROB is full in the next cycle.
- Decoder: decode and issue instruction, purely combinational logic. (So whether to issue a new instruction is determined by IFetch.)
  - Extract opcode, funct3, funct7, rs1, rs2, rd, and imm from instruction.
  - For rs1 and rs2,
    - if the register is renamed, calculate its rob_id;
    - if not, read its value from RegFile.
- RegFile: Register File, stores the value of 32 registers (and its rob_id, if it is renamed).
- MemCtrl: Memory Controller, handles memory accesses from IFetch and LSB.
  - Read all the data (e.g. an entire cache line for IFetch, 4 bytes of data for LoadWord) and return it in one cycle with "done" signal set to true.
- RS: Reservation Station. 16 entries.
- ALU: Arithmetic Logic Unit of RS.
- LSB: Load Store Buffer. 16 entries.
  - I/O read should wait until it becomes the head of ROB to avoid the execution of incorrect I/O read (which will destroy later I/O reads).
  - Store instruction should wait until it is committed in ROB.
- ROB: Reorder Buffer. 16 entries.

## FPGA test result

Worst Negative Slack (WNS): 0.108 ns  
Total Negative Slack (TNS): 0.000 ns  
Worst Hold Slack (WHS): 0.014 ns  
Total Hold Slack (THS): 0.000 ns

| testcase       | tims (s)   |
| -------------- | ---------- |
| array_test1    | 0.005639   |
| array_test2    | 0.004625   |
| basicopt1      | 0.014784   |
| bulgarian      | 1.852560   |
| expr           | 0.013958   |
| gcd            | 0.016515   |
| hanoi          | 5.040610   |
| heart          | 758.936490 |
| looper (fixed) | 2.172611   |
| lvalue2        | 0.013724   |
| magic          | 0.026355   |
| manyarguments  | 0.013838   |
| multiarray     | 0.027464   |
| pi             | 1.820310   |
| qsort          | 9.371726   |
| queens         | 4.250924   |
| statement_test | 0.014148   |
| superloop      | 0.021760   |
| tak            | 0.053439   |
| testsleep      | 9.603108   |
| uartboom       | 0.781744   |

Note: Sometimes you need to re-program the device before running statement_test to get correct result.
