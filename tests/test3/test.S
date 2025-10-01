    .text
    .globl 	_start

_start:
    # Load some value in x1
    li      x1, 0xFFFFFFFF

    # --- CSRRW (atomic swap) ---
    # Write x1 into mstatus, read old mstatus into x2
    csrrw   x2, mstatus, x1

    # --- CSRRS (set bits) ---
    # Set bits from x1 into mie, save old mie into x3
    csrrs   x3, mie, x1

    # --- CSRRC (clear bits) ---
    # Clear bits from x1 in mie, save old mie into x4
    csrrc   x4, mie, x1

    # --- Immediate forms (use 5-bit immediate instead of register) ---

    # CSRRWI: Write immediate 5 into mscratch, old value -> x5
    csrrwi  x5, mscratch, 5

    # CSRRSI: Set bit 1 in mstatus, old value -> x6
    csrrsi  x6, mstatus, 1

    # CSRRCI: Clear bit 1 in mstatus, old value -> x7
    csrrci  x7, mstatus, 1

    # End loop
_infty:
    j _infty