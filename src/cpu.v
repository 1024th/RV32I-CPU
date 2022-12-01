// RISCV32I CPU top module
// port modification allowed for debugging purposes
`include "mem_ctrl.v"
`include "ifetch.v"
`include "regfile.v"
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

  // Instruction Fetcher <-> Memory Controller
  wire if_to_mc_en;
  wire [`ADDR_WID] if_to_mc_pc;
  wire mc_to_if_done;
  wire [`DATA_WID] mc_to_if_data;
  // Reorder Buffer -> Instruction Fetcher
  wire rob_to_if_pc_en;
  wire [`ADDR_WID] rob_to_if_pc;
  // Instruction Fetcher -> Decoder
  wire if_to_dec_inst_rdy;
  wire [`INST_WID] if_to_dec_inst;

  MemCtrl u_MemCtrl (
      .clk           (clk_in),
      .rst           (rst_in),
      .rdy           (rdy_in),
      .mem_din       (mem_din),
      .mem_dout      (mem_dout),
      .mem_a         (mem_a),
      .mem_wr        (mem_wr),
      .io_buffer_full(io_buffer_full),
      .if_en         (if_to_mc_en),
      .if_pc         (if_to_mc_pc),
      .if_done       (mc_to_if_done),
      .if_data       (mc_to_if_data)
  );

  IFetch u_IFetch (
      .clk      (clk_in),
      .rst      (rst_in),
      .rdy      (rdy_in),
      .inst_rdy (if_to_dec_inst_rdy),
      .inst     (if_to_dec_inst),
      .mc_en    (if_to_mc_en),
      .mc_pc    (if_to_mc_pc),
      .mc_done  (mc_to_if_done),
      .mc_data  (mc_to_if_data),
      .rob_pc_en(rob_to_if_pc_en),
      .rob_pc   (rob_to_if_pc)
  );

  always @(posedge clk_in) begin
    if (rst_in) begin

    end else
    if (!rdy_in) begin

    end else begin

    end
  end

endmodule
