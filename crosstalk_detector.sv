// ============================================================================
// File        : crosstalk_detector.sv
// Description : Evaluates adjacent bit-line pairs to detect opposing transitions 
//               (0->1 vs 1->0) that cause severe Miller Effect delays.
// ============================================================================

import bus_pkg::*;

module crosstalk_detector #(
  parameter int unsigned DATA_WIDTH = BUS_DATA_WIDTH
) (
  input  logic [DATA_WIDTH-1:0]       data_curr,
  input  logic [DATA_WIDTH-1:0]       data_prev,
  input  logic [$clog2(DATA_WIDTH):0] threshold,
  output logic [$clog2(DATA_WIDTH):0] crosstalk_count,
  output logic                        crosstalk_hazard
);

  // --------------------------------------------------------------------------
  // Combinatorial Analysis of Adjacent Line Pairs
  // --------------------------------------------------------------------------
  always_comb begin
    crosstalk_count = '0;

    // Parcours des 31 paires adjacentes pour un bus 32 bits
    for (int i = 0; i < DATA_WIDTH - 1; i++) begin
      if (is_opposite_transition(
            data_prev[i],   data_curr[i],
            data_prev[i+1], data_curr[i+1]
          )) begin
        crosstalk_count = crosstalk_count + 1'b1;
      end
    end

    // Déclenchement du flag si le nombre de paires en conflit >= seuil
    if (crosstalk_count >= threshold) begin
      crosstalk_hazard = 1'b1;
    end else begin
      crosstalk_hazard = 1'b0;
    end
  end

endmodule : crosstalk_detector