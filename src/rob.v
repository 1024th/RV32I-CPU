`ifndef REORDER_BUFFER
`define REORDER_BUFFER
`include "macros.v"
module ROB (
    input wire clk,
    input wire rst,
    input wire rdy,

    output wire rob_nxt_full,
    output reg  rollback,

    // to Instruction Fetcher, set pc
    output reg if_set_pc_en,
    output reg [`ADDR_WID] if_set_pc,

    // issue an instruction to Reorder Buffer
    input wire                issue,
    input wire [`REG_POS_WID] issue_rd,
    input wire [ `OPCODE_WID] issue_opcode,
    input wire [   `ADDR_WID] issue_pc,
    input wire                issue_pred_jump,

    // commit
    output reg [`ROB_POS_WID] commit_rob_pos,
    // write to Register
    output reg                reg_write,
    output reg [`REG_POS_WID] reg_rd,
    output reg [   `DATA_WID] reg_val,
    // commit store to Load Store Buffer
    output reg                lsb_store,

    // handle the broadcast
    // from Reservation Station
    input wire                alu_result,
    input wire [`ROB_POS_WID] alu_result_rob_pos,
    input wire [   `DATA_WID] alu_result_val,
    input wire                alu_result_jump,
    input wire [   `ADDR_WID] alu_result_pc,
    // from Load Store Buffer
    input wire                lsb_result,
    input wire [`ROB_POS_WID] lsb_result_rob_pos,
    input wire [   `DATA_WID] lsb_result_val,

    // handle the query from Decoder
    input  wire [`ROB_POS_WID] rs1_pos,
    output wire                rs1_ready,
    output wire [   `DATA_WID] rs1_val,
    input  wire [`ROB_POS_WID] rs2_pos,
    output wire                rs2_ready,
    output wire [   `DATA_WID] rs2_val
);

  reg                ready    [`ROB_SIZE-1:0];
  reg [`REG_POS_WID] rd       [`ROB_SIZE-1:0];
  reg [   `DATA_WID] val      [`ROB_SIZE-1:0];
  reg [   `ADDR_WID] pc       [`ROB_SIZE-1:0];
  reg [ `OPCODE_WID] opcode   [`ROB_SIZE-1:0];
  reg                pred_jump[`ROB_SIZE-1:0];  // predict result, 1=jump

  reg [`ROB_POS_WID] head, tail;
  reg empty;
  wire commit = !empty && ready[head];
  wire [`ROB_POS_WID] nxt_head = head + commit;
  wire [`ROB_POS_WID] nxt_tail = tail + issue;
  // TODO: check
  assign rob_nxt_full = (nxt_head == nxt_tail && !empty);
  wire nxt_empty = (nxt_head == nxt_tail && (empty || !issue));

  // handle the query from Decoder
  assign rs1_ready = ready[rs1_pos];
  assign rs1_val   = val[rs1_pos];
  assign rs2_ready = ready[rs2_pos];
  assign rs2_val   = val[rs2_pos];

  integer i;
  always @(posedge clk) begin
    if (rst || rollback) begin
      head <= 0;
      tail <= 0;
      empty <= 1;
      rollback <= 0;
      for (i = 0; i < `ROB_SIZE; i += 1) begin
        ready[i] <= 0;
        rd[i] <= 0;
        val[i] <= 0;
        pc[i] <= 0;
        opcode[i] <= 0;
        pred_jump[i] <= 0;
      end
      reg_write <= 0;
      lsb_store <= 0;
    end else if (!rdy) begin
      ;
    end else begin
      // add instruction
      empty <= nxt_empty;
      if (issue) begin
        rd[tail]        <= issue_rd;
        opcode[tail]    <= issue_opcode;
        pc[tail]        <= issue_pc;
        pred_jump[tail] <= issue_pred_jump;
        if (issue_opcode == `OPCODE_S) ready[tail] <= 1;
        else ready[tail] <= 0;
        tail <= tail + 1'b1;
      end
      // update result
      if (alu_result) begin
        val[alu_result_rob_pos]   <= alu_result_val;
        ready[alu_result_rob_pos] <= 1;
        if (pred_jump[alu_result_rob_pos] != alu_result_jump) begin
          rollback <= 1;
          if_set_pc_en <= 1;
          if_set_pc <= alu_result_pc;
        end
      end
      if (lsb_result) begin
        val[lsb_result_rob_pos]   <= lsb_result_val;
        ready[lsb_result_rob_pos] <= 1;
      end
      // commit
      reg_write <= 0;
      lsb_store <= 0;
      if (commit) begin
        commit_rob_pos <= head;
        if (opcode[head] == `OPCODE_S) begin
          lsb_store <= 1;
        end else begin
          reg_write <= 1;
          reg_rd    <= rd[head];
          reg_val   <= val[head];
        end
        head <= head + 1'b1;
      end
    end
  end

endmodule
`endif  // REORDER_BUFFER
