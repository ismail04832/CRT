// ============================================================================
// File        : crosstalk_mitigation_sva.sv
// Description : SystemVerilog Assertions (SVA) module for functional and 
//               formal verification of the Anti-Crosstalk and Bus-Invert system.
// ============================================================================

import bus_pkg::*;

module crosstalk_mitigation_sva #(
  parameter int unsigned DATA_WIDTH = BUS_DATA_WIDTH
) (
  input logic                        clk,
  input logic                        rst_n,
  input bus_mode_e                   mode,
  input logic [DATA_WIDTH-1:0]       data_in,
  input phy_bus_packet_s             phy_tx_packet,
  input logic [DATA_WIDTH-1:0]       data_out,
  input logic                        data_mismatch_error
);

  // Default clocking block for formal properties
  default clocking cb @(posedge clk); endclocking
  default disable iff (!rst_n);

  // --------------------------------------------------------------------------
  // 1. DATA INTEGRITY ASSERTIONS (End-to-End Correctness)
  // --------------------------------------------------------------------------

  // Property: Decoded output data must always equal input data (Zero Corruption)
  property p_data_integrity;
    data_out == data_in;
  endproperty

  assert_data_integrity: assert property (p_data_integrity)
    else $error("[SVA ERROR] Data Corruption Detected! data_in = %h, data_out = %h", data_in, data_out);

  // Property: The mismatch flag must stay deasserted ('0')
  property p_no_mismatch_flag;
    !data_mismatch_error;
  endproperty

  assert_no_mismatch_flag: assert property (p_no_mismatch_flag)
    else $error("[SVA ERROR] Mismatch Flag Asserted!");

  // --------------------------------------------------------------------------
  // 2. MODE-SPECIFIC ENCODING ASSERTIONS
  // --------------------------------------------------------------------------

  // Property: In MODE_BYPASS, ctrl_bits must be 2'b00 and data unaltered
  property p_mode_bypass_behavior;
    (mode == MODE_BYPASS) |-> (phy_tx_packet.ctrl_bits == 2'b00) && (phy_tx_packet.data == data_in);
  endproperty

  assert_mode_bypass: assert property (p_mode_bypass_behavior)
    else $error("[SVA ERROR] MODE_BYPASS Violation!");

  // Property: In MODE_BUS_INVERT, ALT_FLAG (ctrl_bits[0]) must never be set
  property p_mode_bus_invert_no_alt;
    (mode == MODE_BUS_INVERT) |-> (phy_tx_packet.ctrl_bits[0] == 1'b0);
  endproperty

  assert_mode_bus_invert_no_alt: assert property (p_mode_bus_invert_no_alt)
    else $error("[SVA ERROR] Invalid ALT_FLAG set during MODE_BUS_INVERT!");

  // Property: In MODE_ANTI_CROSSTALK, INV_FLAG (ctrl_bits[1]) must never be set
  property p_mode_crosstalk_no_inv;
    (mode == MODE_ANTI_CROSSTALK) |-> (phy_tx_packet.ctrl_bits[1] == 1'b0);
  endproperty

  assert_mode_crosstalk_no_inv: assert property (p_mode_crosstalk_no_inv)
    else $error("[SVA ERROR] Invalid INV_FLAG set during MODE_ANTI_CROSSTALK!");

  // --------------------------------------------------------------------------
  // 3. ENCODING TRANSFORMATION VALIDATION
  // --------------------------------------------------------------------------

  // Property: If INV_FLAG is set (without ALT_FLAG), phy_data must be bitwise inverted
  property p_inv_flag_transformation;
    (phy_tx_packet.ctrl_bits == 2'b10) |-> (phy_tx_packet.data == ~data_in);
  endproperty

  assert_inv_flag_transformation: assert property (p_inv_flag_transformation)
    else $error("[SVA ERROR] Incorrect data transformation for INV_FLAG!");

  // Property: If ALT_FLAG is set (without INV_FLAG), phy_data must be XORed with Mask
  property p_alt_flag_transformation;
    (phy_tx_packet.ctrl_bits == 2'b01) |-> (phy_tx_packet.data == (data_in ^ 32'hAAAA_AAAA));
  endproperty

  assert_alt_flag_transformation: assert property (p_alt_flag_transformation)
    else $error("[SVA ERROR] Incorrect data transformation for ALT_FLAG!");

  // Property: If both flags are set (2'b11), both transformations must be applied
  property p_both_flags_transformation;
    (phy_tx_packet.ctrl_bits == 2'b11) |-> (phy_tx_packet.data == ((~data_in) ^ 32'hAAAA_AAAA));
  endproperty

  assert_both_flags_transformation: assert property (p_both_flags_transformation)
    else $error("[SVA ERROR] Incorrect data transformation for Combined Flags (2'b11)!");

  // --------------------------------------------------------------------------
  // 4. COVERAGE POINTS (Functional Coverage Verification)
  // --------------------------------------------------------------------------

  cover_bypass_mode:       cover property (mode == MODE_BYPASS);
  cover_bus_invert_active: cover property (phy_tx_packet.ctrl_bits == 2'b10);
  cover_crosstalk_active:  cover property (phy_tx_packet.ctrl_bits == 2'b01);
  cover_full_protect_both: cover property (phy_tx_packet.ctrl_bits == 2'b11);

endmodule : crosstalk_mitigation_sva