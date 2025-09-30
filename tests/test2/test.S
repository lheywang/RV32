    .text
    .globl 	_start
    .p2align 2   # align to 4 bytes only

_start:
    li  x1, 0                       // R1 	<- 	0
    li  x2, 1                       // R2 	<- 	1

    nop                             // Theses instructions shall be executed, but, as simple waits.
    nop
    nop
    nop
    nop

    la      x5,     _loop           // Load the address of _loop into R5
    jalr    x10,    x5,     0       // jump to _loop (via x5)

    nop                             // Theses instructions shall NEVER be executed.
    nop
    nop
    nop
    nop

_loop:
    add     x3, x1, x2              // R3 	<- 	R1 + R2
    add     x1, x2, x0              // R1 	<- 	R2
    add     x2, x3, x0              // R2 	<- 	R3
    jal     x11, _loop              // jump to _loop

__not_reached:
    // Theses instructions shall NEVER be executed, because we jumped.
    li      x20, 10                 // R20 	<- 	10
    li      x21, 10                 // R21 	<- 	10
    li      x22, 10                 // R22 	<- 	10
    li      x23, 10                 // R23 	<- 	10
    li      x24, 10                 // R24 	<- 	10

