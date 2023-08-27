# Ncomputing-L130
The idea of this project is to reverse engineer the Ncomputing L130 PCB (rev 1.3A), to be able to use it as a generic FPGA development board.

![Labels](docs/img/top_labels.png)

Status:
- ✅ [Reverse engineer main components and connections](pcb/)
- ✅ [Basic Blinky test for CPLD](cpld_passthrough/)
- ✅ [Using Passive Serial Configuration for loading FPGA bitstream (CPLD passes through programming signals to FPGA)](cpld_passthrough/)
- ✅ [Reverse engineer full board](pcb/)
- ✅ [Blinky in FPGA](fpga_blink/)
- ✅ [VGA output](fpga_blink/)
- ✅ [Retrocomputing using multicomp](multicomp/)
- ❌ Persist FPGA bitstream in serial flash
- ❌ Serial port 
- ❌ Sound output
- ❌ Keyboard and mouse
- ❌ SDRAM controller
- ❌ Ethernet

# Schematic, component list and PCB photos

[PDF of the Schematic](docs/img/pcb.pdf)

KiCad files can be found in the `pcb/` folder.

[Full component list here (may be missing some values, or have errors)](docs/components.csv)

[PCB Top layer](docs/img/top.jpg) / [PCB Bottom layer](docs/img/bottom.jpg)

# Block diagram

![Block diagram](docs/img/diagram.png)

# Projects 

The following folders contain `vhd` files that can be used to create a _Quartus II_ project for this board:
- cpld_passthrough: This generates a CPLD bitstream that makes it work as a passthrough so we can send the signals required for programming the FPGA.
- fpga_blink: Blinks the LEDs that are connected to the FPGA.
- fpga_vga: Generates a 640x480 VGA signal that has some characters of a 32x32 monochromatic font. Uses an internal PLL to convert the 80 MHz clock into the 25 MHz pixel clock required.
- multicomp: Details on mods to Grant Searle's guide to create a retro computer

[Getting started: guide to building the projects and programming the board](docs/getting-started.md)

# Documentation

The [docs](docs/) folder contains many documents that are useful for this project.

**When using Quartus to generate the bitstream, remember that by default non defined pins are marked as outputs and are LOW. This can cause short circuits and destroy the rest of the circuit. To avoid that, you should go to Assignments->Device->Device and Pin Options...->Unused Pins and set it to "As input tri-stated with weak pull-up". DO THIS FOR BOTH PROJECTS!**

# Thanks to
[Carlos Pantelides (cpantel)](https://github.com/cpantel/)

# Inspirations
- https://github.com/UzixLS/ncomputing-l230
