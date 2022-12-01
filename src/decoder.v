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

    // decode result, send to other modules
    output wire [`ROB_POS_WID] rob_id,
    output wire [     `OP_WID] op,
    output wire [   `DATA_WID] rs1_val,
    output wire [ `ROB_ID_WID] rs1_rob_id,
    output wire [   `DATA_WID] rs2_val,
    output wire [ `ROB_ID_WID] rs2_rob_id,
    output wire [   `DATA_WID] imm,
    output reg  [`REG_POS_WID] rd,
    output wire [   `ADDR_WID] pc,

    // query in Register File
    output wire [`REG_POS_WID] reg_rs1,
    input  wire [   `DATA_WID] reg_val1,
    input  wire [ `ROB_ID_WID] reg_rob_id1,
    output wire [`REG_POS_WID] reg_rs2,
    input  wire [   `DATA_WID] reg_val2,
    input  wire [ `ROB_ID_WID] reg_rob_id2,
    // write to Register File
    output reg                 reg_en,

    // query in Reorder Buffer
    output wire [`ROB_ID_WID] rob_id1,
    input  wire               rob_ready1,
    input  wire [  `DATA_WID] rob_val1,
    output wire [`ROB_ID_WID] rob_id2,
    input  wire               rob_ready2,
    input  wire [  `DATA_WID] rob_val2,

    // Reservation Station
    input  wire rs_full,
    output reg  rs_en,

    // Load Store Buffer
    input  wire lsb_full,
    output reg  lsb_en,

    // Reorder Buffer
    input  wire                rob_full,
    input  wire [`ROB_POS_WID] nxt_rob_pos,
    output reg                 rob_en,

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


endmodule
`endif  // DECODER
