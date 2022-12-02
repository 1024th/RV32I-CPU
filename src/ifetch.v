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

    // to Memory Controller
    output reg              mc_en,
    output reg  [`ADDR_WID] mc_pc,
    input  wire             mc_done,
    input  wire [`DATA_WID] mc_data,

    // from Reorder Buffer, set pc
    input wire             rob_set_pc_en,
    input wire [`ADDR_WID] rob_set_pc
);

  localparam IDLE = 0, WAIT_MEM = 1;
  reg [`ADDR_WID] pc;
  reg status;

  // Instruction Cache
  `define ICACHE_SIZE 256
  `define INDEX_RANGE 9:2
  `define TAG_RANGE 31:10
  reg valid[`ICACHE_SIZE-1:0];
  reg [`TAG_RANGE] tag[`ICACHE_SIZE-1:0];
  reg [`DATA_WID] data[`ICACHE_SIZE-1:0];

  wire pc_index = pc[`INDEX_RANGE];
  wire pc_tag = pc[`TAG_RANGE];
  wire hit = valid[pc_index] && (tag[pc_index] == pc_tag);
  wire mc_pc_index = mc_pc[`INDEX_RANGE];
  wire mc_pc_tag = mc_pc[`TAG_RANGE];

  integer i;
  always @(posedge clk) begin
    if (rst) begin
      pc    <= 32'h0;
      mc_pc <= 32'h0;
      mc_en <= 0;
      for (i = 0; i < `ICACHE_SIZE; i = i + 1) begin
        valid[i] <= 0;
      end
    end else
    if (!rdy) begin
    end else if (rob_set_pc_en) begin
      inst_rdy <= 0;
      pc <= rob_set_pc;
      mc_en <= 0;
      status <= IDLE;
    end else begin
      if (hit) begin
        inst_rdy <= 1;
        inst <= data[pc_index];
        inst_pc <= pc;
        pc <= pc + 32'h4;  // TODO: predict
      end else begin
        inst_rdy <= 0;
      end
      if (status == IDLE) begin
        if (!hit) begin
          mc_en  <= 1;
          mc_pc  <= pc;
          status <= WAIT_MEM;
        end
      end else begin
        if (mc_done) begin
          valid[mc_pc_index] <= 1;
          tag[mc_pc_index] <= mc_pc_tag;
          data[mc_pc_index] <= mc_data;
          mc_en <= 0;
          status <= IDLE;
        end
      end
    end
  end

endmodule
`endif  // IFETCH
