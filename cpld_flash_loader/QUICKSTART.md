# Quick Start Guide - CPLD Flash Loader

This guide provides step-by-step instructions to use the CPLD flash loader for automatic FPGA configuration.

## Prerequisites

- NComputing L130 board (rev 1.3A)
- Altera USB Blaster JTAG programmer
- Quartus II 13.0sp1 or compatible version
- Pre-programmed AT45DB041B flash with FPGA bitstream

## Step 1: Build the CPLD Project

1. Open Quartus II
2. Create a new project:
   - **Project name**: cpld_flash_loader
   - **Working directory**: Point to the `cpld_flash_loader` folder
   - **Top-level entity**: cpld_flash_loader

3. Add all VHDL files to the project:
   - cpld_flash_loader.vhd (top-level)
   - fpga_config.vhd
   - flash_reader.vhd
   - spi_master.vhd
   - blink.vhd

4. Configure the device:
   - **Device**: EPM3128ATC100-10
   - **Family**: MAX3000A

5. Set unused pins:
   - Go to: Assignments → Device → Device and Pin Options → Unused Pins
   - Select: "As input tri-stated"
   - Click OK

6. Compile the project:
   - Processing → Start Compilation
   - Wait for completion (should take ~30 seconds)

## Step 2: Verify Pin Assignments

Open the Pin Planner (Assignments → Pin Planner) and verify:

| Signal       | Pin | Description              |
|--------------|-----|--------------------------|
| clk_i        | 87  | 80 MHz system clock      |
| led_o        | 1   | Status LED               |
| fpga_data0   | 68  | FPGA configuration data  |
| fpga_dclk    | 63  | FPGA configuration clock |
| fpga_nconfig | 67  | FPGA nCONFIG             |
| fpga_conf_done | 16 | FPGA CONF_DONE          |
| flash_sck    | 23  | Flash SPI clock          |
| flash_si     | 22  | Flash SPI MOSI           |
| flash_so     | 21  | Flash SPI MISO           |
| flash_cs_n   | 24  | Flash chip select        |
| flash_reset_n | 27 | Flash reset              |
| flash_wp_n   | 28  | Flash write protect      |

These should be set automatically via the `chip_pin` attributes in the VHDL code.

## Step 3: Program the CPLD

1. Connect the USB Blaster to the CPLD JTAG header (right connector)
   - Observe pin 1 marking (red stripe on cable)
   - Power on the board

2. Open the Programmer:
   - Tools → Programmer
   - Click "Hardware Setup"
   - Select "USB-Blaster"
   - Click "Close"

3. Add the programming file:
   - Click "Add File"
   - Navigate to `output_files/cpld_flash_loader.pof`
   - Select and open

4. Program the device:
   - Check "Program/Configure"
   - Click "Start"
   - Wait for "100% (Successful)" message

## Step 4: Verify Operation

After programming the CPLD, power cycle the board:

### LED Behavior

- **Blinking (~1 Hz)**: Configuration in progress - this is normal
- **Solid ON**: Configuration successful - FPGA is running
- **OFF**: Configuration error - check flash contents and connections

### Expected Timeline

1. Power on → LED starts blinking (CPLD initializing)
2. After ~50-100ms → Configuration complete
3. LED goes solid ON → FPGA is now running the bitstream from flash

## Troubleshooting

### LED stays OFF
- **Problem**: Configuration error
- **Solutions**:
  - Verify flash chip is properly programmed
  - Check flash connections (especially CS, SCK, MOSI, MISO)
  - Verify FPGA configuration pins are not damaged
  - Check power supplies (3.3V, 1.5V)

### LED keeps blinking continuously
- **Problem**: Configuration never completes
- **Solutions**:
  - Flash may be empty or corrupted
  - Bitstream in flash may be invalid
  - Verify flash programming starting at address 0x000000
  - Check that .rbf file (not .sof) was used

### FPGA doesn't function after configuration
- **Problem**: Configuration succeeded but FPGA design doesn't work
- **Solutions**:
  - This is not a flash loader issue
  - Debug your FPGA design separately
  - Verify the .rbf file works when programmed via JTAG first
  - Check that FPGA pin assignments match your design

### How to go back to JTAG programming
- Simply program the CPLD with `cpld_passthrough` design
- This allows external JTAG programming of the FPGA again
- No hardware changes needed

## Next Steps

Once the flash loader is working:

1. **Test different FPGA designs**: 
   - Program different bitstreams to flash
   - Each power cycle will load the new design

2. **Optimize timing**:
   - Current SPI clock: 5 MHz (conservative)
   - Can increase to 10-20 MHz if needed

3. **Add features**:
   - Multi-image support (store multiple bitstreams)
   - Boot image selection via GPIO
   - Watchdog timer for failed configurations
   - Fallback to secondary image

## Important Notes

- **Flash programming**: Must be done externally (remove chip or use programmer)
- **No JTAG passthrough**: This design doesn't support JTAG programming of FPGA
- **Bitstream format**: Must be .rbf (raw binary), not .sof
- **Bitstream size**: EP1C6 bitstream is ~140 KB, well within flash capacity
- **Configuration time**: ~50-100ms depending on bitstream size

## Support

For issues or questions:
- Check the main [README.md](README.md) for detailed technical information
- Review FPGA and flash datasheets in the `docs/` folder
- See existing examples: `cpld_passthrough`, `fpga_blink`, `fpga_vga`

## Summary

The CPLD flash loader enables standalone operation of the L130 board:
- No programmer needed after initial setup
- FPGA configures automatically on power-up
- Configuration time: ~50-100ms
- Visual feedback via LED
- Easy to switch back to development mode with `cpld_passthrough`

This makes the board suitable for embedded applications, demonstrations, and production use cases where JTAG programming is not practical.
