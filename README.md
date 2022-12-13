# RV32I-CPU

A RISC-V CPU written in Verilog. Tomasulo's algorithm is applied to support out-of-order execution.

## FPGA test result

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

Note: Maybe you need to re-program the device before running statement_test to get correct result.
