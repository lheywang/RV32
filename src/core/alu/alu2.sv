`timescale 1ns / 1ps

import core_config_pkg::XLEN;
import core_config_pkg::alu_commands_t;

/* 
 *  ALU 2 & 3 : Used for calculating advanced maths 
        - Multiplications
        - Divisions
        - Bits shifts (multiple cycles to reduce logic cost)
 */


module alu2 (
    // Standard interface
    input   logic                                           clk,
    input   logic                                           rst_n,

    // Issuer interface
    input   logic   [(core_config_pkg::XLEN - 1) : 0]       arg0,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]       arg1,
    /* verilator lint_off UNUSEDSIGNAL */
    input   logic   [(core_config_pkg::XLEN - 1) : 0]       addr,
    input   logic   [(core_config_pkg::XLEN - 1) : 0]       imm,
    /* verilator lint_off UNUSEDSIGNAL */
    input   alu_commands_t                                  cmd,
    input   logic   [(core_config_pkg::REG_ADDR_W - 1) : 0] i_rd,
    output  logic                                           busy,
    output  logic                                           i_error,

    // Commiter interface
    output  logic   [(core_config_pkg::XLEN - 1) : 0]       res,
    output  logic   [(core_config_pkg::REG_ADDR_W - 1) : 0] o_rd,
    output  logic                                           valid,
    output  logic                                           o_error,
    output  logic                                           req,
    input   logic                                           clear

    // Additionnal interface (optionnal)
    // None for this ALU.                  
);

    /*
     *  Functions definition
     */

    function logic [33:0] booth_partial(
        input logic [3:0] factor, 
        input logic [31:0] A);
        unique case (factor)
            4'b0000, 4'b1111 : booth_partial = 0;
            4'b0001, 4'b0010 : booth_partial = {A[31], A[31], A};
            4'b0011, 4'b0100 : booth_partial = {A[31], A, 1'b0};
            4'b0101, 4'b0110 : booth_partial = {A[31], A, 1'b0} + {A[31], A[31], A};
            4'b0111 :          booth_partial = {A, 2'b0};
            4'b1000 :          booth_partial = -{A, 2'b0};
            4'b1001, 4'b1010 : booth_partial = -({A[31], A, 1'b0} + {A[31], A[31], A});
            4'b1011, 4'b1100 : booth_partial = -({A[31], A, 1'b0});
            4'b1101, 4'b1110 : booth_partial = -({A[31], A[31], A});
        endcase
    endfunction

    function logic signed [3:0] str_estimate(
        input logic [5 : 0] R_top,
        input logic [5 : 0] D_top);

        if      (R_top >= (D_top << 1))                     str_estimate = 4;
        else if (R_top >= (D_top + D_top + D_top) >> 1)     str_estimate = 3;
        else if (R_top >= D_top)                            str_estimate = 2;
        else if (R_top >= (D_top >> 1))                     str_estimate = 1;
        else if (R_top > -(D_top >> 1))                     str_estimate = 0;
        else if (R_top > -(D_top))                          str_estimate = -1;
        else if (R_top > -(D_top + D_top + D_top) >> 1)     str_estimate = -2;
        else if (R_top > -(D_top << 1))                     str_estimate = -3;
        else                                                str_estimate = -4;

    endfunction

    /*
     *  Enums
     */

    typedef enum logic [1:0] {IDLE, CALC, OUT} MEM_FSM;
    typedef enum logic [3:0] {SLL, SRL, SRA, MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU} OP;

    /*
     *  Storages types
     */
    // Temporary variables
    logic   [(2 * core_config_pkg::XLEN) : 0]               res1;   // Will be used as product or Quotient
    logic   [core_config_pkg::XLEN : 0]                     res2;   // Will be used as B_ext or Reminder
    logic   [(core_config_pkg::XLEN ) : 0]                  q_digit;

    // Sign correction logic
    logic   [(core_config_pkg::XLEN - 1) : 0]               absA;
    logic   [(core_config_pkg::XLEN - 1) : 0]               absB;
    logic                                                   signA;
    logic                                                   signB;
    logic                                                   sign;
    logic                                                   sign_enabled;
    logic                                                   shift_en;
    logic                                                   shift_dir;

    // Registered values
    logic   [(2 * core_config_pkg::XLEN) : 0]               r_res1;   // Will be used as product or Quotient
    logic   [core_config_pkg::XLEN : 0]                     r_res2;   // Will be used as B_ext or Reminder

    // Sign correction logic
    logic   [(core_config_pkg::XLEN - 1) : 0]               r_absA;
    logic   [(core_config_pkg::XLEN - 1) : 0]               r_absB;
    logic                                                   r_signA;
    logic                                                   r_signB;
    logic                                                   r_sign;
    logic                                                   r_sign_enabled;

    // FSM Controls signals
    logic                                                   unknown_instr;
    logic                                                   ended;
    MEM_FSM                                                 state;
    MEM_FSM                                                 next_state;
    logic   [4 : 0]                                         cycles_cnt;
    logic   [4 : 0]                                         new_cycles_cnt;
    logic   [4 : 0]                                         updated_cycle_cnt;
    OP                                                      op;
    OP                                                      r_op;

    // Misc signals
    logic   [(core_config_pkg::REG_ADDR_W - 1) : 0]         r_rd;


    /*
     *  First, identify and trigger the calculations
     */
    always_comb begin

        unique case (cmd)

            /*
             *  Shifts operations
             */
            core_config_pkg::c_SLL : begin
                // Calculation
                res1 = 0;
                res2 = 0;
                absA = arg0;
                absB = 0;
                signA = 0;
                signB = 0;
                sign = 0;
                sign_enabled = 0;
                // Getting the number of cycles by ignoring the 26 MSB and dividing by 8 
                // (we can perform an 8 bit shift max per cycle).
                new_cycles_cnt = arg1[4  :0]; 
                op = SLL;

                // Setting flags
                unknown_instr = 0;
            end
            core_config_pkg::c_SRL : begin
                // Calculation
                res1 = 0;
                res2 = 0;
                absA = arg0;
                absB = 0;
                signA = 0;
                signB = 0;
                sign = 0;
                sign_enabled = 0;
                // Getting the number of cycles by ignoring the 26 MSB and dividing by 8 
                // (we can perform an 8 bit shift max per cycle).
                new_cycles_cnt = arg1[4  :0]; 
                op = SRL;

                // Setting flags
                unknown_instr = 0;
            end 
            core_config_pkg::c_SRA : begin
                // Calculation
                res1 = 0;
                res2 = 0;
                absA = arg0;
                absB = 0;
                signA = 0;
                signB = 0;
                sign = 0;
                sign_enabled = 0;
                // Getting the number of cycles by ignoring the 26 MSB and dividing by 8 
                // (we can perform an 8 bit shift max per cycle).
                new_cycles_cnt = arg1[4  :0]; 
                op = SRA;

                // Setting flags
                unknown_instr = 0;
            end 

            /*
             *  Multiplications and divisions 
             */
            core_config_pkg::c_MUL : begin
                // Calculation
                absA = ($signed(arg0) < 0) ? -arg0 : arg0;
                absB = ($signed(arg1) < 0) ? -arg1 : arg1;
                res1 = 0;
                res2 = {absB, 1'b0}; // B_ext
                signA = ($signed(arg0) < 0) ? 1 : 0;
                signB = ($signed(arg1) < 0) ? 1 : 0;
                sign = signA ^ signB;
                sign_enabled = 0;
                new_cycles_cnt = 11;
                op = MUL;

                // Setting flags
                unknown_instr = 0;
            end
            core_config_pkg::c_MULH : begin
                // Calculation
                absA = ($signed(arg0) < 0) ? -arg0 : arg0;
                absB = ($signed(arg1) < 0) ? -arg1 : arg1;
                res1 = 0;
                res2 = {absB, 1'b0}; // B_ext
                signA = ($signed(arg0) < 0) ? 1 : 0;
                signB = ($signed(arg1) < 0) ? 1 : 0;
                sign = signA ^ signB;
                sign_enabled = 1;
                new_cycles_cnt = 11;
                op = MULH;

                // Setting flags
                unknown_instr = 0;
            end
            core_config_pkg::c_MULHSU : begin
                // Calculation
                absA = ($signed(arg0) < 0) ? -arg0 : arg0;
                absB = ($signed(arg1) < 0) ? -arg1 : arg1;
                res1 = 0;
                res2 = {absB, 1'b0}; // B_ext
                signA = ($signed(arg0) < 0) ? 1 : 0;
                signB = ($signed(arg1) < 0) ? 1 : 0;
                sign = signA ^ signB;
                sign_enabled = 1;
                new_cycles_cnt = 11;
                op = MULHSU;

                // Setting flags
                unknown_instr = 0;
            end
            core_config_pkg::c_MULHU : begin
                // Calculation
                absA = ($signed(arg0) < 0) ? -arg0 : arg0;
                absB = ($signed(arg1) < 0) ? -arg1 : arg1;
                res1 = 0;
                res2 = {absB, 1'b0}; // B_ext
                signA = ($signed(arg0) < 0) ? 1 : 0;
                signB = ($signed(arg1) < 0) ? 1 : 0;
                sign = signA ^ signB;
                sign_enabled = 0;
                new_cycles_cnt = 11;
                op = MULHU;

                // Setting flags
                unknown_instr = 0;
            end
            core_config_pkg::c_DIV : begin
                // Calculation
                absA = ($signed(arg0) < 0) ? -arg0 : arg0;
                absB = ($signed(arg1) < 0) ? -arg1 : arg1;
                res1 = 0;
                res2 = 0;
                signA = ($signed(arg0) < 0) ? 1 : 0;
                signB = ($signed(arg1) < 0) ? 1 : 0;
                sign = signA ^ signB;
                sign_enabled = 1;
                new_cycles_cnt = 11;
                op = DIV;

                // Setting flags
                unknown_instr = 0;
            end
            core_config_pkg::c_DIVU : begin
                // Calculation
                absA = ($signed(arg0) < 0) ? -arg0 : arg0;
                absB = ($signed(arg1) < 0) ? -arg1 : arg1;
                res1 = 0;
                res2 = 0;
                signA = ($signed(arg0) < 0) ? 1 : 0;
                signB = ($signed(arg1) < 0) ? 1 : 0;
                sign = signA ^ signB;
                sign_enabled = 0;
                new_cycles_cnt = 11;
                op = DIVU;

                // Setting flags
                unknown_instr = 0;
            end
            core_config_pkg::c_REM : begin
                // Calculation
                absA = ($signed(arg0) < 0) ? -arg0 : arg0;
                absB = ($signed(arg1) < 0) ? -arg1 : arg1;
                res1 = 0;
                res2 = 0;
                signA = ($signed(arg0) < 0) ? 1 : 0;
                signB = ($signed(arg1) < 0) ? 1 : 0;
                sign = signA ^ signB;
                sign_enabled = 1;
                new_cycles_cnt = 11;
                op = REM;

                // Setting flags
                unknown_instr = 0;
            end
            core_config_pkg::c_REMU : begin
                // Calculation
                absA = ($signed(arg0) < 0) ? -arg0 : arg0;
                absB = ($signed(arg1) < 0) ? -arg1 : arg1;
                res1 = 0;
                res2 = 0;
                signA = ($signed(arg0) < 0) ? 1 : 0;
                signB = ($signed(arg1) < 0) ? 1 : 0;
                sign = signA ^ signB;
                sign_enabled = 0;
                new_cycles_cnt = 11;
                op = REMU;

                // Setting flags
                unknown_instr = 0;
            end
            default : begin
                // Calculation
                res1 = 0;
                res2 = 0;
                absA = 0;
                absB = 0;
                signA = 0;
                signB = 0;
                sign = 0;
                sign_enabled = 0;
                new_cycles_cnt = 0;
                op = REM;

                // Setting flags
                unknown_instr = 1;
            end
        endcase
    end

    /* 
     *  Some sync logic to handle the FSM states, evolution and actions
     */
    always_ff @( posedge clk or negedge rst_n ) begin

        if (!rst_n) begin

            state           <= IDLE;
            cycles_cnt      <= 0;

            r_absA          <= 0;
            r_absB          <= 0;
            r_sign          <= 0;
            r_signA         <= 0;
            r_signB         <= 0;
            r_sign_enabled  <= 0;
            r_res1          <= 0;
            r_res2          <= 0;
            r_rd            <= 0;
            r_op            <= MUL;
            ended           <= 0;

        end
        else begin

            state           <= next_state;

            if (state == IDLE) begin

                r_absA          <= absA;
                r_absB          <= absB;
                r_sign          <= sign;
                r_signA         <= signA;
                r_signB         <= signB;
                r_sign_enabled  <= sign_enabled;
                r_res1          <= res1;
                r_res2          <= res2;
                r_rd            <= i_rd;
                r_op            <= op;
                ended           <= 0;
                cycles_cnt      <= new_cycles_cnt;

            end
            else begin

                if (state == CALC) begin

                    unique case (r_op) 

                        SLL : begin
                            r_res1 <= r_res1 << ((cycles_cnt > 8) ? 8 : cycles_cnt);
                            updated_cycle_cnt <= (cycles_cnt > 8) ? cycles_cnt - 8 : 0;
                        end
                        SRL : begin
                            r_res1 <= r_res1 >> ((cycles_cnt > 8) ? 8 : cycles_cnt);
                            updated_cycle_cnt <= (cycles_cnt > 8) ? cycles_cnt - 8 : 0;
                        end
                        SRA : begin
                            r_res1 <= $signed(r_res1) >> ((cycles_cnt > 8) ? 8 : cycles_cnt);
                            updated_cycle_cnt <= (cycles_cnt > 8) ? cycles_cnt - 8 : 0;
                        end

                        MUL, MULH, MULHSU, MULHU : begin
                            r_res1 <= r_res1 + {31'b0, (booth_partial(r_res2[3:0], r_absA) << (11-cycles_cnt))};
                            r_res2 <= r_res2 >> 8;
                            updated_cycle_cnt <= cycles_cnt - 1;
                        end

                        DIV, DIVU, REM, REMU : begin
                            q_digit <= {29'b0, str_estimate(
                                r_res1[(core_config_pkg::XLEN - 1):(core_config_pkg::XLEN - 1)-5],
                                r_absB[(core_config_pkg::XLEN - 1):(core_config_pkg::XLEN - 1)-5]
                                )
                            };
                            r_res1 <= (r_res1 << 3) - q_digit * r_absB;  // remainder update
                            r_res2 <= (r_res2 << 3) | q_digit;           // quotient
                            updated_cycle_cnt <= cycles_cnt - 1;
                        end

                    endcase

                    if (new_cycles_cnt == 0) begin

                        ended <= 1;

                    end
                    else begin

                        ended <= 0;

                    end
                end

            cycles_cnt <= updated_cycle_cnt;  

            end
        end
    end

    always_comb begin

        unique case (state)

            IDLE : begin

                if (!unknown_instr) begin

                    next_state = CALC;
                    i_error = 0;

                end
                else begin

                    next_state = IDLE;
                    i_error = 1;

                end
            end
            CALC : begin

                if (ended) begin

                    next_state = OUT;
                    i_error = 0;

                end
                else begin

                    next_state = CALC;
                    i_error = 0;

                end
            end
            OUT : begin

                if (clear) begin

                    next_state = IDLE;
                    i_error = 0;

                end 
                else begin

                    next_state = OUT;
                    i_error = 0;

                end
            end
        endcase
    end

    /*
     *  Output logic
     */
    always_comb begin

        unique case (state) 

            IDLE : begin

                valid = 0;
                busy = 0;
                req = 0;
                o_error = 0;
                o_rd = 0;
                res = 0;

            end
            CALC : begin

                valid = 0;
                busy = 1;
                req = 0;
                o_error = 0;
                o_rd = 0;
                res = 0;

            end
            OUT : begin

                valid = 1;
                busy = 0;
                req = 0;
                o_error = 0;
                o_rd = 0;
                res = 0;

                unique case (r_op) 

                    MUL : res = r_res1[(core_config_pkg::XLEN - 1) : 0];
                    MULH, MULHSU : res = (r_sign && r_sign_enabled) ? 
                        -(res1[((core_config_pkg::XLEN * 2) - 1) : (core_config_pkg::XLEN)]) : 
                        r_res1[((core_config_pkg::XLEN * 2) - 1) : (core_config_pkg::XLEN)];
                    MULHU : res = r_res1[((core_config_pkg::XLEN * 2) - 1) : (core_config_pkg::XLEN)];
                    DIV : res = (r_sign && r_sign_enabled) ? 
                        -(r_res2[(core_config_pkg::XLEN - 1) : 0]) : 
                        r_res2[(core_config_pkg::XLEN - 1) : 0];
                    DIVU : res = r_res2[(core_config_pkg::XLEN - 1) : 0];
                    REM : res = (r_sign && r_sign_enabled) ? 
                        -(r_res1[(core_config_pkg::XLEN - 1) : 0]) : 
                        r_res1[(core_config_pkg::XLEN - 1) : 0];
                    REMU : res = r_res1[(core_config_pkg::XLEN - 1) : 0];
                    SLL, SRA, SRL : res = r_res1[(core_config_pkg::XLEN - 1) : 0]; 

                endcase
            end
        endcase
    end

endmodule
