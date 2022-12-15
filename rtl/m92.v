//============================================================================
//  Irem M92 for MiSTer FPGA - Main module
//
//  Copyright (C) 2022 Martin Donlon
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

import m92_pkg::*;

module m92 (
    input CLK_32M,
    input CLK_96M,

    input reset_n,
    output reg ce_pix,

    input board_cfg_t board_cfg,
    
    input z80_reset_n,

    output [7:0] R,
    output [7:0] G,
    output [7:0] B,

    output HSync,
    output VSync,
    output HBlank,
    output VBlank,

    output [15:0] AUDIO_L,
    output [15:0] AUDIO_R,

    input [1:0] coin,
    input [1:0] start_buttons,
    input [3:0] p1_joystick,
    input [3:0] p2_joystick,
    input [3:0] p1_buttons,
    input [3:0] p2_buttons,
    input service_button,
    input [15:0] dip_sw,

    input pause_rq,

    output [24:0] sdr_sprite_addr,
    input [63:0] sdr_sprite_dout,
    output sdr_sprite_req,
    input sdr_sprite_rdy,

    output [24:0] sdr_bg_addr,
    input [31:0] sdr_bg_dout,
    output sdr_bg_req,
    input sdr_bg_rdy,

    output [24:0] sdr_cpu_addr,
    input [15:0] sdr_cpu_dout,
    output [15:0] sdr_cpu_din,
    output sdr_cpu_req,
    input sdr_cpu_rdy,
    output [1:0] sdr_cpu_wr_sel,

    input clk_bram,
    input bram_wr,
    input [7:0] bram_data,
    input [19:0] bram_addr,
    input [4:0] bram_cs,

    input [2:0] en_layers,
    input en_sprites,
    input en_audio_filters,

    input sprite_freeze,

    input video_60hz,
    input video_57hz,
    input video_50hz
);

// Divide 32Mhz clock by 4 for pixel clock
reg paused = 0;
reg [8:0] paused_v;
reg [9:0] paused_h;

always @(posedge CLK_32M) begin
    if (pause_rq & ~paused) begin
        if (~cpu_mem_read & ~cpu_mem_write & ~mem_rq_active) begin
            paused <= 1;
            paused_v <= V;
            paused_h <= H;
        end
    end else if (~pause_rq & paused) begin
        paused <= ~(V == paused_v && H == paused_h);
    end
end

reg [1:0] ce_counter_cpu, ce_counter_mcu;
reg ce_cpu, ce_4x_cpu, ce_mcu;

always @(posedge CLK_32M) begin
    if (!reset_n) begin
        ce_cpu <= 0;
        ce_4x_cpu <= 0;
        ce_counter_cpu <= 0;
        ce_counter_mcu <= 0;
    end else begin
        ce_cpu <= 0;
        ce_4x_cpu <= 0;
        ce_mcu <= 0;

        if (~paused) begin
            if (~(ram_rom_memrq & (cpu_mem_read | cpu_mem_write)) & ~mem_rq_active) begin // stall main cpu while fetching from sdram
                ce_counter_cpu <= ce_counter_cpu + 2'd1;
                ce_4x_cpu <= 1;
                ce_cpu <= &ce_counter_cpu;
            end
            ce_counter_mcu <= ce_counter_mcu + 2'd1;
            ce_mcu <= &ce_counter_mcu;
        end
    end
end

