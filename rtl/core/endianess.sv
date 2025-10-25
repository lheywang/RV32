/*
 *  File :      rtl/core/endianess.sv
 *
 *  Author :    l.heywang <leonard.heywang@proton.me>
 *  Date :      25/10.2025
 *  
 *  Brief :     This file is not really a module, because it's only used
 *              to perform the endianess swapping process. This is needed to 
 *              ensure some coherency between the standard (Little Endian) and
 *              the natural (Big Endian). Swap is then realised on the IOs of the 
 *              core, and, on some peripherals.
 */

`timescale 1ns / 1ps

import core_config_pkg::XLEN;

module endianess (
    input  logic [XLEN-1:0] in,
    output logic [XLEN-1:0] out
);

    always_comb begin
        for (int i = 0; i < (XLEN / 8); i++) begin

            out[i*8+:8] = in[((XLEN/8-1-i)*8)+:8];

        end
    end

endmodule
;
