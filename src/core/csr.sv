`timescale 1ns / 1ps

import core_config_pkg::XLEN;

module csr (
    input   logic                                               clk,

    input   logic                                               we,
    input   logic   [(core_config_pkg::CSR_ADDR_W - 1) : 0]     wa,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]           wd,

    input   logic   [(core_config_pkg::CSR_ADDR_W - 1) : 0]     ra,
    output  logic   [(core_config_pkg::XLEN - 1) : 0]           rd,
    output  logic                                               err,

    // Specials inputs
    input   logic   [(core_config_pkg::XLEN - 1) : 0]           cycleL,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]           cycleH,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]           instructionsL,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]           instructionsH,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]           flushsL,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]           flushsH,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]           waitsL,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]           waitsH,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]           decodedL,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]           decodedH
    
);

    /*
     *  Function to identify the CSR using it's address
     */
    function core_config_pkg::csr_t csr_index(input logic [11:0] addr);
        unique case (addr)
            12'h300: csr_index = core_config_pkg::r_MSTATUS;
            12'h304: csr_index = core_config_pkg::r_MIE;
            12'h305: csr_index = core_config_pkg::r_MTVEC;
            12'h340: csr_index = core_config_pkg::r_MSCRATCH;
            12'h341: csr_index = core_config_pkg::r_MEPC;
            12'h342: csr_index = core_config_pkg::r_MCAUSE;
            12'h343: csr_index = core_config_pkg::r_MTVAL;
            12'h344: csr_index = core_config_pkg::r_MIP;

            12'hB00: csr_index = core_config_pkg::r_CYCLE;
            12'hB02: csr_index = core_config_pkg::r_INSTR;
            12'hB03: csr_index = core_config_pkg::r_FLUSH;
            12'hB04: csr_index = core_config_pkg::r_WAIT;
            12'hB05: csr_index = core_config_pkg::r_DECOD;
            12'hB80: csr_index = core_config_pkg::r_CYCLEH;
            12'hB82: csr_index = core_config_pkg::r_INSTRH;
            12'hB83: csr_index = core_config_pkg::r_FLUSHH;
            12'hB84: csr_index = core_config_pkg::r_WAITH;
            12'hB85: csr_index = core_config_pkg::r_DECODH;

            12'hF10: csr_index = core_config_pkg::r_MISA;
            12'hF11: csr_index = core_config_pkg::r_MVENDORID;
            12'hF12: csr_index = core_config_pkg::r_MARCHID;
            12'hF13: csr_index = core_config_pkg::r_MIMPID;
            12'hF14: csr_index = core_config_pkg::r_MHARTID;
            default: csr_index = core_config_pkg::r_NONE;
        endcase
    endfunction

    /*
     *  Function to apply to compute the new value of the register, including masks.
     */
    function logic [(core_config_pkg::XLEN - 1) : 0] update_bits(
        input logic [(core_config_pkg::XLEN - 1) : 0] reg_value,
        input logic [(core_config_pkg::XLEN - 1) : 0] mask,
        input logic [(core_config_pkg::XLEN - 1) : 0] data);

        update_bits = (data & mask) | (reg_value & ~mask);

    endfunction

    /* 
     *  Storage types
     */
    logic [(core_config_pkg::XLEN - 1) : 0] csrs [(core_config_pkg::r_MVENDORID - 1) : 0];
    core_config_pkg::csr_t wid;
    core_config_pkg::csr_t rid;
    core_config_pkg::csr_t r_wid;
    core_config_pkg::csr_t r_rid;
    logic   [(core_config_pkg::XLEN - 1) : 0] r_wd;

    /*
     *  Comb. logic to assign the right ID to each values, and set the error pin.
     */
    always_comb begin

        wid = csr_index(wa);
        rid = csr_index(ra);

        if (wid == core_config_pkg::r_NONE | rid == core_config_pkg::r_NONE) begin
            err = 1;
        end else begin
            err = 0;
        end
        
    end

    /*
     *  Sync logic, perform  read and writes (2 per cpu cycles !).
     */
    always_ff @( posedge clk ) begin

        // Assigning input values to the counters

        if (we) begin

            if (wid != core_config_pkg::r_NONE) begin

                csrs[wid] <= update_bits(
                    csrs[wid], 
                    core_config_pkg::CSR_WMASK[wid], 
                    r_wd
                ); 

            end
        end
          
        if (rid != core_config_pkg::r_NONE) begin

            unique case (rid)
                core_config_pkg::r_MSTATUS,
                core_config_pkg::r_MIE,
                core_config_pkg::r_MTVEC,
                core_config_pkg::r_MSCRATCH,
                core_config_pkg::r_MEPC,
                core_config_pkg::r_MCAUSE,
                core_config_pkg::r_MTVAL,
                core_config_pkg::r_MIP :    rd <= csrs[rid];

                core_config_pkg::r_CYCLE :  rd <= cycleL;
                core_config_pkg::r_CYCLEH : rd <= cycleH;
                core_config_pkg::r_INSTR :  rd <= instructionsL;
                core_config_pkg::r_INSTRH : rd <= instructionsH;
                core_config_pkg::r_FLUSH :  rd <= flushsL;
                core_config_pkg::r_FLUSHH : rd <= flushsH;
                core_config_pkg::r_WAIT :   rd <= waitsL;
                core_config_pkg::r_WAITH :  rd <= waitsH;
                core_config_pkg::r_DECOD :  rd <= decodedL;
                core_config_pkg::r_DECODH : rd <= decodedH;

                core_config_pkg::r_MVENDORID,
                core_config_pkg::r_MARCHID,
                core_config_pkg::r_MIMPID,
                core_config_pkg::r_MHARTID,
                core_config_pkg::r_MISA :   rd <= 32'h0; // Default value on simple impl.

                default :                   rd <= 32'h0;


            endcase
        end  
     end

endmodule
