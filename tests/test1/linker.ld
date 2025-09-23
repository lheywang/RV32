MEMORY
{
    ROM (rx) : ORIGIN = 0x0, LENGTH = 0x4000
}

SECTIONS
{
    .text : {
        *(.text*)
    } > ROM
}