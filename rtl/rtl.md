# RTL

RTL, for Register Transfer Logic is the type of logic used in advanced numeric applications.

In this folder, you'll find all of the SystemVerilog source for this Risc V processor !

There's multiple main folders, and some files

.<br>
├── clocks ------------------------- The folder for the different clocks IP's<br>
├── core --------------------------- The core folder, where all of the SystemVerilog sources are located for the core<br>
│ ├── alu -------------------------- The ALU's source folder<br>
│ │ ├── operations ----------------- Some ALU's are too complex to be implemented into a single file, so here are their submodules<br>
│ │ │ ├── booth.sv<br>
│ │ │ ├── shift.sv<br>
│ │ │ └── srt.sv<br>
│ │ ├── alu0.sv<br>
│ │ ├── alu1.sv<br>
│ │ ├── alu2.sv<br>
│ │ ├── alu4.sv<br>
│ │ └── alu5.sv<br>
│ ├── clock.sv<br>
│ ├── commiter.sv<br>
│ ├── core.sv<br>
│ ├── counter.sv<br>
│ ├── csr.sv<br>
│ ├── decoder.sv<br>
│ ├── endianess.sv<br>
│ ├── issuer.sv<br>
│ ├── occupancy.sv<br>
│ ├── pcounter.sv<br>
│ ├── prediction.sv<br>
│ └── registers.sv<br>
├── memory ------------------------- The memory IP's for the project<br>
├── packages ----------------------- The packages folder, to configure the core and some peripherals<br>
│ ├── def -------------------------- Definition files, that will be used to generated SystemVerilog Headers and C Headers. <br>
│ │ ├── commands.def<br>
│ │ ├── csr.def<br>
│ │ ├── decoders.def<br>
│ │ └── opcodes.def<br>
│ └── core_config_pkg.sv<br>
├── peripherals -------------------- The source for the different peripherals
│ ├── argb.sv<br>
│ ├── gpio.sv<br>
│ ├── interrupt.sv<br>
│ ├── keys.sv<br>
│ ├── serial.sv<br>
│ ├── timer.sv<br>
│ └── ulpi.sv<br>
├── reset.sv<br>
├── rtl.md<br>
└── rv32.sv<br>
