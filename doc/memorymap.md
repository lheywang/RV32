# Memory map

## Memories

| Base address | End addres | Length | Peripheral   | Usage              | Note                  |
| ------------ | ---------- | ------ | ------------ | ------------------ | --------------------- |
| 0x10000000   | 0x00003FFF | 48K    | ROM          | Instruction memory |                       |
| 0x20000000   | 0x00001FFF | 24K    | RAM          | Dynamic memory     |                       |
| 0x80000000   | 0x8FFFFFFF | 256M   | External RAM | External memory    | Unimplemented for now |

## Peripherals

| Base address | End addres | Length | Peripheral           | Usage | Note |
| ------------ | ---------- | ------ | -------------------- | ----- | ---- |
| 0x40000000   | 0x40000FFF | 4095   | GPIO 0               | /     | /    |
| 0x40001000   | 0x40001FFF | 4095   | GPIO 2               | /     | /    |
| 0x40002000   | 0x40002FFF | 4095   | GPIO 3               | /     | /    |
| 0x40003000   | 0x40003FFF | 4095   | GPIO 4               | /     | /    |
| 0x40010000   | 0x40010FFF | 4095   | Serial 0             | /     | /    |
| 0x40011000   | 0x40011FFF | 4095   | Serial 1             | /     | /    |
| 0x40012000   | 0x40012FFF | 4095   | Serial 2             | /     | /    |
| 0x40013000   | 0x40013FFF | 4095   | Serial 3             | /     | /    |
| 0x40014000   | 0x40014FFF | 4095   | Serial 4             | /     | /    |
| 0x40015000   | 0x40015FFF | 4095   | Serial 5             | /     | /    |
| 0x40015000   | 0x40015FFF | 4095   | Serial 5             | /     | /    |
| 0x40020000   | 0x40020FFF | 4095   | Keyboard 0           | /     | /    |
| 0x40030000   | 0x40030FFF | 4095   | aRGB 0               | /     | /    |
| 0x40040000   | 0x40040FFF | 4095   | PWM 0 / Timer 0      | /     | /    |
| 0x40041000   | 0x40041FFF | 4095   | PWM 1 / Timer 1      | /     | /    |
| 0x40042000   | 0x40042FFF | 4095   | PWM 2 / Timer 2      | /     | /    |
| 0x40043000   | 0x40043FFF | 4095   | PWM 3 / Timer 3      | /     | /    |
| 0x40044000   | 0x40044FFF | 4095   | PWM 4 / TImer 4      | /     | /    |
| 0x40045000   | 0x40045FFF | 4095   | PWM 5 / Timer 5      | /     | /    |
| 0x4F000000   | 0x4F000FFF | 4095   | Interrupt controller | /     | /    |

Memory address within peripherals will be defined in the following sections.

## Peripherals registers

Each of the following peripheral are accessed as BASE_ADDRESS + Offset.
Only offset are shown in the following tables.

> **Notes** : Not all peripherals may be implemented,
> depending on the configuration selected when building.

### GPIO

| Address    | Name           | Length | Function                                                                  |
| ---------- | -------------- | ------ | ------------------------------------------------------------------------- |
| 0x00000000 | GPIO_ENABLE    | 4      | Enable or disable the peripheral. Only bit 0 is implemented.              |
| 0x00000004 | GPIO_DIRECTION | 4      | Select the direction of the pins                                          |
| 0x00000008 | GPIO_WRITE     | 4      | The value written on the GPIO ports.                                      |
| 0x0000000C | GPIO_READ      | 4      | The value read from the port                                              |
| 0x00000010 | GPIO_LEN       | 4      | The len of this GPIO port. Cannot be written, set when building the core. |
| 0x00000014 | GPIO_INT       | 4      | Enable interrupt on some pins.                                            |
| 0x00000018 | GPIO_INT_POL   | 4      | Select polarity of the edge of the interrupt on some pin                  |

> **Notes** : Some GPIO may be shorter than 32 bits, leaveing the MSB unused.

### Serial

Send and receive data using any serial protocol, which could be I2C, UART or SPI !

| Address    | Name             | Length | Function                                                                                                                      |
| ---------- | ---------------- | ------ | ----------------------------------------------------------------------------------------------------------------------------- | --- |
| 0x00000000 | SERIAL_ENABLE    | 4      | Enable or disable the peripheral. Only bit 0 is implemented.                                                                  |
| 0x00000004 | SERIAL_CONFIGURE | 4      | Contain multiple bits for the serial configuration.                                                                           |
| 0x00000008 | SERIAL_TRANSFER  | 4      | Launch the write of the TX buffer into the serial. Cleared by hardware. Writes to the TX buffer will be ignored until cleared |
| 0x0000000C | SERIAL_INTERRUPT | 4      | Configure the interrupt behavior of the peripheral                                                                            |
| 0x00000010 | SERIAL_SPEED     | 4      | Configure the speed at which the peripheral operate.                                                                          |
| 0x0000100  | SERIAL_TX_BUFFER | 64     | Peripheral TX buffer                                                                                                          |     |
| 0x0000200  | SERIAL_RX_BUFFER | 64     | Peripheral RX buffer                                                                                                          |

### Keyboard

Handle the deboucing and acquisition of up to 128 keys.

| Address    | Name              | Length | Function                                                     |
| ---------- | ----------------- | ------ | ------------------------------------------------------------ |
| 0x00000000 | KEYBOARD_ENABLE   | 4      | Enable or disable the peripheral. Only bit 0 is implemented. |
| 0x00000004 | KEYBOARD_CONFIG   | 4      | Configure basic functions of the keyboard                    |
| 0x00000008 | KEYBOARD_CLKDIV   | 4      | Configure the master clock divider for the deboucing process |
| 0x00000100 | KEYBOARD_DEBOUNCE | 1024   | Configure the debouncing behavior for each keys              |
| 0x00000200 | KEYBOARD_KEYS     | 8      | Readback of the "old" BIOS keys protocol.                    |
| 0x00000300 | KEYBOARD_NKRO     | 16     | Readback of the "new" NKRO keys protocol.                    |

### aRGB

Handle the effects computing and the data output to up to 256 leds.

| Address    | Name             | Length | Function                                                        |
| ---------- | ---------------- | ------ | --------------------------------------------------------------- |
| 0x00000000 | ARGB_ENABLE      | 4      | Enable or disable the peripheral. Only bit 0 is implemented.    |
| 0x00000004 | ARGB_CONFIG      | 4      | Basic configuration of the aRGB peripheral                      |
| 0x00000008 | ARGB_NUMLED      | 4      | Readback of the leds number (set as peripheral generics)        |
| 0x0000000C | ARGB_REFRESHRATE | 4      | Configure the clock divider used to refresh the main led matrix |
| 0x00000010 | ARGB_START       | 4      | Trigger a manual refresh of the array                           |
| 0x00000100 | ARGB_LED_DATA    | 4      | Store the data to be sent by the leds\*                         |

\* This is actually a target value, and depending on the configuration, there may be a gradient arround the targets.

### Interrupt

| Address    | Name             | Length | Function                                                     |
| ---------- | ---------------- | ------ | ------------------------------------------------------------ |
| 0x00000000 | INTERRUPT_ENABLE | 4      | Enable or disable the peripheral. Only bit 0 is implemented. |
| 0x00000004 | INTERRUPT_MASK   | 4      | Configure the enabled peripherals                            |
| 0x00000008 | INTERRUPT_STATUS | 4      | Readback of the peripherals that triggered interrupt         |
