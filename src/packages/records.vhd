library ieee;
use ieee.std_logic_1164.all;

package records is

    type alu_feedback is record
        zero :          std_logic;            -- ALU produced a zero output                                                      
        overflow :      std_logic;            -- ALU overflow
        beq :           std_logic;            -- Indicate that the BEQ  condition is valid for jump
        bne :           std_logic;            -- Indicate that the BNE  condition is valid for jump
        blt :           std_logic;            -- Indicate that the BLT  condition is valid for jump
        bge :           std_logic;            -- Indicate that the BGE  condition is valid for jump
        bltu :          std_logic;            -- Indicate that the BLTU condition is valid for jump
        bgeu :          std_logic;            -- Indicate that the BGEU condition is valid for jump

    end record alu_feedback;


end package records;