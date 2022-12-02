`ifndef MEM_CTRL
`define MEM_CTRL
`include "macros.v"
module MemCtrl (
    input wire clk,
    input wire rst,
    input wire rdy,

    input  wire [ 7:0] mem_din,   // data input bus
    output reg  [ 7:0] mem_dout,  // data output bus
    output reg  [31:0] mem_a,     // address bus (only 17:0 is used)
    output reg         mem_wr,    // write/read signal (1 for write)

    input wire io_buffer_full,  // 1 if uart buffer is full

    // instruction fetch
    input  wire             if_en,
    input  wire [`ADDR_WID] if_pc,
    output reg              if_done,
    output reg  [`DATA_WID] if_data,

    // Load Store Buffer
    input  wire             lsb_en,
    input  wire             lsb_wr,      // 1 = write
    input  wire [`ADDR_WID] lsb_pc,
    input  wire [      2:0] lsb_len,
    input  wire [`DATA_WID] lsb_w_data,
    output reg              lsb_done,
    output reg  [`DATA_WID] lsb_r_data
);

  localparam IDLE = 0, IF = 1, LOAD = 2, STORE = 3;
  reg [1:0] status;
  reg [2:0] stage;
  reg [2:0] len;

  always @(posedge clk) begin
    if (rst) begin
      status   <= IDLE;
      if_done  <= 0;
      lsb_done <= 0;
      mem_wr   <= 0;
      mem_a    <= 0;
    end else if (!rdy) begin
      if_done  <= 0;
      lsb_done <= 0;
      mem_wr   <= 0;
      mem_a    <= 0;
    end else begin
      if (status != IDLE) begin
        if (stage == len) begin
          stage  <= 3'h0;
          status <= IDLE;
          mem_wr <= 0;
          mem_a  <= 0;
        end else begin
          mem_a <= mem_a + 1;
          stage <= stage + 1;
        end
      end
      mem_wr <= 0;
      case (status)
        IF: begin
          case (stage)
            3'h1: if_data[7:0] <= mem_din;
            3'h2: if_data[15:8] <= mem_din;
            3'h3: if_data[23:16] <= mem_din;
            3'h4: if_data[31:24] <= mem_din;
          endcase
          if (stage == len) begin
            if_done <= 1;
          end
        end
        LOAD: begin
          case (stage)
            3'h1: lsb_r_data[7:0] <= mem_din;
            3'h2: lsb_r_data[15:8] <= mem_din;
            3'h3: lsb_r_data[23:16] <= mem_din;
            3'h4: lsb_r_data[31:24] <= mem_din;
          endcase
          if (stage == len) begin
            lsb_done <= 1;
          end
        end
        STORE: begin
          if (mem_a[17:16] != 2'b11 || !io_buffer_full) begin
            mem_wr <= 1;
            case (stage)
              3'h1: mem_dout <= lsb_w_data[7:0];
              3'h2: mem_dout <= lsb_w_data[15:8];
              3'h3: mem_dout <= lsb_w_data[23:16];
              3'h4: mem_dout <= lsb_w_data[31:24];
            endcase
            if (stage == len) lsb_done <= 1;
          end
        end
        IDLE: begin
          if_done  <= 0;
          lsb_done <= 0;
          if (lsb_en) begin
            status <= lsb_wr ? STORE : LOAD;
            mem_a  <= lsb_pc;
            stage  <= 3'h1;
            len    <= lsb_len;
          end else if (if_en) begin
            status <= IF;
            mem_a  <= if_pc;
            stage  <= 3'h1;
            len    <= 3'd4;
          end
        end
      endcase
    end
  end
endmodule
`endif  // MEM_CTRL
