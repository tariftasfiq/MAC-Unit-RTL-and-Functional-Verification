`timescale 1ns/1ps

// ============================================================
// 1. ENUMS (8-Bit Functional Scopes)
// ============================================================
typedef enum bit [2:0] {
  BN_BIT_PATTERNS = 3'd0, 
  BN_EXTREME_POS  = 3'd1, 
  BN_EXTREME_NEG  = 3'd2, 
  BN_SMALL_POS    = 3'd3, 
  BN_SMALL_NEG    = 3'd4, 
  BN_MID_RANGE    = 3'd5  
} data_bin_e;

typedef enum bit { ACCUMULATE = 1'b0, CLEAR = 1'b1 } clear_region_e;

typedef enum bit [1:0] {
  ACTIVE_FLOW  = 2'd0, 
  BACKPRESSURE = 2'd1, 
  STARVATION   = 2'd2, 
  DEAD_CYCLE   = 2'd3  
} protocol_region_e;

// ============================================================
// 2. INTERFACE (Updated W=8)
// ============================================================
interface mac_if #(parameter int W=8, ACC_W=40) (input clk);
  logic rst_n, valid_in, ready_in, clear_acc, valid_out, ready_out;
  logic [W-1:0] a, b;
  logic [ACC_W-1:0] result;

  clocking driver_cb @(posedge clk);
    default input #1 output #1;
    output rst_n, valid_in, clear_acc, a, b, ready_out;
    input  ready_in;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1 output #1;
    input rst_n, valid_in, clear_acc, a, b, ready_out, ready_in, valid_out, result;
  endclocking

  modport DRIVER  (clocking driver_cb, input clk);
  modport MONITOR (clocking mon_cb,    input clk);
endinterface

// ============================================================
// 3. TRANSACTION (8-Bit Logic & Mixing Allowed)
// ============================================================
class transaction;
  rand data_bin_e      a_region, b_region;
  rand clear_region_e  c_region;
  rand protocol_region_e p_region;

  rand bit [7:0] a, b; // Compressed to 8-bit
  rand bit clear_acc, valid_in, ready_out;
  bit [39:0] result;
  bit valid_out, ready_in;

  static bit [7:0] pattern_lib [$];

  function new();
    if (pattern_lib.size() == 0) begin
      // 8-bit Structural Patterns
      bit [7:0] base_p[] = '{8'h00, 8'hFF, 8'h55, 8'hAA, 8'h7F, 8'h80};
      foreach(base_p[i]) pattern_lib.push_back(base_p[i]);
      for(int i=0; i<8; i++) begin
        pattern_lib.push_back(1 << i);             // Walking Ones
        pattern_lib.push_back(~(1 << i));          // Walking Zeros
        pattern_lib.push_back((1 << (i+1)) - 1);   // Ripple Masks
      end
      pattern_lib = pattern_lib.unique();
    end
  endfunction

  constraint data_dist_c {
    // 60/20/10/10 Bias - FULL CROSS ENABLED (No Isolation)
    a_region dist {
      BN_EXTREME_POS  := 30, BN_EXTREME_NEG  := 30,
      BN_BIT_PATTERNS := 20, BN_MID_RANGE    := 10,
      BN_SMALL_POS    := 5,  BN_SMALL_NEG    := 5
    };
    b_region dist {
      BN_EXTREME_POS  := 30, BN_EXTREME_NEG  := 30,
      BN_BIT_PATTERNS := 20, BN_MID_RANGE    := 10,
      BN_SMALL_POS    := 5,  BN_SMALL_NEG    := 5
    };
  }

  constraint range_c {
    // 8-bit Signed Range Mapping
    (a_region == BN_BIT_PATTERNS) -> a inside {pattern_lib};
    (a_region == BN_EXTREME_POS)  -> a inside {[8'h70 : 8'h7F]};
    (a_region == BN_EXTREME_NEG)  -> a inside {[8'h80 : 8'h8F]};
    (a_region == BN_SMALL_POS)    -> a inside {[8'h01 : 8'h0F]};
    (a_region == BN_SMALL_NEG)    -> a inside {[8'hF0 : 8'hFF]};
    (a_region == BN_MID_RANGE)    -> a inside {[8'h10 : 8'h6F], [8'h90 : 8'hEF]};

    (b_region == BN_BIT_PATTERNS) -> b inside {pattern_lib};
    (b_region == BN_EXTREME_POS)  -> b inside {[8'h70 : 8'h7F]};
    (b_region == BN_EXTREME_NEG)  -> b inside {[8'h80 : 8'h8F]};
    (b_region == BN_SMALL_POS)    -> b inside {[8'h01 : 8'h0F]};
    (b_region == BN_SMALL_NEG)    -> b inside {[8'hF0 : 8'hFF]};
    (b_region == BN_MID_RANGE)    -> b inside {[8'h10 : 8'h6F], [8'h90 : 8'hEF]};
  }

  constraint control_dist_c {
    c_region dist { ACCUMULATE := 95, CLEAR := 5 };
    p_region dist { ACTIVE_FLOW := 60, BACKPRESSURE := 20, STARVATION := 15, DEAD_CYCLE := 5 };
  }

  constraint control_map_c {
    (c_region == CLEAR)      -> clear_acc == 1'b1;
    (c_region == ACCUMULATE) -> clear_acc == 1'b0;
    (p_region == ACTIVE_FLOW)  -> {valid_in, ready_out} == 2'b11;
    (p_region == BACKPRESSURE) -> {valid_in, ready_out} == 2'b10;
    (p_region == STARVATION)   -> {valid_in, ready_out} == 2'b01;
    (p_region == DEAD_CYCLE)   -> {valid_in, ready_out} == 2'b00;
  }
endclass

// ============================================================
// 4. MONITOR
// ============================================================
class monitor;
  mailbox mon2sb;
  virtual mac_if.MONITOR macif;
  bit [7:0] patterns [$];

  function new(mailbox mon2sb, virtual mac_if.MONITOR macif);
    transaction t = new();
    this.mon2sb = mon2sb;
    this.macif = macif;
    this.patterns = t.pattern_lib;
  endfunction

  function data_bin_e get_bin(bit [7:0] v);
    if (v inside {patterns})        return BN_BIT_PATTERNS;
    if (v >= 8'h70 && v <= 8'h7F)   return BN_EXTREME_POS;
    if (v >= 8'h80 && v <= 8'h8F)   return BN_EXTREME_NEG;
    if (v >= 8'h01 && v <= 8'h0F)   return BN_SMALL_POS;
    if (v >= 8'hF0 && v <= 8'hFF)   return BN_SMALL_NEG;
    return BN_MID_RANGE;
  endfunction

  task main(int count);
    transaction m;
    repeat (4) @(macif.mon_cb);
    repeat (count) begin
      m = new();
      m.a = macif.mon_cb.a; m.b = macif.mon_cb.b;
      m.clear_acc = macif.mon_cb.clear_acc; m.valid_in = macif.mon_cb.valid_in;
      m.ready_out = macif.mon_cb.ready_out; m.ready_in = macif.mon_cb.ready_in;
      m.valid_out = macif.mon_cb.valid_out; m.result = macif.mon_cb.result;
      m.a_region = get_bin(m.a); m.b_region = get_bin(m.b);
      m.c_region = (m.clear_acc) ? CLEAR : ACCUMULATE;
      case ({m.valid_in, m.ready_out})
        2'b11: m.p_region = ACTIVE_FLOW; 2'b10: m.p_region = BACKPRESSURE;
        2'b01: m.p_region = STARVATION;  default: m.p_region = DEAD_CYCLE;
      endcase
      mon2sb.put(m); @(macif.mon_cb);
    end
  endtask
endclass

// ============================================================
// 5. SCOREBOARD (Filtered Output)
// ============================================================
class scoreboard;
  mailbox mon2sb;
  int pass, fail;
  bit signed [39:0] exp_acc = 0;
  bit exp_valid = 0;
  longint bin_sizes [6];
  
  // Tracking Logic
  int unique_hits [6][6][2][4]; 
  bit seen_pairs [6][6][2][4][bit [15:0]]; 

  function new(mailbox mon2sb);
    transaction t = new();
    this.mon2sb = mon2sb;
    
    // Index map:   {Patterns, Ext_Pos, Ext_Neg, Sml_Pos, Sml_Neg, Mid_Rng}
    bin_sizes = '{25,       15,      15,      8,       11,      182};
    
    foreach(unique_hits[a,b,c,p]) unique_hits[a][b][c][p] = 0;
  endfunction

  task main(int count);
    transaction m;
    bit [15:0] current_pair;
    bit exp_ready_in, accept_in, accept_out;

    repeat (count) begin
      mon2sb.get(m);
      
      current_pair = {m.a[7:0], m.b[7:0]}; 
      
      if (!seen_pairs[int'(m.a_region)][int'(m.b_region)][int'(m.c_region)][int'(m.p_region)].exists(current_pair)) begin
        seen_pairs[int'(m.a_region)][int'(m.b_region)][int'(m.c_region)][int'(m.p_region)][current_pair] = 1;
        unique_hits[int'(m.a_region)][int'(m.b_region)][int'(m.c_region)][int'(m.p_region)]++;
      end
      
      exp_ready_in = (~exp_valid) | m.ready_out;
      if (m.ready_in !== exp_ready_in || m.valid_out !== exp_valid) fail++;
      else if (exp_valid && (m.result !== exp_acc)) fail++;
      else pass++;

      accept_in = m.valid_in & exp_ready_in;
      accept_out = exp_valid & m.ready_out;
      if (accept_out && !accept_in) exp_valid = 0;
      if (accept_in) begin
        exp_acc = (m.clear_acc ? 40'sb0 : exp_acc) + ($signed(m.a) * $signed(m.b));
        exp_valid = 1;
      end
    end
    print_report();
  endtask

  // Helper function to print a specific target zone
  function void print_target_zone(data_bin_e a_e, data_bin_e b_e);
    int a = int'(a_e);
    int b = int'(b_e);
    int c = int'(ACCUMULATE);
    int p = int'(ACTIVE_FLOW);
    
    longint combo = bin_sizes[a] * bin_sizes[b];
    real coverage_pct = (real'(unique_hits[a][b][c][p]) / real'(combo)) * 100.0;
    
    if (coverage_pct > 100.0) coverage_pct = 100.0;

    // FIXED: Use string literals instead of .name() for Enum Values
    $display("[%15s x %15s | %10s | %12s] Unique Hits: %0d / %0d (%0.2f%%) %s", 
             a_e.name(), b_e.name(), "ACCUMULATE", "ACTIVE_FLOW", 
             unique_hits[a][b][c][p], combo, coverage_pct,
             (unique_hits[a][b][c][p] >= combo) ? "[FULL]" : "");
  endfunction

  function void print_report();
    $display("\n---------------- 8-BIT UNIQUE COVERAGE REPORT ----------------");
    
    // Explicitly call the 7 requested zones in exact serial order
    print_target_zone(BN_EXTREME_POS,  BN_EXTREME_NEG);
    print_target_zone(BN_EXTREME_NEG,  BN_EXTREME_POS);
    print_target_zone(BN_EXTREME_NEG,  BN_EXTREME_NEG);
    print_target_zone(BN_EXTREME_POS,  BN_EXTREME_POS);
    print_target_zone(BN_BIT_PATTERNS, BN_EXTREME_POS);
    print_target_zone(BN_BIT_PATTERNS, BN_EXTREME_NEG);
    print_target_zone(BN_BIT_PATTERNS, BN_BIT_PATTERNS);

    /* --- COMMENTED OUT THE REST OF THE OUTPUT ---
    data_bin_e a_e, b_e; 
    clear_region_e c_e; 
    protocol_region_e p_e;
    longint combo;
    real coverage_pct;

    for (int a=0; a<6; a++) begin
      for (int b=0; b<6; b++) begin
        for (int c=0; c<2; c++) begin
          for (int p=0; p<4; p++) begin
            if (unique_hits[a][b][c][p] > 0) begin
              combo = bin_sizes[a] * bin_sizes[b];
              a_e = data_bin_e'(a); b_e = data_bin_e'(b);
              c_e = clear_region_e'(c); p_e = protocol_region_e'(p);
              
              coverage_pct = (real'(unique_hits[a][b][c][p]) / real'(combo)) * 100.0;
              if (coverage_pct > 100.0) coverage_pct = 100.0;

              $display("[%15s x %15s | %10s | %12s] Unique Hits: %0d / %0d (%0.2f%%) %s", 
                        a_e.name(), b_e.name(), c_e.name(), p_e.name(), 
                        unique_hits[a][b][c][p], combo, coverage_pct,
                        (unique_hits[a][b][c][p] == combo) ? "[FULL]" : "");
            end
          end
        end
      end
    end
    --------------------------------------------- */
  endfunction
endclass
// ============================================================
// 6. TOP MODULE
// ============================================================
module testbench;
  bit clk;
  int sim_count = 50000; 

  mac_if mif(clk);

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // DUT Instantiated with W=8
  mac_unit #(.W(8), .ACC_W(40), .SIGNED(1)) DUT (
    .clk(clk), .rst_n(mif.rst_n), .valid_in(mif.valid_in), .ready_in(mif.ready_in),
    .clear_acc(mif.clear_acc), .a(mif.a), .b(mif.b), .valid_out(mif.valid_out),
    .ready_out(mif.ready_out), .result(mif.result)
  );

  task run_driver(mailbox g2d);
    transaction t;
    mif.driver_cb.rst_n <= 0; repeat(3) @(mif.driver_cb); mif.driver_cb.rst_n <= 1;
    repeat(sim_count) begin
      g2d.get(t); mif.driver_cb.a <= t.a; mif.driver_cb.b <= t.b;
      mif.driver_cb.clear_acc <= t.clear_acc; mif.driver_cb.valid_in <= t.valid_in;
      mif.driver_cb.ready_out <= t.ready_out; @(mif.driver_cb);
    end
  endtask

  mailbox g2d = new(); mailbox m2s = new();
  monitor mon; scoreboard scb;

  initial begin
    mon = new(m2s, mif.MONITOR);
    scb = new(m2s);
    fork
      begin 
        transaction t;
        // FIXED: Cast randomization to void to satisfy Incisive's strict checking
        repeat(sim_count) begin t = new(); void'(t.randomize()); g2d.put(t); end
      end
      run_driver(g2d);
      mon.main(sim_count);
      scb.main(sim_count);
    join
    $display("\nFINAL RESULT: PASS=%0d FAIL=%0d", scb.pass, scb.fail);
    $finish;
  end
endmodule
