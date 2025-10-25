# Sources

Here, in this folder you may find two major elements :

.<br>
├── bsp ------------------------- The base folder for the BSP, which define macros and drivers functions for any peripheral of the core !<br>
│ ├── include<br>
│ │ ├── core<br>
│ │ │ └── \_RV32_core.h<br>
│ │ └── peripherals<br>
│ │ ├── \_RV32_argb.h<br>
│ │ ├── \_RV32_gpio.h<br>
│ │ ├── \_RV32_keys.h<br>
│ │ ├── \_RV32_pic.h<br>
│ │ ├── \_RV32_serial.h<br>
│ │ └── \_RV32_ulpi.h<br>
│ ├── src
│ │ └── drivers<br>
│ │ ├── \_RV32_argb.c<br>
│ │ ├── \_RV32_gpio.c<br>
│ │ ├── \_RV32_keys.c<br>
│ │ ├── \_RV32_pic.c<br>
│ │ ├── \_RV32_serial.c<br>
│ │ └── \_RV32_ulpi.c<br>
│ └── RV32.h<br>
├── main ------------------------- The main folder, with a default blink led example<br>
│ ├── include<br>
│ └── src<br>
│ └── main.c<br>
└── src.md<br>
