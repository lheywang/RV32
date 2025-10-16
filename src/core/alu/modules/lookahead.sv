`timescale 1ns / 1ps

import core_config_pkg::XLEN;

/*
 *  This module, a different type of adder is used to get faster additions / substractions.
 *
 *  The standard ripple carry was enough on a 32 bits width to handle a 200 MHz+ operation, 
 *  where on the SRT / BOOTH algorithms (64 bits operations), this is not. Thus, here another
 *  architecture, faster but also bigger in term of LUT usage. It shall only be used where
 *  the standard ripple carry isn't meeting the needs.
 */

module lookahead #(
    parameter WIDTH = 32
)(
    input   logic   [(WIDTH - 1) : 0]   a,
    input   logic   [(WIDTH - 1) : 0]   b,
    output  logic   [WIDTH : 0]         out,
    output  logic                       carry
);



endmodule
