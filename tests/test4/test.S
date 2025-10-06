    .text
    .globl 	_start
    .p2align 2   # align to 4 bytes only

_start:
    # First, load some data into registers
    li      a0,     10              # Load immediate value 10 into register a0
    li      a1,     20              # Load immediate value 20 into register a1
    li      a5,     0xFFFFFFFF      # Load immediate value 0xFFFFFFFF into register a5 (-1)

    # Evaluate jumps instructions
    beq     a0,     a1,     . + 4   # Branch if a0 == a1 (should not branch)
    beq     a0,     a0,     . + 4   # Branch if a0 == a0 (should branch)
    nop
    nop
    bne     a0,     a0,     . + 4   # Branch if a0 != a0 (should not branch)
    bne     a0,     a1,     . + 4   # Branch if a0 != a1 (should branch)
    nop
    nop
    blt     a1,     a0,     . + 4   # Branch if a1 < a0 (should not branch)
    blt     a0,     a1,     . + 4   # Branch if a0 < a1 (should branch)
    nop
    nop
    bge     a0,     a1,     . + 4   # Branch if a0 >= a1 (should not branch)
    bge     a1,     a0,     . + 4   # Branch if a1 >= a0 (should branch)
    nop
    nop
    bltu    a0,     a5,     . + 4   # Branch if a0 < a5 (unsigned, should branch)
    bltu    a5,     a1,     . + 4   # Branch if a5 < a1 (unsigned, should not branch)
    nop
    nop
    bgeu    a5,     a1,     . + 4   # Branch if a5 >= a1 (unsigned, should branch)
    bgeu    a1,     a5,     . + 4   # Branch if a1 >= a5 (unsigned, should not branch)

_end:
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    # End of program - infinite loop to halt execution
    j       _end
