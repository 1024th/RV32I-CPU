`ifndef REGFILE
`define REGFILE
`include "macros.v"
module RegFile (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire rollback,

    // query from Decoder, combinational
    input  wire [`REG_POS_WID] rs1,
    output reg  [   `DATA_WID] val1,
    output reg  [ `ROB_ID_WID] rob_id1,
    input  wire [`REG_POS_WID] rs2,
    output reg  [   `DATA_WID] val2,
    output reg  [ `ROB_ID_WID] rob_id2,

    // Decoder issue instruction
    input wire                issue,
    input wire [`REG_POS_WID] issue_rd,
    input wire [`ROB_POS_WID] issue_rob_pos,

    // ReorderBuffer commit
    input wire                commit,
    input wire [`REG_POS_WID] commit_rd,
    input wire [   `DATA_WID] commit_val,
    input wire [`ROB_POS_WID] commit_rob_pos
);

  reg [`DATA_WID] val[`REG_SIZE-1:0];
  reg [`ROB_ID_WID] rob_id[`REG_SIZE-1:0];  // {flag, rob_id}; flag: 0=ready, 1=renamed

  wire real_commit = commit && commit_rd != 0;
  wire is_latest_commit = rob_id[commit_rd] == {1'b1, commit_rob_pos};

`ifdef DEBUG
  wire [  `DATA_WID] sp_val = val[2];
  wire [`ROB_ID_WID] sp_rob_id = rob_id[2];
  wire [  `DATA_WID] ra_val = val[1];
  wire [`ROB_ID_WID] ra_rob_id = rob_id[1];
`endif

  always @(*) begin
    if (real_commit && rs1 == commit_rd && is_latest_commit) begin
      rob_id1 = 5'b0;
      val1 = commit_val;
    end else begin
      rob_id1 = rob_id[rs1];
      val1 = val[rs1];
    end

    if (real_commit && rs2 == commit_rd && is_latest_commit) begin
      rob_id2 = 5'b0;
      val2 = commit_val;
    end else begin
      rob_id2 = rob_id[rs2];
      val2 = val[rs2];
    end
  end

  integer i;
  always @(posedge clk) begin
    if (rst) begin
      for (i = 0; i < 32; i = i + 1) begin
        val[i] <= 32'b0;
        rob_id[i] <= 5'b0;
      end
    end else if (rdy) begin
      // 注意 issue 和 commit 同一个寄存器时: 先 commit 后 issue
      if (real_commit) begin
        val[commit_rd] <= commit_val;
        if (is_latest_commit) rob_id[commit_rd] <= 5'b0;

`ifdef DEBUG
        $fdisplay(logfile, "Reg @%t", $realtime);
        for (i = 0; i < 32; i = i + 8) begin
          $fdisplay(logfile, "%6H %6H %6H %6H %6H %6H %6H %6H", val[i], val[i+1], val[i+2], val[i+3], val[i+4], val[i+5], val[i+6], val[i+7]);
        end
`endif
      end
      if (issue && issue_rd != 0) begin
        rob_id[issue_rd] <= {1'b1, issue_rob_pos};
      end

      if (rollback) begin
        for (i = 0; i < 32; i = i + 1) rob_id[i] <= 5'b0;
      end
    end
  end

`ifdef DEBUG
  integer logfile;
  initial begin
    logfile = $fopen("regfile.log", "w");
  end
`endif
endmodule
`endif  // REGFILE
