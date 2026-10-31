`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.10.2026 22:09:33
// Design Name: 
// Module Name: sync_fifo_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`default_nettype none

module sync_fifo_tb;

parameter WIDTH      = 16;
parameter DEPTH      = 64;
parameter MAX_ERRORS = 32;
parameter CLK_FREQ   = 100; // MHz
parameter SIM_CYCLES = 100;

// ----------
//  DUT I /O 
// ----------
 
// General
reg                             clk;
reg                             areset_n;
reg                             sreset;
wire [31:0]                     prbs_seed;

// PRBS Gen
wire                            prbs_gen_adv;
wire [WIDTH-1:0]                prbs_gen_out;

// PRBS Check
wire [WIDTH-1:0]                prbs_check_in;
wire                            prbs_check_adv;
wire [$clog2(MAX_ERRORS)-1:0]   errors;
reg                             toggle_check;   // To run toggle coverage of error

// FIFO
reg                             wr_en;
reg                             rd_en;
wire [WIDTH-1:0]                data_out;
wire                            full;
wire                            empty;


// Internal Signals
localparam clk_period = 1000 / CLK_FREQ ; // ns

integer    cycles;

class wr_en_ctrl;
    rand bit [3:0] wr_en_delay;

        constraint non_zero { wr_en_delay > 0; }
endclass

class rd_en_ctrl;
    rand bit [3:0] rd_en_delay; 

    constraint non_zero { rd_en_delay > 0; }
endclass


// Assignments
assign prbs_seed        = {32{1'b1}};
assign prbs_gen_adv     = wr_en && !full;
assign prbs_check_adv   = rd_en && !empty;
assign prbs_check_in    = toggle_check ?  '0 : data_out;

// Clock generation
always #(clk_period/2) clk = !clk;


// Module instantiations

prbs_gen # (
    .OUT_WIDTH  (WIDTH)
) prbs_gen_inst (
    .clk        (clk),
    .areset_n   (areset_n),
    .sreset     (sreset),
    .advance    (prbs_gen_adv),
    .seed       (prbs_seed),
    .out        (prbs_gen_out)
);

prbs_check # (
    .OUT_WIDTH  (WIDTH),
    .MAX_ERRORS (MAX_ERRORS)
) prbs_check_inst (
    .clk        (clk),
    .areset_n   (areset_n),
    .sreset     (sreset),
    .data_in    (prbs_check_in),
    .advance    (prbs_check_adv),
    .seed       (prbs_seed),
    .errors     (errors)
);


sync_fifo # (
    .WIDTH      (WIDTH),
    .DEPTH      (DEPTH)
) sync_fifo_inst (
    .clk        (clk),
    .areset_n   (areset_n),
    .sreset     (sreset),
    .data_in    (prbs_gen_out),
    .wr_en      (wr_en),
    .rd_en      (rd_en),
    .data_out   (data_out),
    .full       (full),
    .empty      (empty) 
);


// Creating class objects
wr_en_ctrl wr_en_ctrl_obj;
rd_en_ctrl rd_en_ctrl_obj;

// Setting defaults
default clocking cb @(posedge clk); endclocking
default disable iff (sreset);

// ------------
//  ASSERTIONS
// ------------

// A1: reset state
a_sreset: assert property (@(posedge clk) disable iff (1'b0) 
                            sreset |=> (empty && !full) );

// A2: mutually exclusive full and empty flags
a_not_full_and_empty: assert property (!(full && empty));

// A3: no overflow/underflow corruption
a_overflow:  assert property ((full && wr_en && !rd_en) |=> full);
a_underflow: assert property ((empty && rd_en && !wr_en) |=> empty);

// A4: transition into full/empty
a_goes_full:  assert property (wr_en && !rd_en && (sync_fifo_inst.rd_ptr - sync_fifo_inst.wr_ptr == 1) |=> full);
a_goes_empty: assert property (rd_en && !wr_en && (sync_fifo_inst.wr_ptr - sync_fifo_inst.rd_ptr == 1) |=> empty);


// ---------------
//   COVERGROUPS
// ---------------
c_full:          cover property ($rose(full));
c_empty_again:   cover property ($rose(empty));
c_rw_when_full:  cover property (full  && wr_en && rd_en);
c_rw_when_empty: cover property (empty && wr_en && rd_en);


covergroup cg_fifo @(posedge clk iff areset_n);
    option.per_instance = 1;

    cp_level: coverpoint sync_fifo_inst.rd_ptr[$clog2(DEPTH)-1:0] {
      bins empty_lvl = {0};
      bins low       = {[1 : DEPTH/4]};
      bins mid       = {[DEPTH/4+1 : 3*DEPTH/4]};
      bins high      = {[3*DEPTH/4+1 : DEPTH-2]};
      bins full_lvl  = {DEPTH-1};
    }

    cp_wr: coverpoint wr_en;
    cp_rd: coverpoint rd_en;

    // Every read/write combination at every fill level
    x_op_level: cross cp_wr, cp_rd, cp_level;

    // Level transitions
    cp_trans: coverpoint sync_fifo_inst.rd_ptr[$clog2(DEPTH)-1:0] {
      bins fill_edge  = (DEPTH-2 => DEPTH-1);
      bins leave_full = (DEPTH => DEPTH-1);
      bins drain_edge = (1 => 0);
      bins leave_empty= (0 => 1);
    }
  endgroup

cg_fifo cg = new();


initial begin
    if ($test$plusargs("trace") != 0) begin
        $display("[%0t] Tracing to logs/vlt_dump.vcd...\n", $time);
        $dumpfile("logs/vlt_dump.fst");
        $dumpvars();
    end

    // Initialise clk,. areset_n amd sreset
    clk      = 0;
    areset_n = 0;
    sreset   = 1;
    wr_en    = 0;
    rd_en    = 0;

    toggle_check = 0;

    // Initialising class objects
    wr_en_ctrl_obj = new();
    rd_en_ctrl_obj = new();

    # (clk_period*8);
    areset_n = 1;

    # (clk_period*4);
    sreset = 0;

    fork
        // Thread to control wr_en
        forever begin
            wr_en = 0;
            wr_en_ctrl_obj.randomize();
            #(wr_en_ctrl_obj.wr_en_delay*clk_period);
            
            wr_en = 1;
            wr_en_ctrl_obj.randomize();
            #(wr_en_ctrl_obj.wr_en_delay*clk_period);
        end

        // Thread to control rd_en
        forever begin
            rd_en = 0;
            rd_en_ctrl_obj.randomize();
            #(rd_en_ctrl_obj.rd_en_delay*clk_period);
            
            rd_en = 1;
            rd_en_ctrl_obj.randomize();
            #(rd_en_ctrl_obj.rd_en_delay*clk_period);
        end

        // Thread to initiate end of simulation
        begin
            cycles = 0;

            while (cycles < SIM_CYCLES) begin
                if (sync_fifo_inst.rd_ptr == DEPTH-1) begin
                    cycles ++;
                end
                #(clk_period);

                if (cycles > 3*SIM_CYCLES/4) toggle_check = 1;
            end
        end
    join_any  // Expecting read process to end 

    $display("Simulation has ended");
    $finish;
end


endmodule

`default_nettype wire

