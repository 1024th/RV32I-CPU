`ifndef IFETCH
`define IFETCH
`include "macros.v"
module IFetch (
    input wire clk,
    input wire rst,
    input wire rdy,

    // Reservation Station
    input wire rs_nxt_full,
    // Load Store Buffer
    input wire lsb_nxt_full,
    // Reorder Buffer
    input wire rob_nxt_full,

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
    input wire [`ADDR_WID] rob_set_pc,
    // from Reorder Buffer, update Branch Predictor
    input wire             rob_br,
    input wire             rob_br_jump,
    input wire [`ADDR_WID] rob_br_pc
);

  localparam IDLE = 0, WAIT_MEM = 1;
  reg [`ADDR_WID] pc;
  reg status;

  // Instruction Cache
  reg valid[`ICACHE_BLK_NUM-1:0];
  reg [`ICACHE_TAG_WID] tag[`ICACHE_BLK_NUM-1:0];
  reg [`ICACHE_BLK_WID] data[`ICACHE_BLK_NUM-1:0];

  // Branch Predictor
  reg [`ADDR_WID] pred_pc;
  reg pred_jump;

  wire [`ICACHE_BS_WID] pc_bs = pc[`ICACHE_BS_RANGE];
  wire [`ICACHE_IDX_WID] pc_index = pc[`ICACHE_IDX_RANGE];
  wire [`ICACHE_TAG_WID] pc_tag = pc[`ICACHE_TAG_RANGE];
  wire hit = valid[pc_index] && (tag[pc_index] == pc_tag);
  wire [`ICACHE_IDX_WID] mc_pc_index = mc_pc[`ICACHE_IDX_RANGE];
  wire [`ICACHE_TAG_WID] mc_pc_tag = mc_pc[`ICACHE_TAG_RANGE];

  wire [`ICACHE_BLK_WID] cur_block_raw = data[pc_index];
  wire [`INST_WID] cur_block[15:0];
  wire [`INST_WID] get_inst = cur_block[pc_bs];

  genvar _i;
  generate
    for (_i = 0; _i < `ICACHE_BLK_SIZE / `INST_SIZE; _i = _i + 1) begin
      assign cur_block[_i] = cur_block_raw[_i*32+31:_i*32];
    end
  endgenerate

`ifdef DEBUG
  // wire [`INST_WID] pc_inst_from_cache = data[pc_index][pc_bs];
`endif

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
    end else begin
      if (rob_set_pc_en) begin
        inst_rdy <= 0;
        pc <= rob_set_pc;
        // Do not interrupt current read
        // mc_en <= 0;
        // status <= IDLE;
      end else begin
        if (hit && !rs_nxt_full && !lsb_nxt_full && !rob_nxt_full) begin
          inst_rdy <= 1;
          inst <= get_inst;
          inst_pc <= pc;
          pc <= pred_pc;
          inst_pred_jump <= pred_jump;
        end else begin
          inst_rdy <= 0;
        end
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
          data[mc_pc_index]  <= mc_data;
          mc_en  <= 0;
          status <= IDLE;
        end
      end
    end
  end

  // Branch History Table
  `define BHT_SIZE 256
  `define BHT_IDX_RANGE 9:2
  `define BHT_IDX_WID 7:0
  reg [1:0] bht[`BHT_SIZE-1:0];
  wire [`BHT_IDX_WID] bht_idx = rob_br_pc[`BHT_IDX_RANGE];
  always @(posedge clk) begin
    if (rst) begin
      for (i = 0; i < `BHT_SIZE; i = i + 1) bht[i] <= 0;
    end else if (rdy) begin
      if (rob_br) begin
        if (rob_br_jump) begin
          if (bht[bht_idx] < 2'd3) bht[bht_idx] <= bht[bht_idx] + 1;
        end else begin
          if (bht[bht_idx] > 2'd0) bht[bht_idx] <= bht[bht_idx] - 1;
        end
      end
    end
  end

  // Branch Predictor
  wire [`BHT_IDX_WID] pc_bht_idx = pc[`BHT_IDX_RANGE];
  always @(*) begin
    pred_pc   = pc + 4;
    pred_jump = 0;
    case (get_inst[`OPCODE_RANGE])
      `OPCODE_JAL: begin
        pred_pc   = pc + {{12{get_inst[31]}}, get_inst[19:12], get_inst[20], get_inst[30:21], 1'b0};
        pred_jump = 1;
      end
      `OPCODE_BR: begin
        if (bht[pc_bht_idx] >= 2'd2) begin
          pred_pc   = pc + {{20{get_inst[31]}}, get_inst[7], get_inst[30:25], get_inst[11:8], 1'b0};
          pred_jump = 1;
        end
      end
    endcase
  end

endmodule
`endif  // IFETCH
