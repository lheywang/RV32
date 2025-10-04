#!/usr/bin/env python3
# ================================================================================
#                                   tester.py
#
#                                   l.heywang
#                                   23/09/2025
#
#       Assemble assembly files, simulate HDL core with the program
#       in memory and run the simulation.
#       Then, read back signals to ensure the correct output has been
#       computed. Used to automate tests against a define ISA.
# =================================================================================
from vcdvcd import VCDVCD

vcd = VCDVCD("build/signals.vcd")

print(vcd)

# Command : ghdl -r --workdir=build/ -Pbuild/ core_tb --vcd=build/signals.vcd --stop-time=10us --max-stack-alloc=0 --disp-time

for sig in vcd.signals:
    print("  ", sig)
