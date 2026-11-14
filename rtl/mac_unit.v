`timescale 1ns/1ps
// mac_unit.v
// Synthesizable Multiply-Accumulate (MAC) unit
// - Computes:  acc_next = (clear_acc ? 0 : acc) + (a * b)
// - Output:    result = acc_next (registered)
// - Handshake: valid_in/ready_in and valid_out/ready_out
// - 1-cycle latency from accepted input to valid_out asserted
// - Output held stable when downstream not ready (1-deep buffer)

module mac_unit #(
  parameter integer W      = 16,   // input width
  parameter integer ACC_W  = 40,   // accumulator width (>= 2*W + guard bits)
  parameter integer SIGNED = 1     // 1: signed arithmetic, 0: unsigned
) (
  input                   clk,
  input                   rst_n,       // active-low synchronous reset

  // Input side
  input                   valid_in,
  output                  ready_in,
  input                   clear_acc,  // clears accumulator on accepted transaction
  input      [W-1:0]      a,
  input      [W-1:0]      b,

  // Output side
  output                  valid_out,
  input                   ready_out,
  output reg [ACC_W-1:0]  result
);

  // -----------------------------
  // Handshake (MAC generates ready_in)
  // -----------------------------
  // 1-deep output buffer:
  // - If no valid output is being held, we can accept input.
  // - If holding valid output, we can accept input only if output will be consumed now.
  assign ready_in = (~valid_out) | ready_out;

  wire accept_in  = valid_in & ready_in;
  wire accept_out = valid_out & ready_out;

  // -----------------------------
  // Internal state: accumulator
  // -----------------------------
  reg [ACC_W-1:0] acc_q;

  // -----------------------------
  // Combinational math: acc_next
  // -----------------------------
  // Signed views
  wire signed [W-1:0]      a_s = a;
  wire signed [W-1:0]      b_s = b;
  wire signed [2*W-1:0]    prod_s = a_s * b_s;

  // Unsigned product
  wire [2*W-1:0]           prod_u = a * b;

  // Extend product to ACC_W before adding
  wire signed [ACC_W-1:0]  prod_s_ext = {{(ACC_W-2*W){prod_s[2*W-1]}}, prod_s};
  wire [ACC_W-1:0]         prod_u_ext = {{(ACC_W-2*W){1'b0}}, prod_u};

  // Build the addend (either old acc or 0)
  wire [ACC_W-1:0] acc_base = clear_acc ? {ACC_W{1'b0}} : acc_q;

  // Next accumulator value
  wire [ACC_W-1:0] acc_next =
      (SIGNED != 0) ? ( $signed(acc_base) + prod_s_ext )
                    : ( acc_base + prod_u_ext );

  // -----------------------------
  // Output valid flag (1-deep buffer)
  // -----------------------------
  reg valid_out_r;
  assign valid_out = valid_out_r;

  // -----------------------------
  // Sequential logic
  // -----------------------------
  always @(posedge clk) begin
    if (!rst_n) begin
      acc_q       <= {ACC_W{1'b0}};
      result      <= {ACC_W{1'b0}};
      valid_out_r <= 1'b0;
    end else begin
      // If output consumed and no new input arrives the same cycle, clear valid_out
      if (accept_out && !accept_in) begin
        valid_out_r <= 1'b0;
      end

      // If input is accepted, update accumulator and output register
      if (accept_in) begin
        acc_q       <= acc_next;
        result      <= acc_next;
        valid_out_r <= 1'b1;
      end
      // else: hold state (good for power when idle/stalled)
    end
  end

endmodule