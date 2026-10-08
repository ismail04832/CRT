// ============================================================================
// File        : crosstalk_mitigation_top.sv
// Description : Top-Level Architecture for the Anti-Crosstalk and Bus-Invert
//               System. Connects Encoder, PHY Interconnect, Decoder, and 
//               includes built-in BIST/Traffic Generation and Statistics Monitors.
// ============================================================================

import bus_pkg::*;

module crosstalk_mitigation_top #(
  parameter int unsigned DATA_WIDTH = BUS_DATA_WIDTH
) (
  // Clock & Reset
  input  logic                        clk,
  input  logic                        rst_n,

  // Configuration Inputs
  input  bus_mode_e                   mode,                // Mode d'opération du bus
  input  logic [$clog2(DATA_WIDTH):0] crosstalk_threshold, // Seuil de tolérance crosstalk
  input  logic                        bist_enable,         // '1' pour utiliser le générateur PRBS interne

  // External System Interface
  input  logic [DATA_WIDTH-1:0]       ext_data_in,         // Entrée de données externe (si bist_enable = 0)
  output logic [DATA_WIDTH-1:0]       ext_data_out,        // Sortie décodée finale

  // Statistics & Monitoring Outputs
  output logic [31:0]                 total_transitions,   // Compteur cumulé de basculements
  output logic [31:0]                 crosstalk_events,    // Compteur cumulé d'événements crosstalk
  output logic                        data_mismatch_error  // Flag d'erreur si data_out != data_in
);

  // --------------------------------------------------------------------------
  // Internal Signals & Packet Wires
  // --------------------------------------------------------------------------
  logic [DATA_WIDTH-1:0] data_to_encode;
  phy_bus_packet_s       phy_bus_lines; // Bus physique (Données encodées + Ctrl)
  logic [DATA_WIDTH-1:0] decoded_data;

  // Registres pour le générateur PRBS (LFSR 32 bits)
  logic [31:0] lfsr_reg;

  // Registre pour le calcul des transitions sur le bus physique
  logic [DATA_WIDTH-1:0] phy_data_prev_reg;

  // --------------------------------------------------------------------------
  // 1. Multiplexeur d'Entrée & PRBS Traffic Generator (LFSR)
  // --------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      lfsr_reg <= 32'hACE1_2815; // Seed non-nulle pour le LFSR
    end else if (bist_enable) begin
      // Polynôme x^32 + x^22 + x^2 + x + 1
      lfsr_reg <= {lfsr_reg[30:0], lfsr_reg[31] ^ lfsr_reg[21] ^ lfsr_reg[1] ^ lfsr_reg[0]};
    end
  end

  // Sélection entre données externes ou trafic BIST interne
  assign data_to_encode = bist_enable ? lfsr_reg : ext_data_in;

  // --------------------------------------------------------------------------
  // 2. Instanciation de l'Émetteur (Bus Encoder)
  // --------------------------------------------------------------------------
  bus_encoder #(
    .DATA_WIDTH(DATA_WIDTH)
  ) u_bus_encoder (
    .clk                (clk),
    .rst_n              (rst_n),
    .mode               (mode),
    .crosstalk_threshold(crosstalk_threshold),
    .data_in            (data_to_encode),
    .phy_tx_packet      (phy_bus_lines)
  );

  // --------------------------------------------------------------------------
  // 3. Instanciation du Récepteur (Bus Decoder)
  // --------------------------------------------------------------------------
  bus_decoder #(
    .DATA_WIDTH(DATA_WIDTH)
  ) u_bus_decoder (
    .phy_rx_packet      (phy_bus_lines),
    .data_out           (decoded_data)
  );

  assign ext_data_out = decoded_data;

  // --------------------------------------------------------------------------
  // 4. Monitoring Logic & Integrity Check
  // --------------------------------------------------------------------------

  // A. Verification d'intégrité de la donnée (data_in vs data_out)
  always_comb begin
    data_mismatch_error = (data_to_encode != decoded_data);
  end

  // B. Compteurs statistiques sur le bus physique
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      phy_data_prev_reg <= '0;
      total_transitions <= '0;
      crosstalk_events  <= '0;
    end else begin
      // Enregistrement de l'historique du bus
      phy_data_prev_reg <= phy_bus_lines.data;

      // Accumulation du nombre total de basculements de bits sur le bus
      total_transitions <= total_transitions + 32'(hamming_distance(phy_bus_lines.data, phy_data_prev_reg));

      // Ingrémentation du compteur si un masque anti-crosstalk est activé (ALT_FLAG = 1)
      if (phy_bus_lines.ctrl_bits[0]) begin
        crosstalk_events <= crosstalk_events + 1'b1;
      end
    end
  end

endmodule : crosstalk_mitigation_top