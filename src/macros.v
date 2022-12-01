`ifndef MACROS
`define MACROS

`define REG_SIZE 32
`define ROB_SIZE 16

`define INST_WID 31:0
`define DATA_WID 31:0
`define ADDR_WID 31:0
`define ROB_POS_WID 3:0
`define REG_POS_WID 4:0
// rob_id = {flag, rob_pos}
// flag: 0 = ready, 1 = renamed
`define ROB_ID_WID 4:0
// width of self-defined opcode
`define OP_WID 5:0

// RISC-V
`define OPCODE_L      7'b0000011
`define OPCODE_S      7'b0100011
`define OPCODE_ARITHI 7'b0010011
`define OPCODE_ARITH  7'b0110011
`define OPCODE_LUI    7'b0110111
`define OPCODE_AUIPC  7'b0010111
`define OPCODE_JAL    7'b1101111
`define OPCODE_JALR   7'b1100111
`define OPCODE_BR     7'b1100011

`endif // MACROS
