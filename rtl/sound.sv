module sound(
    input clk_sys, // 40M
    input reset,

    // ioctl load
    input [19:0] rom_addr,
    input [7:0] rom_data,
    input rom_wr,

    output [15:0] sample
);

// TODO
// Sample ROM
// Sound RAM
// YM2151
// GA20
// Sample Filters
// Output Filters
// V35
// Latches
// Sound ROM -- Done
// Clock dividers - Done

wire ce_28m, ce_14m, ce_7m, ce_3_5m, ce_1_7m;
jtframe_frac_cen #(6) pixel_cen
(
    .clk(clk_sys),
    .n(10'd63),
    .m(10'd88),
    .cen({ce_1_7m, ce_3_5m, ce_7m, ce_14m, ce_28m})
);

wire ram_cs, rom_cs, io_cs;
wire ym2151_cs, ga21_cs, latch1_cs, latch2_cs;
wire [1:0] cpu_be;
wire [15:0] cpu_dout, cpu_din;
wire [19:0] cpu_addr;
wire [15:0] rom_dout, ram_dout;
wire cpu_rd, cpu_wr;

wire [7:0] ym2151_dout;
wire ym2151_irq_n;

singleport_ram #(.widthad(13), .width(8)) ram_0(
    .clock(clk_sys),
    .wren(ram_cs & cpu_wr & cpu_be[0]),
    .address(cpu_addr[13:1]),
    .data(cpu_dout[7:0]),
    .q(ram_dout[7:0])
);

singleport_ram #(.widthad(13), .width(8)) ram_1(
    .clock(clk_sys),
    .wren(ram_cs & cpu_wr & cpu_be[1]),
    .address(cpu_addr[13:1]),
    .data(cpu_dout[15:8]),
    .q(ram_dout[15:8])
);

singleport_ram #(.widthad(16), .width(8)) rom_0(
    .clock(clk_sys),
    .wren(rom_wr & ~rom_addr[0]),
    .address(rom_wr ? rom_addr[16:1] : cpu_addr[16:1]),
    .data(rom_data),
    .q(rom_dout[7:0])
);

singleport_ram #(.widthad(16), .width(8)) rom_1(
    .clock(clk_sys),
    .wren(rom_wr & rom_addr[0]),
    .address(rom_wr ? rom_addr[16:1] : cpu_addr[16:1]),
    .data(rom_data),
    .q(rom_dout[15:8])
);

assign ram_cs = cpu_addr[19:12] >= 8'ha0 && cpu_addr[19:12] < 8'ha4;
assign io_cs = cpu_addr[19:12] == 8'ha8;
assign rom_cs = ~ram_cs & ~io_cs;

assign ga20_cs   = io_cs & cpu_addr[7:6] == 2'b00; // 0xa8000 - 0xa803f
assign ym2151_cs = io_cs & cpu_addr[7:2] == 6'b010000; // 0xa8040 - 0xa8043
assign latch1_cs = io_cs & cpu_addr[7:0] == 8'h44;
assign latch2_cs = io_cs & cpu_addr[7:0] == 8'h46;

assign cpu_din = rom_cs ? rom_dout :
            ram_cs ? ( cpu_addr[0] ? { ram_dout[15:8], ram_dout[15:8] } : ram_dout ) :
            ym2151_cs ? { ym2151_dout, ym2151_dout } :
            16'hffff;




v35 v35(
    .clk(clk_sys),
    .ce(ce_28m),
    .reset(reset),
    
    .mem_rd(cpu_rd),
    .mem_wr(cpu_wr),
    .mem_be(cpu_be),
    .mem_addr(cpu_addr),
    .mem_dout(cpu_dout),
    .mem_din(cpu_din)
);


jt51 ym2151(
    .rst(reset),
    .clk(clk_sys),
    .cen(ce_3_5m),
    .cen_p1(ce_1_7m),
    .cs_n(~ym2151_cs),
    .wr_n(~cpu_wr),
    .a0(cpu_addr[1]),
    .din(cpu_dout[7:0]),
    .dout(ym2151_dout),
    .irq_n(ym2151_irq_n),
    .xleft(sample),
    .xright()
);

endmodule