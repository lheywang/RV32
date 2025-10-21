# Testbenchs

All of the different modules are compiled using Verilator, and can be tested with some testbenchs (C++).

This folder group them all, in it's subfolders

.<br>
├── include ------------------------ The include folder, which contain utility headers<br>
│ ├── colors.h<br>
│ └── utils.h<br>
├── src ---------------------------- The source folder<br>
│ ├── core ------------------------- The tests for the RISC-V core<br>
│ │ ├── alu<br>
│ │ │ ├── modules<br>
│ │ │ │ ├── tb_booth.cpp<br>
│ │ │ │ ├── tb_shift.cpp<br>
│ │ │ │ └── tb_srt.cpp<br>
│ │ │ ├── tb_alu0.cpp<br>
│ │ │ ├── tb_alu1.cpp<br>
│ │ │ ├── tb_alu2.cpp<br>
│ │ │ ├── tb_alu4.cpp<br>
│ │ │ └── tb_alu5.cpp<br>
│ │ ├── tb_clock.cpp<br>
│ │ ├── tb_counter.cpp<br>
│ │ ├── tb_csr.cpp<br>
│ │ ├── tb_decoder.cpp<br>
│ │ ├── tb_endianess.cpp<br>
│ │ ├── tb_occupancy.cpp<br>
│ │ ├── tb_pcounter.cpp<br>
│ │ └── tb_registers.cpp<br>
│ ├── peripherals ------------------ The tests for the peripherals<br>
│ │ ├── tb_argb.cpp<br>
│ │ ├── tb_gpio.cpp<br>
│ │ ├── tb_keys.cpp<br>
│ │ ├── tb_serial.cpp<br>
│ │ ├── tb_timer.cpp<br>
│ │ └── tb_ulpi.cpp<br>
│ ├── utils ------------------------ The source for the utilities<br>
│ │ └── utils.cpp<br>
│ └── tb_reset.cpp<br>
└── testbenchs.md<br>
