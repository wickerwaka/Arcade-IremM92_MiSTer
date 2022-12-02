## IC1
M51953A, Reset controller. Holds /RESET (pin 5) signal low for a short time after power up

## IC2
74LS175, Quad flip-flop. Coin counter output. Maybe memcard and rumble? Unknown how it is connected to the CPU.

## IC3
72LS244, Octal Buffer. Test, start, dma busy. Lower Byte

## IC4
72LS244, Octal Buffer. 1P, maybe. Lower Byte

## IC5
72LS244, Octal Buffer. 2P, maybe. Upper Byte

## IC6
72LS244, Octal Buffer. CN4 (4P). Upper Byte

## IC7
72LS244, Octal Buffer. SW2. Upper Byte

## IC8
72F86, Quad XOR. Unknown purpose

## IC9
74ALS273N, Octal flip-flip. Latches RGB value from palette data in IC15. Connected directly to IC15 data lines. CLK/CLR source unknown. Pin 155 on IC63, B2 on CN2.

## IC10
74ALS273N, Octal flip-flip. Latches RGB value from palette data in IC16. Connected directly to IC16 data lines. CLK/CLR source unknown. Pin 155 on IC63, B2 on CN2.

## IC11
PAL16L8. Generates the select signals for the shared ram multiplexers (IC17, 18, etc). Inputs are from the three custom ICs and the videocontrol register. 

## IC12
72LS244, Octal Buffer. CN5 (3P). Lower Byte

## IC13
72LS244, Octal Buffer. SW1. Lower Byte

## IC15 & IC16 "Palette RAM"
MB81C78A, 8k x 8bit SRAM. Two 8K RAMs that are used to store the active color palettes. The ICs 17, 18, 19, 25, 26, 27, 28 multiplex the address lines, which are selected by IC11.

IC63 and the B Board address this RAM in order to latch color output values to the output flipflops (IC9 & IC10). The CPU and IC42 have read and write access to this RAM, but in general use the CPU does not access it and IC42 only writes to it during its DMA transfer.

The output enable and chip select signals are always asserted. 

## IC17, IC18, IC19, IC25, IC26, IC27, IC28
74LS153, multiplexers. Multiplexes shared ram address lines and write enable.

| Channel | Source |
|---|---|
| 0 | CPU |
| 1 | IC42 |
| 2 | IC63 |
| 3 | B Board |

All ICs follow the same pattern with the exception of IC17. IC17 uses video control values for some address signals. Only signals from IC42 are used directly. VID_CTRL8 and 9 appear to control the color bank switching, but this differs from MAME which has it as VID_CTRL0 and 1. Are the bytes flipped? This implies that the sprite data is also bank switched, but is the sprite DMA aware of that?

## IC46
74LS138, 3-8 decoder. Selects 244 buffers based on IO port address. Address lines A1-A3 are hooked up to ABC inputs. Not sure how enables are hooked up.

## IC55
72LS244, Octal Buffer. SW3. Upper Byte
