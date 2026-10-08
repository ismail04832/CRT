// ============================================================================
// File        : hamming_weight.sv
// Description : Combinational module to calculate Hamming Distance between
//               current and previous bus data, providing an inversion prompt.
// ============================================================================

import bus_pkg::*;

module hamming_weight #(
  parameter int unsigned DATA_WIDTH = BUS_DATA_WIDTH
) (
  // Input Data Ports
  input  logic [DATA_WIDTH-1:0] data_curr, // Nouvelle donnée (cycle t)
  input  logic [DATA_WIDTH-1:0] data_prev, // Donnée précédente (cycle t-1)

  // Output Metrics
  output logic [$clog2(DATA_WIDTH):0] switches_count,  // Nombre total de transitions
  output logic                        invert_recommend // '1' si switches > DATA_WIDTH/2
);

  // --------------------------------------------------------------------------
  // Combinatorial Logic
  // --------------------------------------------------------------------------
  always_comb begin
    // Calcul de la distance de Hamming via la fonction du package bus_pkg
    switches_count = hamming_distance(data_curr, data_prev);

    // Recommandation d'inversion si plus de la moitié des bits basculent
    invert_recommend = (switches_count > (DATA_WIDTH / 2));
  end

endmodule : hamming_weight