# CPLD flash boot

This CPLD image configures the FPGA from the on-board AT45DB041B serial flash at power-up.

The FPGA is still configured in Passive Serial mode, but the external programming header is not passed through to the FPGA in this project. The CPLD is the only device connected to the flash, so it acts as the configuration controller:

1. Hold `nCONFIG` low while the FPGA finishes power-on reset.
2. Release `nCONFIG`.
3. Send an AT45DB041B continuous array read command from byte address 0.
4. Stream each byte read to the FPGA `DATA0` while clocking `SCK` and `DCLK`, reversing the bit order.
5. Stop when `CONF_DONE` rises, then send a few extra `DCLK` pulses and deselect the flash.

The flash is expected to already contain the FPGA bitstream starting at byte address 0. 