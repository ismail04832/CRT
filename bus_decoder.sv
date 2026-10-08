// ============================================================================
// File        : bus_decoder.sv
// Description : Bus-Invert and Anti-Crosstalk Decoder Module.
//               Reads PHY packet control flags to undo bit inversion and
//               anti-crosstalk masking, restoring original unencoded data.
// ============================================================================

import bus_pkg::*;

module bus_decoder #(
  parameter int unsigned DATA_WIDTH = BUS_DATA_WIDTH
) (
  // PHY Packet Input from Bus
  input  phy_bus_packet_s       phy_rx_packet, // Données encodées + bits de contrôle

  // Restored Output Data
  output logic [DATA_WIDTH-1:0] data_out        // Donnée d'origine restaurée
);

  // --------------------------------------------------------------------------
  // Local Parameters
  // --------------------------------------------------------------------------
  // Masque fixe de déphasage alterné (identique à celui de l'encodeur)
  localparam logic [DATA_WIDTH-1:0] ALT_CROSSTALK_MASK = 32'hAAAA_AAAA;

  // --------------------------------------------------------------------------
  // Combinatorial Decoding Logic
  // --------------------------------------------------------------------------
  always_comb begin
    case (phy_rx_packet.ctrl_bits)
      // ----------------------------------------------------------------------
      // 2'b00 : Aucune modification appliquée à l'émission
      // ----------------------------------------------------------------------
      2'b00: begin
        data_out = phy_rx_packet.data;
      end

      // ----------------------------------------------------------------------
      // 2'b10 : INV_FLAG = 1 (Données inversées par Bus-Invert)
      // ----------------------------------------------------------------------
      2'b10: begin
        data_out = ~phy_rx_packet.data; // Ré-inversion bit-à-bit
      end

      // ----------------------------------------------------------------------
      // 2'b01 : ALT_FLAG = 1 (Masque Anti-Crosstalk appliqué)
      // ----------------------------------------------------------------------
      2'b01: begin
        data_out = phy_rx_packet.data ^ ALT_CROSSTALK_MASK; // Retrait du masque
      end

      // ----------------------------------------------------------------------
      // 2'b11 : INV_FLAG = 1 & ALT_FLAG = 1 (Inversion + Masque combinés)
      // ----------------------------------------------------------------------
      2'b11: begin
        data_out = (~phy_rx_packet.data) ^ ALT_CROSSTALK_MASK;
      end

      default: begin
        data_out = phy_rx_packet.data;
      end
    endcase
  end

endmodule : bus_decoder