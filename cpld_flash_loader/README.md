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

**Note:** The current design assumes the flash is pre-programmed via external means (e.g., using a dedicated flash programmer or a temporary CPLD design). Board programming via JTAG is not included in this version.

### Steps to program flash:
1. Generate your FPGA bitstream (.rbf file) using Quartus
2. Use an external flash programmer or create a helper CPLD design to write the bitstream to flash starting at address 0
3. Program the CPLD with this flash_loader design
4. Power cycle the board - the FPGA should now configure from flash automatically

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
