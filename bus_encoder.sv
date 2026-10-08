// ============================================================================
// File        : bus_encoder.sv
// Description : Main Bus-Invert and Anti-Crosstalk Encoder Top Module.
//               Evaluates transition metrics, applies encoding transformations,
//               and outputs the PHY packet along with control flags.
// ============================================================================

import bus_pkg::*;

module bus_encoder #(
  parameter int unsigned DATA_WIDTH = BUS_DATA_WIDTH
) (
  // Clock & Reset
  input  logic                        clk,
  input  logic                        rst_n,

  // Configuration
  input  bus_mode_e                   mode,                // Mode d'opération
  input  logic [$clog2(DATA_WIDTH):0] crosstalk_threshold, // Seuil pour alerte crosstalk

  // Data Interface
  input  logic [DATA_WIDTH-1:0]       data_in,             // Donnée brute entrante
  output phy_bus_packet_s             phy_tx_packet        // Paquet encodé vers le bus (Data + Ctrl)
);

  // --------------------------------------------------------------------------
  // Internal Signals & Registers
  // --------------------------------------------------------------------------
  logic [DATA_WIDTH-1:0] data_prev_reg; // Registre séquentiel (Donnée transmise à t-1)

  // Signaux d'évaluation issus des blocs de mesure
  logic                  invert_recommend;
  logic                  crosstalk_hazard;
  logic [$clog2(DATA_WIDTH):0] unused_switches_count;
  logic [$clog2(DATA_WIDTH):0] unused_crosstalk_count;

  // Données et contrôles combinatoires calculés
  logic [DATA_WIDTH-1:0] data_encoded_comb;
  logic [CTRL_WIDTH-1:0] ctrl_bits_comb;

  // Mask fixe de déphasage alterné pour éliminer le crosstalk
  localparam logic [DATA_WIDTH-1:0] ALT_CROSSTALK_MASK = 32'hAAAA_AAAA;

  // --------------------------------------------------------------------------
  // Instanciation des Blocs de Mesure (Sub-modules)
  // --------------------------------------------------------------------------

  // 1. Calculateur de Poids/Distance de Hamming
  hamming_weight #(
    .DATA_WIDTH(DATA_WIDTH)
  ) u_hamming_weight (
    .data_curr       (data_in),
    .data_prev       (data_prev_reg),
    .switches_count  (unused_switches_count),
    .invert_recommend(invert_recommend)
  );

  // 2. Détecteur de Crosstalk Pire-Cas
  crosstalk_detector #(
    .DATA_WIDTH(DATA_WIDTH)
  ) u_crosstalk_detector (
    .data_curr       (data_in),
    .data_prev       (data_prev_reg),
    .threshold       (crosstalk_threshold),
    .crosstalk_count (unused_crosstalk_count),
    .crosstalk_hazard(crosstalk_hazard)
  );

  // --------------------------------------------------------------------------
  // Combinatorial Decision & Encoding Logic
  // --------------------------------------------------------------------------
  always_comb begin
    // Valeurs par défaut : Mode BYPASS
    data_encoded_comb = data_in;
    ctrl_bits_comb    = 2'b00; // [1] = INV_FLAG, [0] = ALT_FLAG

    case (mode)
      // ----------------------------------------------------------------------
      // Mode 0: BYPASS (Aucune modification des données)
      // ----------------------------------------------------------------------
      MODE_BYPASS: begin
        data_encoded_comb = data_in;
        ctrl_bits_comb    = 2'b00;
      end

      // ----------------------------------------------------------------------
      // Mode 1: BUS_INVERT (Réduction énergie si > 50% de basculements)
      // ----------------------------------------------------------------------
      MODE_BUS_INVERT: begin
        if (invert_recommend) begin
          data_encoded_comb = ~data_in; // Inversion bit-à-bit
          ctrl_bits_comb    = 2'b10;    // INV_FLAG = 1
        end else begin
          data_encoded_comb = data_in;
          ctrl_bits_comb    = 2'b00;
        end
      end

      // ----------------------------------------------------------------------
      // Mode 2: ANTI_CROSSTALK (Cassure des transitions pires-cas)
      // ----------------------------------------------------------------------
      MODE_ANTI_CROSSTALK: begin
        if (crosstalk_hazard) begin
          data_encoded_comb = data_in ^ ALT_CROSSTALK_MASK; // Application du masque
          ctrl_bits_comb    = 2'b01;                         // ALT_FLAG = 1
        end else begin
          data_encoded_comb = data_in;
          ctrl_bits_comb    = 2'b00;
        end
      end

      // ----------------------------------------------------------------------
      // Mode 3: FULL_PROTECT (Combinaison Inversion + Anti-Crosstalk)
      // ----------------------------------------------------------------------
      MODE_FULL_PROTECT: begin
        case ({invert_recommend, crosstalk_hazard})
          2'b10: begin // Inversion seule recommandée
            data_encoded_comb = ~data_in;
            ctrl_bits_comb    = 2'b10;
          end
          2'b01: begin // Anti-crosstalk seul recommandé
            data_encoded_comb = data_in ^ ALT_CROSSTALK_MASK;
            ctrl_bits_comb    = 2'b01;
          end
          2'b11: begin // Les deux menaces sont détectées simultanément
            data_encoded_comb = (~data_in) ^ ALT_CROSSTALK_MASK;
            ctrl_bits_comb    = 2'b11; // INV_FLAG = 1 & ALT_FLAG = 1
          end
          default: begin
            data_encoded_comb = data_in;
            ctrl_bits_comb    = 2'b00;
          end
        endcase
      end

      default: begin
        data_encoded_comb = data_in;
        ctrl_bits_comb    = 2'b00;
      end
    endcase
  end

  // Affectation de la sortie physique combinatoire
  assign phy_tx_packet.data      = data_encoded_comb;
  assign phy_tx_packet.ctrl_bits = ctrl_bits_comb;

  // --------------------------------------------------------------------------
  // Sequential Logic: History Register Update (t-1)
  // --------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_prev_reg <= '0; // Initialisation du bus à zéro au Reset
    end else begin
      // On sauvegarde la donnée réellement transmise sur les pistes physiques
      data_prev_reg <= data_encoded_comb;
    end
  end

endmodule : bus_encoder