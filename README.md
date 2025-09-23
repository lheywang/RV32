# RV32
My own implement of a VHDL RISC V 32b MCU. Targetted to be implemented on real target at the end. 
The core is compliant with the RV32I ISA, which is the most basic one.

The core include some peripherals (which are, for a first release targetted against a specific project, a keyboard)
- PWM output
- Keys matrix scanner / acquisition (up to 128 keys)
- aRGB generator / scanner peripheral (up to 8 rows of 16 leds)
- USB-HS through ULPI peripheral
- timers

## Requirements : 
### Synthetisation : 
This implementation is based on Altera / Intel IPs, so you need a valid installation of Quartus Lite (this is enough for a MAX10 device).
It shall be possible to port the core to any FPGA, because except PLL and memory (both RAM and ROM), it doesn't use any vendor IPs.

### Simulation : 
The simulation is based on GHDL and GTKWAVE, two open sources tools, managed by a python script ("ghdl.py"). The script is responsible
of the discovery of the VHDL source files, compilation and running. It make thinks a bit more convenient.
For any cases, and even if the tools used are open source, the design, in it's actual state require the altera_mf VHDL library, which IS NOT 
open source, so can't be bundled here.
Read the documentation on src/memory/behavioral/sim.md file to understant how to obtain theses.

Trying to compile without will end up in errors.

## File structure : 
.
├── build                                       Build folder, store temp artifacts
│   ├── \*
├── presentation                                GTKWave presentations files, usefull to store the state of any previous test bench
│   ├── \*.gtkw
├── src                                         Main sources.
│   ├── clocks                                  Main clocks. Actually an Intel FPGA IP.
│   │   └── pll
│   │       ├── \*
│   ├── core                                    RV32I core implementation. Does not include any memory nor peripherals.
│   │   ├── alu
│   │   ├── clock
│   │   ├── core_controller
│   │   ├── decoder
│   │   ├── pcounter
│   │   ├── register
│   │   ├── register_file
│   │   ├── core_tb.vhd
│   │   └── core.vhd
│   ├── memory                                  Memory section, include both ROM and RAM for the core. Not required in simulation only.
│   │   ├── behavioral                          Comportement simulation.
│   │   │   ├── altera_mf_components.vhd
│   │   │   ├── altera_mf.vhd
│   │   │   └── sim.md
│   │   ├── ram                                 RAM. Actually an Intel FPGA IP.
│   │   │   ├── \*
│   │   └── rom                                 ROM. Actually an Intel FPGA IP.
│   │       ├── \*
│   ├── packages                                Common packages.
│   │   └── common.vhd
│   ├── peripherals                             Peripherals folders. Any of them is optionnal.
│   │   ├── argb
│   │   ├── gpio
│   │   ├── keys
│   │   ├── pwm
│   │   ├── serial
│   │   ├── timer
│   │   └── ulpi
│   └── rv32.vhd
├── tests                                       Tests folders. Contain small assembly programs to test the operation principle of the core.
│   ├── test1
│   │   ├── test.md
│   │   └── test.S
│   ├── tester.py                               Tester script, charged to automatically choose and build the correct memory file.
│   ├── autotester.py                           Autotester, used memory dumps to check if design is working, or not.
│   └── tests.md
├── .gitignore
├── ghdl.py                                     Main simulation script.
├── LICENSE
└── README.md
