LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

PACKAGE records IS

    --! @brief This records group the status flags out of the ALU, feed into the controller to decide if an exception or a branch must be taken.
    TYPE alu_feedback IS RECORD
        zero : STD_LOGIC; --! ALU produced a zero output                                                      
        overflow : STD_LOGIC; --! ALU overflow (the result is then WRONG)
        beq : STD_LOGIC; --! Indicate that the BEQ condition is valid for jump
        bne : STD_LOGIC; --! Indicate that the BNE condition is valid for jump
        blt : STD_LOGIC; --! Indicate that the BLT condition is valid for jump
        bge : STD_LOGIC; --! Indicate that the BGE condition is valid for jump
        bltu : STD_LOGIC; --! Indicate that the BLTU condition is valid for jump
        bgeu : STD_LOGIC; --! Indicate that the BGEU condition is valid for jump

    END RECORD alu_feedback;
END PACKAGE records;