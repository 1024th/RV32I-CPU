`ifndef IFETCH
`define IFETCH
`include "macros.v"
module IFetch (
    input wire clk,
    input wire rst,
    input wire rdy,

    // to Instruction Decoder
    output reg             inst_rdy,
    output reg [`INST_WID] inst,
    output reg [`ADDR_WID] inst_pc,
    output reg             inst_pred_jump,

    // to Memory Controller
    output reg                 mc_en,
    output reg  [   `ADDR_WID] mc_pc,
    input  wire                mc_done,
    input  wire [`IF_DATA_WID] mc_data,

    // from Reorder Buffer, set pc
    input wire             rob_set_pc_en,
    input wire [`ADDR_WID] rob_set_pc
);

  localparam IDLE = 0, WAIT_MEM = 1;
  reg [`ADDR_WID] pc;
  reg status;

  reg valid[`ICACHE_BLK_NUM-1:0];
  reg [`ICACHE_TAG_WID] tag[`ICACHE_BLK_NUM-1:0];
  reg [`INST_WID] data[`ICACHE_BLK_NUM-1:0][`ICACHE_BLK_SIZE-1:0];

  wire [`ICACHE_BS_WID] pc_bs = pc[`ICACHE_BS_RANGE];
  wire [`ICACHE_IDX_WID] pc_index = pc[`ICACHE_IDX_RANGE];
  wire pc_tag = pc[`ICACHE_TAG_RANGE];
  wire hit = valid[pc_index] && (tag[pc_index] == pc_tag);
  wire [`ICACHE_IDX_WID] mc_pc_index = mc_pc[`ICACHE_IDX_RANGE];
  wire mc_pc_tag = mc_pc[`ICACHE_TAG_RANGE];

  wire [`INST_WID] receive_data[`ICACHE_BLK_SIZE-1:0];
  genvar _i;
  generate
    for (_i = 0; _i < `ICACHE_BLK_SIZE; _i = _i + 1) begin
      assign receive_data[_i] = mc_data[_i*32+31:_i*32];
    end
  endgenerate

  integer i, j;
  always @(posedge clk) begin
    if (rst) begin
      pc    <= 32'h0;
      mc_pc <= 32'h0;
      mc_en <= 0;
      for (i = 0; i < `ICACHE_BLK_NUM; i = i + 1) begin
        valid[i] <= 0;
      end
      inst_rdy <= 0;
      status   <= IDLE;
    end else if (!rdy) begin
      ;
    end else if (rob_set_pc_en) begin
      inst_rdy <= 0;
      pc <= rob_set_pc;
      mc_en <= 0;
      status <= IDLE;
    end else begin
      if (hit && data[pc_index][pc_bs] != 0) begin
        inst_rdy <= 1;
        inst <= data[pc_index][pc_bs];
        inst_pc <= pc;
        pc <= pc + 32'h4;  // TODO: predict
        inst_pred_jump <= 0;
      end else begin
        inst_rdy <= 0;
      end
      if (status == IDLE) begin
        if (!hit) begin
          mc_en  <= 1;
          mc_pc  <= {pc[`ICACHE_TAG_RANGE], pc[`ICACHE_IDX_RANGE], 6'b0};
          status <= WAIT_MEM;
        end
      end else begin
        if (mc_done) begin
          valid[mc_pc_index] <= 1;
          tag[mc_pc_index]   <= mc_pc_tag;
          for (i = 0; i < `ICACHE_BLK_SIZE; i++) data[mc_pc_index][i] <= receive_data[i];
          mc_en  <= 0;
          status <= IDLE;
        end
      end
    end
  end

endmodule
`endif  // IFETCH
