`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.10.2026 21:54:53
// Design Name: 
// Module Name: sync_fifo
// Project Name: 
// Target Devices: Basys 3
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

module sync_fifo # (
    parameter WIDTH = 16,
    parameter DEPTH = 64
) (
    input wire              clk,
    input wire              areset_n,
    input wire              sreset,

    input wire [WIDTH-1:0]  data_in,
    input wire              wr_en,
    input wire              rd_en,

    output wire [WIDTH-1:0] data_out,
    output wire             full,
    output wire             empty
);


// FIFO-related signals
reg [WIDTH-1:0]             fifo [DEPTH-1:0]; // FIFO

reg [$clog2(DEPTH):0]       wr_ptr; // Write pointer
reg [$clog2(DEPTH):0]       rd_ptr; // Read pointer

assign full = (wr_ptr[$clog2(DEPTH)-1:0] == rd_ptr[$clog2(DEPTH)-1:0]) && 
              (wr_ptr[$clog2(DEPTH)] !=  rd_ptr[$clog2(DEPTH)]);

assign empty = (wr_ptr == rd_ptr);

always_ff @(posedge clk or negedge areset_n)
  begin
    if (!areset_n)
      begin
        wr_ptr      <= '0;
        rd_ptr      <= '0;
        fifo        <= '{default : '0};
      end
    else if (sreset)
      begin
        wr_ptr      <= '0;
        rd_ptr      <= '0; 
        fifo        <= '{default : '0};
      end
    else
      begin 
        // Write logic
        if (wr_en && !full)
            begin
                wr_ptr <= wr_ptr + 1;
                fifo[wr_ptr[$clog2(DEPTH)-1:0]] <= data_in;
            end
              
        // Read logic
        if (rd_en && !empty)
            begin
                rd_ptr <= rd_ptr + 1;
            end
      end
  end
  
assign data_out = fifo[rd_ptr[$clog2(DEPTH)-1:0]];

endmodule

`default_nettype wire