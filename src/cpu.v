// RISCV32I CPU top module
// port modification allowed for debugging purposes
`include "mem_ctrl.v"
`include "ifetch.v"
`include "decoder.v"
`include "regfile.v"
`include "rs.v"
`include "alu.v"
`include "lsb.v"
`include "rob.v"
`include "macros.v"

module cpu (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input  wire [ 7:0] mem_din,   // data input bus
    output wire [ 7:0] mem_dout,  // data output bus
    output wire [31:0] mem_a,     // address bus (only 17:0 is used)
    output wire        mem_wr,    // write/read signal (1 for write)

    input wire io_buffer_full,  // 1 if uart buffer is full

    output wire [31:0] dbgreg_dout  // cpu register output (debugging demo)
);

  // implementation goes here

  // Specifications:
  // - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
  // - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
  // - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
  // - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
  // - 0x30000 read: read a byte from input
  // - 0x30000 write: write a byte to output (write 0x00 is ignored)
  // - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
  // - 0x30004 write: indicates program stop (will output '\0' through uart tx)

  // Reorder Buffer rollback signal
  wire                 rollback;
  // if RS/LSB/ROB is full in next cycle, do not issue new instruction
  wire                 rs_nxt_full;
  wire                 lsb_nxt_full;
  wire                 rob_nxt_full;

  // Reservation Station ALU broadcast
  wire                 alu_result;
  wire [`ROB_POS_WID]  alu_result_rob_pos;
  wire [   `DATA_WID]  alu_result_val;
  wire [   `ADDR_WID]  alu_result_pc;
  wire                 alu_result_jump;
  // Load Store Buffer broadcast
  wire                 lsb_result;
  wire [`ROB_POS_WID]  lsb_result_rob_pos;
  wire [   `DATA_WID]  lsb_result_val;

  // Instruction Fetcher <-> Memory Controller
  wire                 if_to_mc_en;
  wire [   `ADDR_WID]  if_to_mc_pc;
  wire                 mc_to_if_done;
  wire [`IF_DATA_WID]  mc_to_if_data;
  // Load Store Buffer <-> Memory Controller
  wire                 lsb_to_mc_en;
  wire                 lsb_to_mc_wr;
  wire [   `ADDR_WID]  lsb_to_mc_addr;
  wire [         2:0 ] lsb_to_mc_len;
  wire [   `DATA_WID]  lsb_to_mc_w_data;
  wire                 mc_to_lsb_done;
  wire [   `DATA_WID]  mc_to_lsb_r_data;

  // Reorder Buffer -> Instruction Fetcher
  wire                 rob_to_if_set_pc_en;
  wire [   `ADDR_WID]  rob_to_if_set_pc;
  wire                 rob_to_if_br;
  wire                 rob_to_if_br_jump;
  wire [   `ADDR_WID]  rob_to_if_br_pc;
  // Instruction Fetcher -> Decoder
  wire                 if_to_dec_inst_rdy;
  wire [   `INST_WID]  if_to_dec_inst;
  wire [   `ADDR_WID]  if_to_dec_inst_pc;
  wire                 if_to_dec_inst_pred_jump;

  MemCtrl u_MemCtrl (
      .clk           (clk_in),
      .rst           (rst_in),
      .rdy           (rdy_in),
      .rollback      (rollback),
      .mem_din       (mem_din),
      .mem_dout      (mem_dout),
      .mem_a         (mem_a),
      .mem_wr        (mem_wr),
      .io_buffer_full(io_buffer_full),
      .if_en         (if_to_mc_en),
      .if_pc         (if_to_mc_pc),
      .if_done       (mc_to_if_done),
      .if_data       (mc_to_if_data),
      .lsb_en        (lsb_to_mc_en),
      .lsb_wr        (lsb_to_mc_wr),
      .lsb_addr      (lsb_to_mc_addr),
      .lsb_len       (lsb_to_mc_len),
      .lsb_w_data    (lsb_to_mc_w_data),
      .lsb_done      (mc_to_lsb_done),
      .lsb_r_data    (mc_to_lsb_r_data)
  );

  IFetch u_IFetch (
      .clk           (clk_in),
      .rst           (rst_in),
      .rdy           (rdy_in),
      .rs_nxt_full   (rs_nxt_full),
      .lsb_nxt_full  (lsb_nxt_full),
      .rob_nxt_full  (rob_nxt_full),
      .inst_rdy      (if_to_dec_inst_rdy),
      .inst          (if_to_dec_inst),
      .inst_pc       (if_to_dec_inst_pc),
      .inst_pred_jump(if_to_dec_inst_pred_jump),
      .mc_en         (if_to_mc_en),
      .mc_pc         (if_to_mc_pc),
      .mc_done       (mc_to_if_done),
      .mc_data       (mc_to_if_data),
      .rob_set_pc_en (rob_to_if_set_pc_en),
      .rob_set_pc    (rob_to_if_set_pc),
      .rob_br        (rob_to_if_br),
      .rob_br_jump   (rob_to_if_br_jump),
      .rob_br_pc     (rob_to_if_br_pc)
  );


  // Decoder issues instruction
  wire                issue;
  wire [`ROB_POS_WID] issue_rob_pos;
  wire [ `OPCODE_WID] issue_opcode;
  wire                issue_is_store;
  wire [ `FUNCT3_WID] issue_funct3;
  wire                issue_funct7;
  wire [   `DATA_WID] issue_rs1_val;
  wire [ `ROB_ID_WID] issue_rs1_rob_id;
  wire [   `DATA_WID] issue_rs2_val;
  wire [ `ROB_ID_WID] issue_rs2_rob_id;
  wire [   `DATA_WID] issue_imm;
  wire [`REG_POS_WID] issue_rd;
  wire [   `ADDR_WID] issue_pc;
  wire                issue_pred_jump;
  wire                issue_is_ready;

  // Decoder query in Register File
  wire [`REG_POS_WID] dec_query_reg_rs1;
  wire [   `DATA_WID] dec_query_reg_rs1_val;
  wire [ `ROB_ID_WID] dec_query_reg_rs1_rob_id;
  wire [`REG_POS_WID] dec_query_reg_rs2;
  wire [   `DATA_WID] dec_query_reg_rs2_val;
  wire [ `ROB_ID_WID] dec_query_reg_rs2_rob_id;
  // Decoder query in Reorder Buffer
  wire [`ROB_POS_WID] dec_query_rob_rs1_pos;
  wire                dec_query_rob_rs1_ready;
  wire [   `DATA_WID] dec_query_rob_rs1_val;
  wire [`ROB_POS_WID] dec_query_rob_rs2_pos;
  wire                dec_query_rob_rs2_ready;
  wire [   `DATA_WID] dec_query_rob_rs2_val;
  // send instruction to Reservation Station
  wire                dec_to_rs_en;
  // send instruction to Load Store Buffer
  wire                dec_to_lsb_en;
  // get next free position of Reorder Buffer
  wire [`ROB_POS_WID] nxt_rob_pos;

  // commit
  wire [`ROB_POS_WID] rob_commit_pos;
  // write to Register
  wire                rob_to_reg_write;
  wire [`REG_POS_WID] rob_to_reg_rd;
  wire [   `DATA_WID] rob_to_reg_val;
  // to Load Store Buffer
  wire                rob_to_lsb_commit_store;

  wire [`ROB_POS_WID] rob_head_pos;

  Decoder u_Decoder (
      .rst               (rst_in),
      .rdy               (rdy_in),
      .rollback          (rollback),
      .inst_rdy          (if_to_dec_inst_rdy),
      .inst              (if_to_dec_inst),
      .inst_pc           (if_to_dec_inst_pc),
      .inst_pred_jump    (if_to_dec_inst_pred_jump),
      .issue             (issue),
      .rob_pos           (issue_rob_pos),
      .opcode            (issue_opcode),
      .is_store          (issue_is_store),
      .funct3            (issue_funct3),
      .funct7            (issue_funct7),
      .rs1_val           (issue_rs1_val),
      .rs1_rob_id        (issue_rs1_rob_id),
      .rs2_val           (issue_rs2_val),
      .rs2_rob_id        (issue_rs2_rob_id),
      .imm               (issue_imm),
      .rd                (issue_rd),
      .pc                (issue_pc),
      .pred_jump         (issue_pred_jump),
      .is_ready          (issue_is_ready),
      .reg_rs1           (dec_query_reg_rs1),
      .reg_rs1_val       (dec_query_reg_rs1_val),
      .reg_rs1_rob_id    (dec_query_reg_rs1_rob_id),
      .reg_rs2           (dec_query_reg_rs2),
      .reg_rs2_val       (dec_query_reg_rs2_val),
      .reg_rs2_rob_id    (dec_query_reg_rs2_rob_id),
      .rob_rs1_pos       (dec_query_rob_rs1_pos),
      .rob_rs1_ready     (dec_query_rob_rs1_ready),
      .rob_rs1_val       (dec_query_rob_rs1_val),
      .rob_rs2_pos       (dec_query_rob_rs2_pos),
      .rob_rs2_ready     (dec_query_rob_rs2_ready),
      .rob_rs2_val       (dec_query_rob_rs2_val),
      .rs_en             (dec_to_rs_en),
      .lsb_en            (dec_to_lsb_en),
      .nxt_rob_pos       (nxt_rob_pos),
      .alu_result        (alu_result),
      .alu_result_rob_pos(alu_result_rob_pos),
      .alu_result_val    (alu_result_val),
      .lsb_result        (lsb_result),
      .lsb_result_rob_pos(lsb_result_rob_pos),
      .lsb_result_val    (lsb_result_val)
  );

  RegFile u_RegFile (
      .clk           (clk_in),
      .rst           (rst_in),
      .rdy           (rdy_in),
      .rollback      (rollback),
      .rs1           (dec_query_reg_rs1),
      .val1          (dec_query_reg_rs1_val),
      .rob_id1       (dec_query_reg_rs1_rob_id),
      .rs2           (dec_query_reg_rs2),
      .val2          (dec_query_reg_rs2_val),
      .rob_id2       (dec_query_reg_rs2_rob_id),
      .issue         (issue),
      .issue_rd      (issue_rd),
      .issue_rob_pos (issue_rob_pos),
      .commit        (rob_to_reg_write),
      .commit_rd     (rob_to_reg_rd),
      .commit_val    (rob_to_reg_val),
      .commit_rob_pos(rob_commit_pos)
  );

  // Reservation Station -> ALU
  wire                rs_to_alu_en;
  wire [ `OPCODE_WID] rs_to_alu_opcode;
  wire [ `FUNCT3_WID] rs_to_alu_funct3;
  wire                rs_to_alu_funct7;
  wire [   `DATA_WID] rs_to_alu_val1;
  wire [   `DATA_WID] rs_to_alu_val2;
  wire [   `DATA_WID] rs_to_alu_imm;
  wire [   `ADDR_WID] rs_to_alu_pc;
  wire [`ROB_POS_WID] rs_to_alu_rob_pos;
  RS u_RS (
      .clk               (clk_in),
      .rst               (rst_in),
      .rdy               (rdy_in),
      .rollback          (rollback),
      .rs_nxt_full       (rs_nxt_full),
      .issue             (dec_to_rs_en),
      .issue_rob_pos     (issue_rob_pos),
      .issue_opcode      (issue_opcode),
      .issue_funct3      (issue_funct3),
      .issue_funct7      (issue_funct7),
      .issue_rs1_val     (issue_rs1_val),
      .issue_rs1_rob_id  (issue_rs1_rob_id),
      .issue_rs2_val     (issue_rs2_val),
      .issue_rs2_rob_id  (issue_rs2_rob_id),
      .issue_imm         (issue_imm),
      .issue_pc          (issue_pc),
      .alu_en            (rs_to_alu_en),
      .alu_opcode        (rs_to_alu_opcode),
      .alu_funct3        (rs_to_alu_funct3),
      .alu_funct7        (rs_to_alu_funct7),
      .alu_val1          (rs_to_alu_val1),
      .alu_val2          (rs_to_alu_val2),
      .alu_imm           (rs_to_alu_imm),
      .alu_pc            (rs_to_alu_pc),
      .alu_rob_pos       (rs_to_alu_rob_pos),
      .alu_result        (alu_result),
      .alu_result_rob_pos(alu_result_rob_pos),
      .alu_result_val    (alu_result_val),
      .lsb_result        (lsb_result),
      .lsb_result_rob_pos(lsb_result_rob_pos),
      .lsb_result_val    (lsb_result_val)
  );
  ALU u_ALU (
      .clk           (clk_in),
      .rst           (rst_in),
      .rdy           (rdy_in),
      .rollback      (rollback),
      .alu_en        (rs_to_alu_en),
      .opcode        (rs_to_alu_opcode),
      .funct3        (rs_to_alu_funct3),
      .funct7        (rs_to_alu_funct7),
      .val1          (rs_to_alu_val1),
      .val2          (rs_to_alu_val2),
      .imm           (rs_to_alu_imm),
      .pc            (rs_to_alu_pc),
      .rob_pos       (rs_to_alu_rob_pos),
      .result        (alu_result),
      .result_rob_pos(alu_result_rob_pos),
      .result_val    (alu_result_val),
      .result_jump   (alu_result_jump),
      .result_pc     (alu_result_pc)
  );

  LSB u_LSB (
      .clk               (clk_in),
      .rst               (rst_in),
      .rdy               (rdy_in),
      .rollback          (rollback),
      .lsb_nxt_full      (lsb_nxt_full),
      .issue             (dec_to_lsb_en),
      .issue_rob_pos     (issue_rob_pos),
      .issue_is_store    (issue_is_store),
      .issue_funct3      (issue_funct3),
      .issue_rs1_val     (issue_rs1_val),
      .issue_rs1_rob_id  (issue_rs1_rob_id),
      .issue_rs2_val     (issue_rs2_val),
      .issue_rs2_rob_id  (issue_rs2_rob_id),
      .issue_imm         (issue_imm),
      .mc_en             (lsb_to_mc_en),
      .mc_wr             (lsb_to_mc_wr),
      .mc_addr           (lsb_to_mc_addr),
      .mc_len            (lsb_to_mc_len),
      .mc_w_data         (lsb_to_mc_w_data),
      .mc_done           (mc_to_lsb_done),
      .mc_r_data         (mc_to_lsb_r_data),
      .result            (lsb_result),
      .result_rob_pos    (lsb_result_rob_pos),
      .result_val        (lsb_result_val),
      .alu_result        (alu_result),
      .alu_result_rob_pos(alu_result_rob_pos),
      .alu_result_val    (alu_result_val),
      .lsb_result        (lsb_result),
      .lsb_result_rob_pos(lsb_result_rob_pos),
      .lsb_result_val    (lsb_result_val),
      .commit_store      (rob_to_lsb_commit_store),
      .commit_rob_pos    (rob_commit_pos),
      .head_rob_pos      (rob_head_pos)
  );

  ROB u_ROB (
      .clk               (clk_in),
      .rst               (rst_in),
      .rdy               (rdy_in),
      .rob_nxt_full      (rob_nxt_full),
      .rollback          (rollback),
      .if_set_pc_en      (rob_to_if_set_pc_en),
      .if_set_pc         (rob_to_if_set_pc),
      .issue             (issue),
      .issue_rd          (issue_rd),
      .issue_opcode      (issue_opcode),
      .issue_pc          (issue_pc),
      .issue_pred_jump   (issue_pred_jump),
      .issue_is_ready    (issue_is_ready),
      .head_rob_pos      (rob_head_pos),
      .commit_rob_pos    (rob_commit_pos),
      .reg_write         (rob_to_reg_write),
      .reg_rd            (rob_to_reg_rd),
      .reg_val           (rob_to_reg_val),
      .lsb_store         (rob_to_lsb_commit_store),
      .commit_br         (rob_to_if_br),
      .commit_br_jump    (rob_to_if_br_jump),
      .commit_br_pc      (rob_to_if_br_pc),
      .alu_result        (alu_result),
      .alu_result_rob_pos(alu_result_rob_pos),
      .alu_result_val    (alu_result_val),
      .alu_result_jump   (alu_result_jump),
      .alu_result_pc     (alu_result_pc),
      .lsb_result        (lsb_result),
      .lsb_result_rob_pos(lsb_result_rob_pos),
      .lsb_result_val    (lsb_result_val),
      .rs1_pos           (dec_query_rob_rs1_pos),
      .rs1_ready         (dec_query_rob_rs1_ready),
      .rs1_val           (dec_query_rob_rs1_val),
      .rs2_pos           (dec_query_rob_rs2_pos),
      .rs2_ready         (dec_query_rob_rs2_ready),
      .rs2_val           (dec_query_rob_rs2_val),
      .nxt_rob_pos       (nxt_rob_pos)
  );


endmodule
