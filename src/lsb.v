`ifndef LOAD_STORE_BUFFER
`define LOAD_STORE_BUFFER
`include "macros.v"

module LSB (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire rollback,

    output wire lsb_nxt_full,

    // issue instruction
    input wire                issue,
    input wire [`ROB_POS_WID] issue_rob_pos,
    input wire                issue_is_store,
    input wire [ `FUNCT3_WID] issue_funct3,
    input wire [   `DATA_WID] issue_rs1_val,
    input wire [ `ROB_ID_WID] issue_rs1_rob_id,
    input wire [   `DATA_WID] issue_rs2_val,
    input wire [ `ROB_ID_WID] issue_rs2_rob_id,
    input wire [   `DATA_WID] issue_imm,

    // Memory Controller
    output reg              mc_en,
    output reg              mc_wr,      // 1 = write
    output reg  [`ADDR_WID] mc_addr,
    output reg  [      2:0] mc_len,
    output reg  [`DATA_WID] mc_w_data,
    input  wire             mc_done,
    input  wire [`DATA_WID] mc_r_data,

    // broadcast result
    output reg                result,
    output reg [`ROB_POS_WID] result_rob_pos,
    output reg [   `DATA_WID] result_val,

    // handle the broadcast
    // from Reservation Station
    input wire                alu_result,
    input wire [`ROB_POS_WID] alu_result_rob_pos,
    input wire [   `DATA_WID] alu_result_val,
    // from Load Store Buffer
    input wire                lsb_result,
    input wire [`ROB_POS_WID] lsb_result_rob_pos,
    input wire [   `DATA_WID] lsb_result_val,

    // Reorder Buffer commits store
    input wire                commit_store,
    input wire [`ROB_POS_WID] commit_rob_pos,

    // check if I/O read can be done
    input  wire [`ROB_POS_WID] head_rob_pos
);
  integer i;
  `define LSB_SIZE 16
  `define LSB_POS_WID 3:0
  `define LSB_ID_WID 4:0
  `define LSB_NPOS 5'd16

  reg                busy      [`LSB_SIZE-1:0];
  reg                is_store  [`LSB_SIZE-1:0];
  reg [ `FUNCT3_WID] funct3    [`LSB_SIZE-1:0];
  reg [ `ROB_ID_WID] rs1_rob_id[`LSB_SIZE-1:0];
  reg [   `DATA_WID] rs1_val   [`LSB_SIZE-1:0];
  reg [ `ROB_ID_WID] rs2_rob_id[`LSB_SIZE-1:0];
  reg [   `DATA_WID] rs2_val   [`LSB_SIZE-1:0];
  reg [   `DATA_WID] imm       [`LSB_SIZE-1:0];
  reg [`ROB_POS_WID] rob_pos   [`LSB_SIZE-1:0];
  reg                committed [`LSB_SIZE-1:0];

  reg [`LSB_POS_WID] head, tail;
  reg [`LSB_ID_WID] last_commit_pos;
  reg empty;
  localparam IDLE = 0, WAIT_MEM = 1;
  reg [1:0] status;

  wire [`ADDR_WID] head_addr = rs1_val[head] + imm[head];
  wire head_is_io = head_addr[17:16] == 2'b11;
  wire exec_head = !empty && rs1_rob_id[head][4] == 0 && rs2_rob_id[head][4] == 0 && (!is_store[head] && !rollback && (!head_is_io || rob_pos[head] == head_rob_pos) || committed[head]);
  wire pop = status == WAIT_MEM && mc_done;
  wire [`LSB_POS_WID] nxt_head = head + pop;
  wire [`LSB_POS_WID] nxt_tail = tail + issue;
  // TODO: check
  wire nxt_empty = (nxt_head == nxt_tail && (empty || pop && !issue));
  assign lsb_nxt_full = (nxt_head == nxt_tail && !nxt_empty);

  always @(posedge clk) begin
    if (rst || (rollback && last_commit_pos == `LSB_NPOS)) begin
      status <= IDLE;
      mc_en <= 0;
      head <= 0;
      tail <= 0;
      last_commit_pos <= `LSB_NPOS;
      empty <= 1;
      for (i = 0; i < `LSB_SIZE; i = i + 1) begin
        busy[i]       <= 0;
        is_store[i]   <= 0;
        funct3[i]     <= 0;
        rs1_rob_id[i] <= 0;
        rs1_val[i]    <= 0;
        rs2_rob_id[i] <= 0;
        rs2_val[i]    <= 0;
        imm[i]        <= 0;
        rob_pos[i]    <= 0;
        committed[i]  <= 0;
      end
    end else if (rollback) begin
      // clear uncommitted Load/Store
      tail <= last_commit_pos + 1;
      for (i = 0; i < `LSB_SIZE; i = i + 1) begin
        if (!committed[i]) begin
          busy[i] <= 0;
        end
      end
      if (status == WAIT_MEM && mc_done) begin  // finish
        busy[head] <= 0;
        committed[head] <= 0;
        // Discard load result
        // if (!is_store[head]) begin
        //   result <= 1;
        //   result_val <= mc_r_data;
        //   result_rob_pos <= rob_pos[head];
        // end
        if (last_commit_pos[`LSB_POS_WID] == head) begin
          last_commit_pos <= `LSB_NPOS;
          empty <= 1;
        end
        status <= IDLE;
        mc_en  <= 0;
        head   <= head + 1'b1;
      end
    end else if (!rdy) begin
      ;
    end else begin
      // execute Load or Store
      result <= 0;
      if (status == WAIT_MEM) begin
        if (mc_done) begin  // finish
          busy[head] <= 0;
          committed[head] <= 0;
          if (!is_store[head]) begin
            result <= 1;
            case (funct3[head])
              `FUNCT3_LB:  result_val <= {{24{mc_r_data[7]}}, mc_r_data[7:0]};
              `FUNCT3_LBU: result_val <= {24'b0, mc_r_data[7:0]};
              `FUNCT3_LH:  result_val <= {{16{mc_r_data[15]}}, mc_r_data[15:0]};
              `FUNCT3_LHU: result_val <= {16'b0, mc_r_data[15:0]};
              `FUNCT3_LW:  result_val <= mc_r_data;
            endcase
            result_rob_pos <= rob_pos[head];
          end
          if (last_commit_pos[`LSB_POS_WID] == head) last_commit_pos <= `LSB_NPOS;
          status <= IDLE;
          mc_en  <= 0;
        end
      end else begin  // status == IDLE
        mc_en <= 0;
        if (exec_head) begin
`ifdef DEBUG
          $fdisplay(logfile, "will Exec %s @%t", is_store[head] ? "S" : "L", $realtime);
          $fdisplay(logfile, "  addr:%X, w:%X, rob_pos:%X", head_addr, rs2_val[head],
                    rob_pos[head]);
`endif
          mc_en   <= 1;
          mc_addr <= head_addr;
          if (is_store[head]) begin
            mc_w_data <= rs2_val[head];
            case (funct3[head])
              `FUNCT3_SB: mc_len <= 3'd1;
              `FUNCT3_SH: mc_len <= 3'd2;
              `FUNCT3_SW: mc_len <= 3'd4;
            endcase
            mc_wr <= 1;
          end else begin
            case (funct3[head])
              `FUNCT3_LB, `FUNCT3_LBU: mc_len <= 3'd1;
              `FUNCT3_LH, `FUNCT3_LHU: mc_len <= 3'd2;
              `FUNCT3_LW: mc_len <= 3'd4;
            endcase
            mc_wr <= 0;
          end
          status <= WAIT_MEM;
        end
      end

      // handle broadcast, update values
      if (alu_result)
        for (i = 0; i < `LSB_SIZE; i = i + 1) begin
          if (rs1_rob_id[i] == {1'b1, alu_result_rob_pos}) begin
            rs1_rob_id[i] <= 0;
            rs1_val[i] <= alu_result_val;
          end
          if (rs2_rob_id[i] == {1'b1, alu_result_rob_pos}) begin
            rs2_rob_id[i] <= 0;
            rs2_val[i] <= alu_result_val;
          end
        end

      if (lsb_result)
        for (i = 0; i < `LSB_SIZE; i = i + 1) begin
          if (rs1_rob_id[i] == {1'b1, lsb_result_rob_pos}) begin
            rs1_rob_id[i] <= 0;
            rs1_val[i] <= lsb_result_val;
          end
          if (rs2_rob_id[i] == {1'b1, lsb_result_rob_pos}) begin
            rs2_rob_id[i] <= 0;
            rs2_val[i] <= lsb_result_val;
          end
        end

      // ROB commits store
      if (commit_store) begin
        for (i = 0; i < `LSB_SIZE; i = i + 1)
          if (busy[i] && rob_pos[i] == commit_rob_pos && !committed[i]) begin
            committed[i] <= 1;
            last_commit_pos <= {1'b0, i[`LSB_POS_WID]};
          end
      end

      // add instruction
      if (issue) begin
        busy[tail]       <= 1;
        is_store[tail]   <= issue_is_store;
        funct3[tail]     <= issue_funct3;
        rs1_rob_id[tail] <= issue_rs1_rob_id;
        rs1_val[tail]    <= issue_rs1_val;
        rs2_rob_id[tail] <= issue_rs2_rob_id;
        rs2_val[tail]    <= issue_rs2_val;
        imm[tail]        <= issue_imm;
        rob_pos[tail]    <= issue_rob_pos;
      end

      empty <= nxt_empty;
      head  <= nxt_head;
      tail  <= nxt_tail;
    end
  end

`ifdef DEBUG
  integer logfile;
  initial begin
    logfile = $fopen("lsb.log", "w");
  end
`endif
endmodule
`endif  // LOAD_STORE_BUFFER
