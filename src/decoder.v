`ifndef DECODER
`define DECODER
`include "macros.v"

module Decoder (
    input wire clk,
    input wire rst,
    input wire rdy,

    // from Instruction Fetcher
    input wire             inst_rdy,
    input wire [`INST_WID] inst,
    input wire [`ADDR_WID] inst_pc,

    // issue instruction
    output reg                issue,
    output reg [`ROB_POS_WID] rob_pos,
    output reg [ `OPCODE_WID] opcode,
    output reg [ `FUNCT3_WID] funct3,
    output reg                funct7,
    output reg [   `DATA_WID] rs1_val,
    output reg [ `ROB_ID_WID] rs1_rob_id,
    output reg [   `DATA_WID] rs2_val,
    output reg [ `ROB_ID_WID] rs2_rob_id,
    output reg [   `DATA_WID] imm,
    output reg [`REG_POS_WID] rd,
    output reg [   `ADDR_WID] pc,

    // query in Register File
    output wire [`REG_POS_WID] reg_rs1,
    input  wire [   `DATA_WID] reg_val1,
    input  wire [ `ROB_ID_WID] reg_rob_id1,
    output wire [`REG_POS_WID] reg_rs2,
    input  wire [   `DATA_WID] reg_val2,
    input  wire [ `ROB_ID_WID] reg_rob_id2,

    // query in Reorder Buffer
    output wire [`ROB_POS_WID] rob_pos1,
    input  wire                rob_ready1,
    input  wire [   `DATA_WID] rob_val1,
    output wire [`ROB_POS_WID] rob_pos2,
    input  wire                rob_ready2,
    input  wire [   `DATA_WID] rob_val2,

    // Reservation Station
    input  wire rs_full,
    output reg  rs_en,

    // Load Store Buffer
    input  wire lsb_full,
    output reg  lsb_en,

    // Reorder Buffer
    input wire                rob_full,
    input wire [`ROB_POS_WID] nxt_rob_pos,

    // handle the broadcast
    // from Reservation Station
    input wire rs_result,
    input wire [`ROB_ID_WID] rs_result_rob_id,
    input wire [`DATA_WID] rs_result_val,
    // from Load Store Buffer
    input wire lsb_result,
    input wire [`ROB_ID_WID] lsb_result_rob_id,
    input wire [`DATA_WID] lsb_result_val
);
  assign reg_rs1  = inst[19:15];
  assign reg_rs2  = inst[24:20];
  assign rob_pos1 = reg_rob_id1[`ROB_POS_WID];
  assign rob_pos2 = reg_rob_id2[`ROB_POS_WID];

  always @(posedge clk) begin
    if (!inst_rdy || rs_full || lsb_full) begin
      issue <= 0;
    end else begin
      issue <= 1;
      rob_pos <= nxt_rob_pos;

      opcode <= inst[6:0];
      funct3 <= inst[14:12];
      funct7 <= inst[30];
      rd <= inst[11:7];

      rs1_rob_id <= 0;
      if (reg_rob_id1[4] == 0) begin
        rs1_val <= reg_val1;
      end else if (rob_ready1) begin
        rs1_val <= rob_val1;
      end else if (rs_result && reg_rob_id1 == rs_result_rob_id) begin
        rs1_val <= rs_result_val;
      end else if (lsb_result && reg_rob_id1 == lsb_result_rob_id) begin
        rs1_val <= lsb_result_val;
      end else begin
        rs1_val <= 0;
        rs1_rob_id <= reg_rob_id1;
      end

      rs2_rob_id <= 0;
      if (reg_rob_id2[4] == 0) begin
        rs2_val <= reg_val2;
      end else if (rob_ready2) begin
        rs2_val <= rob_val2;
      end else if (rs_result && reg_rob_id2 == rs_result_rob_id) begin
        rs2_val <= rs_result_val;
      end else if (lsb_result && reg_rob_id2 == lsb_result_rob_id) begin
        rs2_val <= lsb_result_val;
      end else begin
        rs2_val <= 0;
        rs2_rob_id <= reg_rob_id2;
      end

      lsb_en <= 0;
      rs_en  <= 0;
      case (opcode)
        `OPCODE_S: lsb_en <= 1;
        `OPCODE_L: lsb_en <= 1;
        `OPCODE_ARITHI: rs_en <= 1;
        `OPCODE_ARITH: rs_en <= 1;
        `OPCODE_JALR: rs_en <= 1;
        `OPCODE_BR: rs_en <= 1;
      endcase
    end
  end

endmodule
`endif  // DECODER
