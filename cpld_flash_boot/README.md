# CPLD flash boot

This CPLD image configures the FPGA from the on-board AT45DB041B serial flash at power-up.

The FPGA is still configured in Passive Serial mode, but the external programming header is not passed through to the FPGA in this project. The CPLD is the only device connected to the flash, so it acts as the configuration controller:

1. Hold `nCONFIG` low while the FPGA finishes power-on reset.
2. Release `nCONFIG`.
3. Send an AT45DB041B continuous array read command from byte address 0.
4. Stream each byte read to the FPGA `DATA0` while clocking `SCK` and `DCLK`, reversing the bit order.
5. Stop when `CONF_DONE` rises, then send a few extra `DCLK` pulses and deselect the flash.

The flash is expected to already contain the FPGA bitstream starting at byte address 0. 

## Implementation notes

Use `cpld_flash_boot.vhd` as the Quartus top-level design. Add
`cpld_flash_boot.sdc` to the Quartus project so the clock and multicycle timing
constraints are applied.

The CPLD uses the 80 MHz board clock on pin 87 and drives the AT45DB041B with
the Continuous Array Read, High Frequency Mode command:

```text
0B 00 00 00 00 -> data...
```

The CPLD generates a global clock-enable pulse every 8 cycles of the 80 MHz
input clock. The boot sequencer only advances on that enable. Because `SCK` and
`DCLK` each spend one enable tick low and one enable tick high, the serial
clocks are 5 MHz. The CPLD keeps `nCONFIG` low and leaves the flash deselected
for about 26 ms after startup before issuing the read command. Each flash byte
is read MSB-first from `SO`, then sent to the FPGA `DATA0` LSB-first with
separate `DCLK` pulses. After `CONF_DONE` rises, the CPLD sends 64 extra `DCLK`
pulses and deselects the flash.
