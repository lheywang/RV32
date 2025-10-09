`timescale 1ns / 1ps

import core_config_pkg::XLEN;

module endianess (
    input   logic   [XLEN-1:0]  in,
    output  logic   [XLEN-1:0]  out
);

    always_comb begin
        for (int i = 0; i < (XLEN / 8); i++) begin
            out[i*8 +: 8] = in[((XLEN/8 - 1 - i) * 8) +: 8];
        end
    end
    
endmodule;
