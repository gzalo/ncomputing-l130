# CPLD Flash Loader

This CPLD project enables the NComputing L130 to load the FPGA bitstream from the onboard AT45DB041B serial flash memory on power-up, eliminating the need for external JTAG programming after the initial flash programming.

## Overview

The CPLD flash loader:
- Reads the FPGA bitstream from AT45DB041B serial flash (starting at address 0)
- Configures the Cyclone EP1C6 FPGA using Passive Serial (PS) mode
- Provides visual feedback via LED:
  - Blinking: Configuration in progress
  - Solid ON: Configuration successful
  - OFF: Configuration error

## Architecture

The design consists of four main components:

1. **spi_master.vhd** - SPI master controller for communicating with the flash chip
2. **flash_reader.vhd** - High-level controller that reads data from flash using continuous read mode
3. **fpga_config.vhd** - FPGA configuration controller implementing Passive Serial protocol
4. **cpld_flash_loader.vhd** - Top-level module coordinating all components

## Pin Assignments

### FPGA Configuration Interface (Passive Serial)
- Pin 68: FPGA DATA0
- Pin 63: FPGA DCLK  
- Pin 67: FPGA nCONFIG
- Pin 16: FPGA CONF_DONE

Note: FPGA nSTATUS (pin 146) is not connected to the CPLD. The configuration sequence uses fixed timing delays instead of monitoring nSTATUS.

### Flash Memory Interface (SPI)
- Pin 23: Flash SCK (SPI Clock)
- Pin 22: Flash SI (MOSI - Master Out Slave In)
- Pin 21: Flash SO (MISO - Master In Slave Out)
- Pin 24: Flash CS# (Chip Select, active low)
- Pin 27: Flash RESET# (always high - not in reset)
- Pin 28: Flash WP# (always high - write protect disabled)

### Other
- Pin 87: 80 MHz system clock input
- Pin 1: Status LED output

## Programming the Flash

Before using this loader, the flash memory must be programmed with the FPGA bitstream. The bitstream should be stored starting at address 0x000000.

**Note:** The current design assumes the flash is pre-programmed via external means. As specified in the requirements, board programming via JTAG is not included in this version - the expectation is that the memory is already loaded with the bitstream manually.

### Methods to program the flash:

1. **External Flash Programmer**: 
   - Remove the flash chip (U5 - AT45DB041B) from the board
   - Use a dedicated SPI flash programmer
   - Write the FPGA .rbf bitstream starting at address 0x000000
   - Reinstall the flash chip on the board

2. **In-Circuit Programming with Test Points**:
   - If the board has test points for the SPI signals, use them with an external programmer
   - Ensure the CPLD is not driving the SPI bus during programming

3. **Custom CPLD Flash Programming Design**:
   - Create a temporary CPLD design that accepts data via JTAG or GPIO
   - This design would write to the flash memory
   - After programming the flash, replace with the flash_loader design
   - This approach requires additional development work

### Bitstream Preparation:

1. Generate your FPGA design using Quartus II
2. In Quartus, select Device → Device and Pin Options → Configuration
3. Choose "Passive Serial" as the configuration scheme
4. Compile the design to generate the bitstream file
5. Convert to raw binary format (.rbf) if not already done:
   - File → Convert Programming Files
   - Select "Raw Binary File (.rbf)" as output format
   - Add the .sof file as input
   - Generate the .rbf file
6. This .rbf file should be written to flash starting at address 0x000000

## Building the Project

1. Create a new Quartus II project pointing to the `cpld_flash_loader` directory
2. Use "cpld_flash_loader" as both the project name and top-level design entity
3. Add all .vhd files to the project:
   - cpld_flash_loader.vhd
   - fpga_config.vhd
   - flash_reader.vhd
   - spi_master.vhd
   - blink.vhd
4. Select device: **EPM3128ATC100-10** from the MAX3000A family
5. Set unused pins to "As input tri-stated" (Device > Device and Pin Options > Unused Pins)
6. Compile the project
7. Program the CPLD using JTAG

## Differences from cpld_passthrough

Unlike `cpld_passthrough` which allows external JTAG programming of the FPGA:
- The CPLD actively drives the configuration signals (not a simple passthrough)
- Configuration happens automatically on power-up
- No external programmer connection is needed after initial setup
- The FPGA programming header is not used
- In this mode, the FPGA only receives configuration data from the CPLD, not from external pins

### Alternative: Hybrid Mode

While this implementation focuses on automatic flash-based configuration, the system could be extended to support a hybrid mode where:
- A GPIO pin selects between flash mode and passthrough mode
- Passthrough mode would work like `cpld_passthrough` for development
- Flash mode enables standalone operation in production

This would require modifying the CPLD logic to multiplex the configuration signals based on a mode selection pin, but the current implementation keeps it simple with flash-only operation.

## Timing

- SPI clock runs at ~5 MHz (80 MHz system clock divided by 16)
- FPGA DCLK runs at ~20 MHz (80 MHz system clock divided by 4)
- Typical configuration time for EP1C6 bitstream (~140 KB): ~56ms

## Troubleshooting

**LED is OFF (solid):**
- Configuration error occurred
- Check flash contents
- Verify flash is properly connected
- Check FPGA status signals

**LED keeps blinking:**
- Configuration never completes
- Flash may not contain valid bitstream
- Flash read command may be failing

**Configuration seems to work but FPGA doesn't function:**
- Bitstream may be corrupted
- Verify correct .rbf file was written to flash
- Check that bitstream starts at address 0x000000

## Technical Notes

### AT45DB041B Flash
- 4-Mbit (512K x 8-bit) serial flash
- Supports continuous array read (command 0xE8)
- SPI Mode 0 (CPOL=0, CPHA=0)
- Maximum SPI clock: 20 MHz (we use 5 MHz for margin)
- 2048 pages of 264 bytes each (with page size selection)
- Standard 264-byte page mode used for continuous read
- Total usable capacity: ~540 KB (sufficient for EP1C6 bitstream of ~140 KB)

**Note on Page Size**: The AT45DB041B can operate in two page size modes:
- Binary page size (256 bytes): More standard but requires one-time configuration
- DataFlash page size (264 bytes): Default mode, works with continuous read command
  
The current implementation uses the default 264-byte page mode with the continuous array read command (0xE8), which works regardless of page size configuration.

### Cyclone FPGA Passive Serial Configuration
- MSB-first bit order
- DCLK frequency: up to 40 MHz (we use 20 MHz)
- Typical bitstream size: ~140 KB for EP1C6
- Requires additional clocks after CONF_DONE for initialization

## Future Enhancements

Possible improvements:
- Add support for programming flash via JTAG
- Implement fallback to JTAG mode if flash read fails
- Add CRC checking of bitstream
- Support multiple bitstream images in flash
- Add mode selection via GPIO pins

## References

- [AT45DB041B Datasheet](http://ww1.microchip.com/downloads/en/DeviceDoc/doc3443.pdf)
- [Configuring Cyclone FPGAs](https://cdrdv2-public.intel.com/655144/cyc_c51013.pdf)
- [Configuration Handbook](https://cdrdv2-public.intel.com/654348/section_3_vol_2.pdf)
