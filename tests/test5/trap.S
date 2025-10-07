    .text
    .globl 	_trap_handler
    .p2align 2                          # align to 4 bytes only
    .org 0x0000B700                     # Set origin to 0x0000B700


# Placed at address 0x0000B700 by the linker script
_trap_handler:
    addi    t0,         zero,   1       # Set t0 to 1 to indicate we entered the trap handler
_trap_loop:
    addi    t0,         t0,     1       # Increment t0 to show we are in the trap handler
    jal     ra,         _trap_loop      # Infinite loop to simulate work in the trap handler
