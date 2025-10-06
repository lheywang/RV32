    .text
    .globl 	_start
    .p2align 2   # align to 4 bytes only

# Note : This test require the interrupt to be triggered in the test bench.
# Without, the processor will loop indefinitely in the main loop.

_start:
    call    _enable_interrupts
    addi    t1,         zero,   0       # Clear t1 to use it in the main loop
_main_loop:
    addi    t1,         t1,     1       # Perform some work in the main loop.
    j       _main_loop                  # Infinite loop to simulate main program work

_enable_interrupts:
    li      t0,         0x8             # MIE bit in mstatus
    csrw    mstatus,    t0              # Enable global interrupts

    li      t0,         0x800           # External interrupt bit in MIE
    csrw    mie,        t0              # Enable machine external interrupts
    ret                                 # Return, alias to JALR

_trap_handler:
    addi    t0,         zero,   1       # Set t0 to 1 to indicate we entered the trap handler
_trap_loop:
    addi    t0,         t0,     1       # Increment t0 to show we are in the trap handler
    j       _trap_loop                  # Infinite loop to simulate work in the trap handler
    
