# RV32

This is a student's implementation of an RV32 core, so, please don't use them in prod :)

I've done that for the pleasure of doing it, and to learn about CPU design, so there may be some majors
flaws.

This is a small Risc V 32b core, targeted for simple MCU devices. It support the most basics extensions :

- RV32I : Base of RV32 specs, most simple operations.
- RV32_zicsr : CSR registers, used for interrupts and exception handling.

The core include some peripherals (which are, for a first release targetted against a specific project, a keyboard).
Theses peripherals could be added or removed dynamically by editing the peripheral.vhd file !

- PWM output
- Keys matrix scanner / acquisition (up to 128 keys)
- aRGB generator / scanner peripheral (up to 8 rows of 16 leds)
- USB-HS through ULPI peripheral
- timers

## Requirements :

### Synthetisation :

The core itself is based on pure VHDL, so it can be synthetized to any FPGA target. The LUT requirements is
expected to be arround 2000 LUTS (Intel FPGA MAX 10). The core does not include any memory (ROM or RAM), this is
leaved to the user to manage it.

The default configuration came with IP instantiations for RAM and ROM memories, which enable the user to swap them
to their vendors or custom implementation.
The only limitation is that both of them shall be able to perform an IO within a CPU cycle (10 ns) when the memories
are running at twice the frequency (5 ns).

### Simulation :

The simulation is based on GHDL and GTKWAVE, two open sources tools, managed by a python script ("ghdl.py"). The script
is responsible of the discovery of the VHDL source files, compilation and running. It make thinks a bit more convenient.
For any cases, and even if the tools used are open source, the design, in it's actual state require the altera_mf VHDL
library, which IS NOT open source, so can't be bundled here.
Read the documentation on src/memory/behavioral/sim.md file to understant how to obtain theses.

Trying to compile without will end up in errors.

## File structure :

.
├── build Build folder, store temp artifacts<br>
│ ├── \*<br>
├── presentation GTKWave presentations files, usefull to store the state of any previous test bench<br>
│ ├── \*.gtkw<br>
├── src Main sources.<br>
│ ├── clocks Main clocks. Actually an Intel FPGA IP.<br>
│ │ └── pll<br>
│ │ ├── \*<br>
│ ├── core RV32I core implementation. Does not include any memory nor peripherals.<br>
│ │ ├── alu<br>
│ │ ├── clock<br>
│ │ ├── core_controller<br>
│ │ ├── decoder<br>
│ │ ├── pcounter<br>
│ │ ├── endianness<br>
│ │ ├── csr<br>
│ │ ├── register_file<br>
│ │ ├── core_tb.vhd<br>
│ │ └── core.vhd<br>
│ ├── memory Memory section, include both ROM and RAM for the core. Not required in simulation only.<br>
│ │ ├── behavioral Comportement simulation.<br>
│ │ │ ├── altera_mf_components.vhd<br>
│ │ │ ├── altera_mf.vhd<br>
│ │ │ └── sim.md<br>
│ │ ├── ram RAM. Actually an Intel FPGA IP.<br>
│ │ │ ├── \*<br>
│ │ └── rom ROM. Actually an Intel FPGA IP.<br>
│ │ ├── \*<br>
│ ├── packages Common packages.<br>
│ │ └── common.vhd<br>
│ ├── peripherals Peripherals folders. Any of them is optionnal.<br>
│ │ ├── argb<br>
│ │ ├── gpio<br>
│ │ ├── keys<br>
│ │ ├── pwm<br>
│ │ ├── serial<br>
│ │ ├── timer<br>
│ │ └── ulpi<br>
│ └── rv32.vhd<br>
├── tests Tests folders. Contain small assembly programs to test the operation principle of the core.<br>
│ ├── test1<br>
│ │ ├── test.md<br>
│ │ └── test.S<br>
│ ├── tester.py Tester script, charged to automatically choose and build the correct memory file.<br>
│ ├── autotester.py Autotester, used memory dumps to check if design is working, or not.<br>
│ └── tests.md<br>
├── .gitignore<br>
├── ghdl.py Main simulation script.<br>
├── LICENSE<br>
└── README.md<br>

## Versions history

### v1 (VHDL)
A first version, wroten in VHDL is available trough a stale branch. This version, even if working was NOT complete, and
thus shall not be used as an official core.

It's major drawback was pure combinational ALU and reg to reg operations. This created extremely long paths, which cause
the frequency to reduce drastically. In the last version, it was not able to handle more than 50 MHz, where the latest version
is designed to operate at 200+ MHz !

### v2 (SystemVerilog)
To be done !
