module sound(
    input clk_sys, // 40M
    input reset,

    input paused,

    input latch_wr,
    input latch_rd,

    input [7:0] latch_din,
    output [7:0] latch_dout,
    output latch_rdy,

    // ioctl load
    input [19:0] rom_addr,
    input [7:0] rom_data,
    input rom_wr,

    input [7:0] secure_addr,
    input [7:0] secure_data,
    input secure_wr,

    output reg [15:0] sample,

    // sdr
    input clk_ram,
    output [24:0] sdr_addr,
    input [63:0] sdr_data,
    output sdr_req,
    input sdr_rdy
);


wire [15:0] sample_out, fm_sample, fm_sample_flt;

wire [11:0] fm_scale = int'(2.6 * 128);
wire [11:0] pcm_scale = int'(1.90 * 128);

always_ff @(posedge clk_sys) begin
    reg [27:0] sum;
    reg [27:0] fm;
    reg [27:0] pcm;

    fm  <= $signed(fm_sample_flt) * fm_scale;
    pcm <= $signed(sample_out)    * pcm_scale;

    sum <= fm + pcm;
    if (&sum[27:22] || &(~sum[27:22])) sample <= sum[22:7];
    else if (sum[27]) sample <= 16'h8000;
    else sample <= 16'h7fff; 
end

wire ce_28m, ce_14m, ce_7m, ce_3_5m, ce_1_7m;
jtframe_frac_cen #(6) pixel_cen
(
    .clk(clk_sys),
    .cen_in(~paused),
    .n(10'd63),
    .m(10'd88),
    .cen({ce_1_7m, ce_3_5m, ce_7m, ce_14m, ce_28m})
);

wire ram_cs, rom_cs, io_cs;
wire ym2151_cs, ga20_cs, snd_latch_cs, main_latch_cs;
wire [1:0] cpu_be;
wire [15:0] cpu_dout, cpu_din;
wire [19:0] cpu_addr;
wire [15:0] rom_dout, ram_dout;
wire cpu_rd, cpu_wr;

wire [7:0] ym2151_dout;
wire ym2151_irq_n;

wire [7:0] ga20_dout;

reg [7:0] main_latch, snd_latch;
reg main_latch_rdy, snd_latch_rdy;

assign latch_rdy = main_latch_rdy;
assign latch_dout = main_latch;

wire [15:0] cpu_word_dout = cpu_addr[0] ? { cpu_dout[7:0], 8'h00 } : cpu_dout;
wire [1:0] cpu_word_be = cpu_addr[0] ? { cpu_be[0], 1'b0 } : cpu_be;

singleport_ram #(.widthad(13), .width(8), .name("SRA0")) ram_0(
    .clock(clk_sys),
    .wren(ram_cs & cpu_wr & cpu_word_be[0]),
    .address(cpu_addr[13:1]),
    .data(cpu_word_dout[7:0]),
    .q(ram_dout[7:0])
);

singleport_ram #(.widthad(13), .width(8), .name("SRA1")) ram_1(
    .clock(clk_sys),
    .wren(ram_cs & cpu_wr & cpu_word_be[1]),
    .address(cpu_addr[13:1]),
    .data(cpu_word_dout[15:8]),
    .q(ram_dout[15:8])
);

singleport_ram #(.widthad(16), .width(8), .name("SRO0")) rom_0(
    .clock(clk_sys),
    .wren(rom_wr & ~rom_addr[0]),
    .address(rom_wr ? rom_addr[16:1] : cpu_addr[16:1]),
    .data(rom_data),
    .q(rom_dout[7:0])
);

singleport_ram #(.widthad(16), .width(8), .name("SRO1")) rom_1(
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
assign snd_latch_cs = io_cs & cpu_addr[7:0] == 8'h44;
assign main_latch_cs = io_cs & cpu_addr[7:0] == 8'h46;

assign cpu_din = rom_cs ? ( cpu_addr[0] ? { rom_dout[7:0], rom_dout[15:8] } : rom_dout ) :
            ram_cs ? ( cpu_addr[0] ? { 8'd0, ram_dout[15:8] } : ram_dout ) :
            ym2151_cs ? { 8'd0, ym2151_dout } :
            snd_latch_cs ? { 8'd0, snd_latch } :
            ga20_cs ? { 8'd0, ga20_dout } :
            16'hffff;

v35 v35(
    .clk(clk_sys),
    .ce(ce_28m),
    .ce_cycle(ce_7m),
    .reset(reset),
    
    .mem_rd(cpu_rd),
    .mem_wr(cpu_wr),
    .mem_be(cpu_be),
    .mem_addr(cpu_addr),
    .mem_dout(cpu_dout),
    .mem_din(cpu_din),

    .intp0(ym2151_irq_n),
    .intp1(~snd_latch_rdy),
    .intp2(0),

    .secure(1),
    .secure_wr(secure_wr),
    .secure_addr(secure_addr),
    .secure_data(secure_data)
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
    .xright(fm_sample),
    .xleft()
);

// fc1 = 19020hz
// fc2 = 8707hz
IIR_filter #( .use_params(1), .stereo(0), .coeff_x(0.000001054852861174913), .coeff_x0(3), .coeff_x1(3), .coeff_x2(1), .coeff_y0(-2.94554610428990093496), .coeff_y1(2.89203308225615352001), .coeff_y2(-0.94647938909674766972)) lpf_ym (
	.clk(clk_sys),
	.reset(reset),

	.ce(ce_3_5m),
	.sample_ce(ce_3_5m),

	.cx(), .cx0(), .cx1(), .cx2(), .cy0(), .cy1(), .cy2(),

	.input_l(fm_sample),
	.output_l(fm_sample_flt),

    .input_r(),
    .output_r()
);

wire [19:0] sample_addr;
wire [7:0] sample_data;
wire sample_valid;
wire sample_rd;

ga20_cache ga20_cache(
    .clk(clk_sys),
    .reset(reset),

    .rd(sample_rd),
    .addr(sample_addr),
    .valid(sample_valid),
    .dout(sample_data),

    .clk_ram(clk_ram),
    .sdr_addr(sdr_addr),
    .sdr_data(sdr_data),
    .sdr_req(sdr_req),
    .sdr_rdy(sdr_rdy)
);

ga20 ga20(
    .clk(clk_sys),
    .reset(reset),

    .ce(ce_3_5m),

    .cs(ga20_cs),
    .rd(cpu_rd),
    .wr(cpu_wr),
    .addr(cpu_addr[5:1]),
    .din(cpu_dout[7:0]),
    .dout(ga20_dout),

    .sample_rd(sample_rd),
    .sample_addr(sample_addr),
    .sample_valid(sample_valid),
    .sample_din(sample_data),

    .sample_out(sample_out)
);

always_ff @(posedge clk_sys) begin
    if (reset) begin
        main_latch_rdy <= 0;
        snd_latch_rdy <= 0;
    end else begin
        if (latch_rd) begin
            main_latch_rdy <= 0;
        end

        if (latch_wr) begin
            snd_latch <= latch_din;
            snd_latch_rdy <= 1;
        end

        if (snd_latch_cs & cpu_wr) begin
            snd_latch_rdy <= 0;
        end

        if (main_latch_cs & cpu_wr) begin
            main_latch <= cpu_dout[7:0];
            main_latch_rdy <= 1;
        end
    end
end
endmodule