wire ce_pix_half;
jtframe_frac_cen #(2) pixel_cen
(
    .clk(CLK_32M),
    .n(video_57hz ? 10'd115 : video_60hz ? 10'd207 : 10'd1),
    .m(video_57hz ? 10'd444 : video_60hz ? 10'd760 : 10'd4),
    .cen({ce_pix_half, ce_pix})
);

wire clock = CLK_32M;

/* Global signals from schematics */
wire IOWR = cpu_io_write; // IO Write
wire IORD = cpu_io_read; // IO Read
wire MWR = cpu_mem_write; // Mem Write
wire MRD = cpu_mem_read; // Mem Read

wire TNSL;

wire [15:0] cpu_mem_out;
wire [19:0] cpu_mem_addr;
wire [1:0] cpu_mem_sel;

// v30 bus read/write signals are only asserted for a single clock cycle, so latch them for an additional one
reg cpu_mem_read_lat, cpu_mem_write_lat;
wire cpu_mem_read_w, cpu_mem_write_w;
wire cpu_mem_read = cpu_mem_read_w | cpu_mem_read_lat;
wire cpu_mem_write = cpu_mem_write_w | cpu_mem_write_lat;

wire cpu_io_read, cpu_io_write;
wire [7:0] cpu_io_in;
wire [7:0] cpu_io_out;
wire [7:0] cpu_io_addr;

wire [15:0] cpu_mem_in;


wire [15:0] cpu_word_out = cpu_mem_addr[0] ? { cpu_mem_out[7:0], 8'h00 } : cpu_mem_out;
wire [19:0] cpu_word_addr = { cpu_mem_addr[19:1], 1'b0 };
wire [1:0] cpu_word_byte_sel = cpu_mem_addr[0] ? { cpu_mem_sel[0], 1'b0 } : cpu_mem_sel;
reg [15:0] cpu_ram_rom_data;
wire [24:0] cpu_region_addr;
wire cpu_region_writable;

wire ram_rom_memrq;
wire sprite_memrq;
wire palette_memrq;
wire sprite_control_memrq;
wire video_control_memrq;
wire pf_vram_memrq;

function [15:0] word_shuffle(input [19:0] addr, input [15:0] data);
    begin
        word_shuffle = addr[0] ? { 8'h00, data[15:8] } : data;
    end
endfunction

reg mem_rq_active = 0;
reg pal_;

always @(posedge CLK_32M or negedge reset_n)
begin
    if (!reset_n) begin
    end else begin
        cpu_mem_read_lat <= cpu_mem_read_w;
        cpu_mem_write_lat <= cpu_mem_write_w;
    end
end

reg sdr_cpu_rq, sdr_cpu_ack, sdr_cpu_rq2;

always_ff @(posedge CLK_96M) begin
    sdr_cpu_req <= 0;
    if (sdr_cpu_rdy) sdr_cpu_ack <= sdr_cpu_rq;
    if (sdr_cpu_rq != sdr_cpu_rq2) begin
        sdr_cpu_req <= 1;
        sdr_cpu_rq2 <= sdr_cpu_rq;
    end
end


always_ff @(posedge CLK_32M or negedge reset_n) begin
    if (!reset_n) begin
        mem_rq_active <= 0;
    end else begin
        if (!mem_rq_active) begin
            if (ram_rom_memrq & ((cpu_mem_read_w & ~cpu_mem_read_lat) | (cpu_mem_write_w & ~cpu_mem_write_lat))) begin // sdram request
                sdr_cpu_wr_sel <= 2'b00;
                sdr_cpu_addr <= cpu_region_addr;
                if (cpu_mem_write & cpu_region_writable ) begin
                    sdr_cpu_wr_sel <= cpu_word_byte_sel;
                    sdr_cpu_din <= cpu_word_out;
                end
                sdr_cpu_rq <= ~sdr_cpu_rq;
                mem_rq_active <= 1;
            end
        end else if (sdr_cpu_rq == sdr_cpu_ack) begin
            cpu_ram_rom_data <= sdr_cpu_dout;
            mem_rq_active <= 0;
        end
    end
end

wire rom0_ce, rom1_ce, ram_cs2;


wire [15:0] switches_p1_p2 = { p2_buttons, p2_joystick, p1_buttons, p1_joystick };
wire [15:0] switches_p3_p4 = 16'hffff;
wire [15:0] flags = { 8'hff, TNSL, 1'b1, 1'b1 /*TEST*/, 1'b1 /*R*/, coin, start_buttons };

reg [7:0] sys_flags = 0;
wire COIN0 = sys_flags[0];
wire COIN1 = sys_flags[1];
wire SOFT_NL = ~sys_flags[2];
wire CBLK = sys_flags[3];
wire BRQ = ~sys_flags[4];
wire BANK = sys_flags[5];
wire NL = SOFT_NL ^ dip_sw[8];

reg [1:0] iset;
reg [15:0] iset_data;

// TODO BANK, CBLK, NL
always @(posedge CLK_32M) begin
    iset <= 2'b00;
    if (IOWR && cpu_io_addr == 8'h02) sys_flags <= cpu_io_out[7:0];
    if (IOWR && cpu_io_addr == 8'h9e) begin
        iset <= 2'b01;
        iset_data <= { 8'h00, cpu_io_out };
    end
    if (IOWR && cpu_io_addr == 8'h9f) begin
        iset <= 2'b10;
        iset_data <= { cpu_io_out, 8'h00 };
    end

end

// mux io and memory reads
always_comb begin
    bit [15:0] d16;
    bit [15:0] io16;

    if (palette_memrq) d16 = palette_dout;
    else if (sprite_memrq) d16 = sprite_dout;
    else if(pf_vram_memrq) d16 = pf_vram_dout;
    else d16 = cpu_ram_rom_data;
    cpu_mem_in = word_shuffle(cpu_mem_addr, d16);

    case ({cpu_io_addr[7:1], 1'b0})
    8'h00: io16 = switches_p1_p2;
    8'h02: io16 = flags;
    8'h04: io16 = dip_sw;
    8'h06: io16 = switches_p3_p4;
    8'h08: io16 = 16'hffff; // soundlatch2 TODO
    default: io16 = 16'hffff;
    endcase

    cpu_io_in = cpu_io_addr[0] ? io16[15:8] : io16[7:0];
end

cpu v30(
    .clk(CLK_32M),
    .ce(ce_cpu), // TODO
    .ce_4x(ce_4x_cpu), // TODO
    .reset(~reset_n),
    .turbo(0),
    .SLOWTIMING(0),

    .cpu_idle(),
    .cpu_halt(),
    .cpu_irqrequest(),
    .cpu_prefix(),

    .dma_active(0),
    .sdma_request(0),
    .canSpeedup(),

    .bus_read(cpu_mem_read_w),
    .bus_write(cpu_mem_write_w),
    .bus_be(cpu_mem_sel),
    .bus_addr(cpu_mem_addr),
    .bus_datawrite(cpu_mem_out),
    .bus_dataread(cpu_mem_in),

    .irqrequest_in(int_req),
    .irqvector_in(int_vector),
    .irqrequest_ack(int_ack),

    .load_savestate(0),

    // TODO
    .cpu_done(),

    .RegBus_Din(cpu_io_out),
    .RegBus_Adr(cpu_io_addr),
    .RegBus_wren(cpu_io_write),
    .RegBus_rden(cpu_io_read),
    .RegBus_Dout(cpu_io_in),

    .sleep_savestate(paused)
);

address_translator address_translator(
    .A(cpu_mem_addr),
    .board_cfg(board_cfg),
    .ram_rom_memrq(ram_rom_memrq),
    .sdr_addr(cpu_region_addr),
    .writable(cpu_region_writable),

    .sprite_memrq(sprite_memrq),
    .palette_memrq(palette_memrq),
    .sprite_control_memrq(sprite_control_memrq),
    .video_control_memrq(video_control_memrq),
    .pf_vram_memrq(pf_vram_memrq)
);

wire int_req, int_ack;
wire [8:0] int_vector;

m92_pic m92_pic(
    .clk(CLK_32M),
    .ce(ce_cpu),
    .reset(~reset_n),

    .cs((IORD | IOWR) & ~cpu_io_addr[7] & cpu_io_addr[6]), // 0x40-0x43
    .wr(IOWR),
    .rd(0),
    .a0(cpu_io_addr[1]),
    
    .din(cpu_io_out),

    .int_req(int_req),
    .int_vector(int_vector),
    .int_ack(int_ack),

    .intp({5'd0, HINT, TNSL, VBLK})
);

wire [8:0] VE, V;
wire [9:0] HE, H;
wire HBLK, VBLK, HS, VS;
wire HINT, CLD;

assign HSync = HS;
assign HBlank = HBLK;
assign VSync = VS;
assign VBlank = VBLK;

kna70h015 kna70h015(
    .CLK_32M(CLK_32M),

    .CE_PIX(ce_pix),
    .iset(iset),
    .iset_data(iset_data),
    .NL(NL),
    .S24H(0),

    .CLD(CLD),
    .CPBLK(),

    .VE(VE),
    .V(V),
    .HE(HE),
    .H(H),

    .HBLK(HBLK),
    .VBLK(VBLK),
    .HINT(HINT),

    .HS(HS),
    .VS(VS),

    .video_50hz(video_50hz)
);

wire [15:0] pf_vram_dout;
wire [10:0] pf_color_index;
wire pf_priority;

wire P1L;

board_b_d board_b_d(
    .CLK_32M(CLK_32M),
    .CLK_96M(CLK_96M),

    .CE_PIX(ce_pix),

    .DOUT(pf_vram_dout),

    .DIN(cpu_word_out),
    .A(cpu_word_addr),
    .BYTE_SEL(cpu_word_byte_sel),

    .IO_DIN(cpu_io_out),
    .IO_A(cpu_io_addr),

    .MRD(MRD),
    .MWR(MWR),
    .IORD(IORD),
    .IOWR(IOWR),
    .CLD(CLD),

    .vram_memrq(pf_vram_memrq),
    
    .NL(NL),

    .VE(VE),
    .HE({HE[9], HE[7:0]}),
    .H({H[9], H[7:0]}),

    .color_index(pf_color_index),
    .prio(pf_priority),

    .sdr_data(sdr_bg_dout),
    .sdr_addr(sdr_bg_addr),
    .sdr_req(sdr_bg_req),
    .sdr_rdy(sdr_bg_rdy),

    .paused(paused),

    .en_layers(en_layers)
);

wire [10:0] final_color_index = (|sprite_color_index[3:0] & (sprite_priority | ~pf_priority) & en_sprites) ? sprite_color_index : pf_color_index;

wire [15:0] palette_dout;
wire [4:0] pal_r, pal_g, pal_b;
palette palette(
    .clk(CLK_32M),
    .bank(0), // TODO
    .cpu_we(palette_memrq & MWR ? cpu_word_byte_sel : 2'b00),
    .cpu_word_addr(cpu_word_addr),
    .word_in(cpu_word_out),
    .word_out(palette_dout),

    .color_index(final_color_index),
    .red(pal_r),
    .green(pal_g),
    .blue(pal_b)
);

assign R = ~CBLK ? { pal_r, pal_r[4:2] } : 8'h00;
assign G = ~CBLK ? { pal_g, pal_g[4:2] } : 8'h00;
assign B = ~CBLK ? { pal_b, pal_b[4:2] } : 8'h00;

wire [15:0] sprite_dout;
wire [11:0] sprite_color_index;
wire sprite_priority;

wire sprite_dma = MWR && cpu_word_byte_sel[0] && cpu_word_addr == 20'hf9008;

sprite sprite(
    .CLK_32M(CLK_32M),
    .CLK_96M(CLK_96M),
    .CE_PIX(ce_pix),

    .DIN(cpu_word_out),
    .DOUT(sprite_dout),
    
    .A(cpu_word_addr),
    .BYTE_SEL(cpu_word_byte_sel),

    .BUFDBEN(sprite_memrq),
    .MRD(MRD),
    .MWR(MWR),

    .VE(VE),
    .NL(NL),
    .HBLK(HBLK),
    .pixel_out(sprite_color_index),
    .prio_out(sprite_priority),

    .TNSL(TNSL),
    .DMA_ON(sprite_dma),

    .sdr_data(sdr_sprite_dout),
    .sdr_addr(sdr_sprite_addr),
    .sdr_req(sdr_sprite_req),
    .sdr_rdy(sdr_sprite_rdy)
);

/*
wire [4:0] obj_r = en_sprite_palette ? obj_pal_r : { obj_pix[3:0], 1'b0 };
wire [4:0] obj_g = en_sprite_palette ? obj_pal_g : { obj_pix[3:0], 1'b0 };
wire [4:0] obj_b = en_sprite_palette ? obj_pal_b : { obj_pix[3:0], 1'b0 };

wire P0L = (|obj_pix[3:0]) && en_sprites;

assign R = ~CBLK ? ( (P0L & P1L) ? {obj_r[4:0], obj_r[4:2]} : {char_r[4:0], char_r[4:2]} ) : 8'h00;
assign G = ~CBLK ? ( (P0L & P1L) ? {obj_g[4:0], obj_g[4:2]} : {char_g[4:0], char_g[4:2]} ) : 8'h00;
assign B = ~CBLK ? ( (P0L & P1L) ? {obj_b[4:0], obj_b[4:2]} : {char_b[4:0], char_b[4:2]} ) : 8'h00;

wire sprite_dout_valid;

wire [7:0] obj_pix;

*/

/*
// 3.5Khz 2nd order low pass filter with additional 10dB attenuation
IIR_filter #( .use_params(1), .stereo(0), .coeff_x(0.00004185087102461337 * 0.31622776601), .coeff_x0(2), .coeff_x1(1), .coeff_x2(0), .coeff_y0(-1.99222499379830120247), .coeff_y1(0.99225510233860669818), .coeff_y2(0)) samples_lpf (
	.clk(CLK_32M),
	.reset(~reset_n),

	.ce(ce_filter),
	.sample_ce(1),

	.cx(),
	.cx0(),
	.cx1(),
	.cx2(),
	.cy0(),
	.cy1(),
	.cy2(),

	.input_l({signed_mcu_sample[7:0], 8'd0}),
    .input_r(),
	.output_l(filtered_mcu_sample),
    .output_r()
);


// 9khz 1st order, 10khz 2nd order
IIR_filter #( .use_params(1), .stereo(0), .coeff_x(0.00000476166826258131), .coeff_x0(3), .coeff_x1(3), .coeff_x2(1), .coeff_y0(-2.96374831301152275032), .coeff_y1(2.92805248787211569450), .coeff_y2(-0.96430074919997255112)) music_lpf (
	.clk(CLK_32M),
	.reset(~reset_n),

	.ce(ce_filter),
	.sample_ce(1),

	.cx(),
	.cx0(),
	.cx1(),
	.cx2(),
	.cy0(),
	.cy1(),
	.cy2(),

	.input_l(ym_audio),
    .input_r(),
	.output_l(filtered_ym_audio),
    .output_r()
);

reg [16:0] audio_out;

assign AUDIO_L = audio_out[16:1];
assign AUDIO_R = audio_out[16:1];

always @(posedge CLK_32M) begin
    ce_filter_counter <= ce_filter_counter + 3'd1;
  
    if (en_audio_filters)
        audio_out <= {filtered_ym_audio[15], filtered_ym_audio[15:0]} + {filtered_mcu_sample[15], filtered_mcu_sample[15:0]};
    else
        audio_out <= {ym_audio[15], ym_audio[15:0]} + {{signed_mcu_sample[7], signed_mcu_sample[7:0], 8'd0}};
end

*/

endmodule
