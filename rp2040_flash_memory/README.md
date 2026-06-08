# RP2040 flash programmer

This directory contains a small MicroPython helper for programming the
AT45DB041D SPI flash used by this project.

## Why use the RP2040

Programming this flash with XGecu/TL866II was not reliable. The programmer
detects the memory incorrectly: the first manufacturer/device ID byte is read as
`0x1E` instead of `0x1F`.

Adding resistors and capacitors on the clock and SO lines did not fix the
problem reliably. The programmer also seems to have trouble selecting between
the 256-byte and 264-byte page modes, so programming may work but verifies
incorrectly.

## Programming flow

1. Install MicroPython on the RP2040 board.
2. Copy `flash.py` and the generated `.rbf` file to the RP2040 filesystem.
3. In Quartus, generate the `.rbf` file from the project output:
   `File -> Convert Programming Files`.
4. Open the MicroPython REPL and run:

```python
import flash
flash.program_file("output_file.rbf")
```

The script currently assumes 256-byte page mode (it appears to be the default
in our boards) and uses the pinout documented at the top of `flash.py`.
