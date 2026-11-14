`timescale 1ns/1ps

// mac_unit.v
// Optimized 8-bit MAC with 4-bit Guard Band
// - Input Width (W): 8 bits
// - Product Width: 16 bits
// - Accumulator Width (ACC_W): 20 bits (16-bit product + 4 guard bits)

module mac_unit #(
    parameter integer W      = 8,   
    parameter integer ACC_W  = 20,  // Updated to 20-bit per your specification
    parameter integer SIGNED = 1    
) (
    input                   clk,
    input                   rst_n,      

    // Input side
    input                   valid_in,
    output                  ready_in,
    input                   clear_acc,  
    input      [W-1:0]      a,
    input      [W-1:0]      b,

    // Output side
    output                  valid_out,
    input                   ready_out,
    output reg [ACC_W-1:0]  result
);

    // ---------------------------------------------------------
    // 1. Handshake & Control
    // ---------------------------------------------------------
    assign ready_in = (~valid_out) | ready_out;

    wire accept_in  = valid_in & ready_in;
    wire accept_out = valid_out & ready_out;

    // ---------------------------------------------------------
    // 2. Internal Accumulator
    // ---------------------------------------------------------
    reg [ACC_W-1:0] acc_q;

    // ---------------------------------------------------------
    // 3. 8x8 Multiplication Logic
    // ---------------------------------------------------------
    // Signed views for math
    wire signed [W-1:0]      a_s = a;
    wire signed [W-1:0]      b_s = b;
    
    // The 16-bit product
    wire signed [2*W-1:0]    prod_s = a_s * b_s; 
    wire [2*W-1:0]           prod_u = a * b;     

    // ---------------------------------------------------------
    // 4. Extension to 20-bit and Accumulation
    // ---------------------------------------------------------
    // Extend the 16-bit product to the 20-bit accumulator width
    wire signed [ACC_W-1:0]  prod_s_ext = $signed(prod_s);
    wire [ACC_W-1:0]         prod_u_ext = {{4{1'b0}}, prod_u}; // Zero-pad for unsigned

    // Select base: Clear to 0 or use current accumulator
    wire [ACC_W-1:0] acc_base = clear_acc ? {ACC_W{1'b0}} : acc_q;

    // Perform the MAC operation
    wire [ACC_W-1:0] acc_next = (SIGNED != 0) ? ( $signed(acc_base) + prod_s_ext )
                                              : ( acc_base + prod_u_ext );

    // ---------------------------------------------------------
    // 5. Sequential Logic (Single Cycle Latency)
    // ---------------------------------------------------------
    reg valid_out_r;
    assign valid_out = valid_out_r;

    always @(posedge clk) begin
        if (!rst_n) begin
            acc_q       <= {ACC_W{1'b0}};
            result      <= {ACC_W{1'b0}};
            valid_out_r <= 1'b0;
        end else begin
            // Handshake management
            if (accept_out && !accept_in) begin
                valid_out_r <= 1'b0;
            end

            // Update result on accepted input
            if (accept_in) begin
                acc_q       <= acc_next;
                result      <= acc_next;
                valid_out_r <= 1'b1;
            end
        end
    end

endmodule
