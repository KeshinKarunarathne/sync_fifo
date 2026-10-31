/*
    This module is used to check a PRBS sequence generated using a 32-bit LFSR according to the following:
    p(x) = x^32 + x^22 + x^2 + 1

*/

`default_nettype none

module prbs_check #(
    parameter OUT_WIDTH  = 16,
    parameter MAX_ERRORS = 32
) (
    input wire                          clk,
    input wire                          areset_n,
    input wire                          sreset,

    input wire [OUT_WIDTH-1:0]          data_in,
    input wire                          advance,
    input wire [31:0]                   seed,

    output reg [$clog2(MAX_ERRORS)-1:0] errors
);


// Internal Signals
logic [31:0]                        lfsr;
logic [31:0]                        lfsr_update;
logic [32+OUT_WIDTH-1:0]            prbs_adv_out;
logic [OUT_WIDTH-1:0]               data_out;

// Function to compute the next state of the LFSR
function [32+OUT_WIDTH-1:0] prbs_adv;
    input logic  [31:0]    curr_lfsr;

    logic [31:0]           next_lfsr;
    logic [OUT_WIDTH-1:0]  curr_out;

    logic                   fb;

    begin
        next_lfsr = curr_lfsr;
        for (int i = 0; i < OUT_WIDTH; i++)
            begin
                fb = next_lfsr[31]^next_lfsr[21]^next_lfsr[1]^next_lfsr[0];
                curr_out[i] = fb;
                next_lfsr = {next_lfsr[30:0], fb};
            end

        prbs_adv = {next_lfsr, curr_out};
    end
endfunction

// Assigining logic
assign prbs_adv_out = prbs_adv(lfsr);
assign lfsr_update  = prbs_adv_out[32+OUT_WIDTH-1 -: 32];
assign data_out     = prbs_adv_out[OUT_WIDTH-1:0];


// Update registers
always_ff @(posedge clk or negedge areset_n) begin
    if (!areset_n) begin 
        lfsr    <= '0;
        errors  <= '0;
    end
    else if (sreset) begin
        lfsr   <= seed;
        errors <= '0;
    end
    else if (advance) begin
        lfsr <= lfsr_update;
        
        // Update error counter
        if (data_out != data_in && errors < {$clog2(MAX_ERRORS){1'b1}}) errors <= errors + 1;
    end
end


endmodule

`default_nettype wire