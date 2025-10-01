MEMORY
{
    ROM (rx) : ORIGIN = 0x0, LENGTH = 48K
}

SECTIONS
{
    .text : {
        *(.text*)
    } > ROM
}