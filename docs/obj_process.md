## Registers

### 0xf9000 OBJ Pointer

LSB byte sets the starting position of the OBJ copy pointer. The pointer is decremented each time an object is copied. Once the pointer goes below zero, no more objects will be copied. The starting value of the pointer will be `~LSB`.

The pointer is counts backwards during copies and forwards during raster. At most, 210 objects can be processed in a single line, so the maximum value for the pointer register is 0x2e.


### 0xf9002 Direct Memory access
When set to `0x0001`, reads and writes to 0xf8000-0xf8fff go directly to sprite RAM.

When set to `0x0002`, reads and writes to 0xf8000-0xf8fff go directly to color RAM.


### 0xf9004 Copy Mode
`0x0000` copy all objects except for those with their layer set to 7 (`0b111`).

`0x0001` copy all objects in layer order.

`0x0002` Split the objects up based on Y position. Objects < `0xff` (lower half of the screen) get copied to sprite RAM 0x000-0x3ff. Objects > `0xff` get copied to sprite RAM 0x400-0x7ff. Sprite RAM 0x400-0x7ff is what is rasterized.

Maybe used for split screen or something?

Can the Y position be changed?

`0x0008` copy all objects regardless of layer value

`0x0100` copy to upper 1024 colors

`0x0200` copy to VID_CTRL14 bank, obj prio

`0x0400` copy to VID_CTRL15 bank

### 0xf9008 Initiate transfer
Clears sprite RAM. Copies colors to color RAM. Performs the obj transfer. `DMA_BUSY` signal will be asserted until transfer is complete.


## Timing Notes

GA22 sends hcount signal to GA21 which is used to generate the obj ram address. It counts at 13.333Mhz, 2x the pixel clock. It increments for 848 cycles and then resets to 0. 846 is the highest value it reaches, then it is 0 for two systems. 848 @ 13.333Mhz is 63.6us, the line length. Since the maximum value (846) is midway through the 212th sprite, 211 is likely the maximum number of sprites.


X=44 is the start of the line buffer
First 8 pixels are not draw, so a sprite will no appear in the line buffer until X=48
X=467 is the last position that will draw into the line buffer

X=96 is the first visible pixel
X=415 is the last visible pixel



111088 clks per frame
2160 clks vsync
1928 clks vsync start to v_pulse
424 clks v_pulse
104 clks hblank
31,40,33 hfp, hsync, hbp
hpulse on 20th hsync clk, every 4 clocks: read from 0xf000, row scroll 1-3. the sync ends

