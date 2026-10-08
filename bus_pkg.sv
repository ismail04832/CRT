package bus_pkg;

  localparam int unsigned BUS_DATA_WIDTH = 32;
  localparam int unsigned CTRL_WIDTH     = 2;

  typedef enum logic [1:0] {
    MODE_BYPASS         = 2'b00,
    MODE_BUS_INVERT     = 2'b01,
    MODE_ANTI_CROSSTALK = 2'b10,
    MODE_FULL_PROTECT   = 2'b11
  } bus_mode_e;

  typedef struct packed {
    logic [CTRL_WIDTH-1:0]     ctrl_bits;
    logic [BUS_DATA_WIDTH-1:0] data;
  } phy_bus_packet_s;


  function automatic int unsigned count_ones(
    input logic [BUS_DATA_WIDTH-1:0] val
  );
    int unsigned count;

    begin
      count = 0;

      for (int i = 0; i < BUS_DATA_WIDTH; i++) begin
        if (val[i])
          count++;
      end

      return count;
    end
  endfunction


  function automatic int unsigned hamming_distance(
    input logic [BUS_DATA_WIDTH-1:0] a,
    input logic [BUS_DATA_WIDTH-1:0] b
  );

    begin
      return count_ones(a ^ b);
    end

  endfunction


  function automatic logic is_opposite_transition(
    input logic bit_i_prev,
    input logic bit_i_curr,
    input logic bit_next_prev,
    input logic bit_next_curr
  );

    logic trans_i;
    logic trans_next;

    begin
      trans_i    = bit_i_prev ^ bit_i_curr;
      trans_next = bit_next_prev ^ bit_next_curr;

      return (trans_i && trans_next) &&
             (bit_i_curr != bit_next_curr);
    end

  endfunction

endpackage : bus_pkg