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

    input sprite_freeze
);

reg paused = 0;
reg [8:0] paused_v;
reg [9:0] paused_h;

// TODO FIX pause
/*
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
*/

reg [1:0] ce_counter_cpu;
reg ce_cpu, ce_4x_cpu;

always @(posedge CLK_32M) begin
    if (!reset_n) begin
        ce_cpu <= 0;
        ce_4x_cpu <= 0;
        ce_counter_cpu <= 0;
    end else begin
        ce_cpu <= 0;
        ce_4x_cpu <= 0;

        if (~paused) begin
            if (~(ram_rom_memrq & (cpu_mem_read | cpu_mem_write)) & ~mem_rq_active) begin // stall main cpu while fetching from sdram
                ce_counter_cpu <= ce_counter_cpu + 2'd1;
                ce_4x_cpu <= 1;
                ce_cpu <= &ce_counter_cpu;
            end
        end
    end
end

wire ce_pix_half;
jtframe_frac_cen #(2) pixel_cen
(
    .clk(CLK_32M),
    .n(10'd1),
    .m(10'd4),
    .cen({ce_pix_half, ce_pix})
);

wire clock = CLK_32M;

/* Global signals from schematics */
wire IOWR = cpu_io_write; // IO Write
wire IORD = cpu_io_read; // IO Read
wire MWR = cpu_mem_write; // Mem Write
wire MRD = cpu_mem_read; // Mem Read

wire dma_busy;

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
wire [15:0] flags = { 8'hff, dma_busy, 1'b1, 1'b1 /*TEST*/, 1'b1 /*R*/, coin, start_buttons };

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

    if (buffer_memrq) d16 = ga22_dout;
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

    .buffer_memrq(buffer_memrq),
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

    .intp({5'd0, HINT, dma_busy, vblank})
);

wire vblank, hblank, vsync, hsync, vpulse, hpulse;

assign HSync = hsync;
assign HBlank = hblank;
assign VSync = vsync;
assign VBlank = vblank;

wire [15:0] pf_vram_dout;
wire [10:0] pf_color_index;
wire pf_priority;

wire P1L;

board_b_d board_b_d(
    .clk(CLK_32M),
    .clk_ram(CLK_96M),

    .ce_pix(ce_pix),

    .DOUT(pf_vram_dout),

    .DIN(cpu_word_out),
    .A(cpu_word_addr),

    .IO_DIN(cpu_io_out),
    .IO_A(cpu_io_addr),

    .MRD(MRD),
    .MWR(MWR),
    .IORD(IORD),
    .IOWR(IOWR),

    .vram_memrq(pf_vram_memrq),
    
    .NL(NL),

    .color_index(pf_color_index),
    .prio(pf_priority),

    .sdr_data(sdr_bg_dout),
    .sdr_addr(sdr_bg_addr),
    .sdr_req(sdr_bg_req),
    .sdr_rdy(sdr_bg_rdy),

    .paused(paused),

    .en_layers(en_layers),

    .vblank(vblank),
    .hblank(hblank),
    .vsync(vsync),
    .hsync(hsync),
    .hpulse(hpulse),
    .vpulse(vpulse)
);

wire objram_we;
wire [15:0] objram_data, objram_q;
wire [63:0] objram_q64;
wire [10:0] objram_addr;

objram objram(
    .clk(CLK_32M),

    .addr(objram_addr),
    .we(objram_we),

    .data(objram_data),

    .q(objram_q),
    .q64(objram_q64)
);

wire bufram_we;
wire [15:0] bufram_data, bufram_q;
wire [10:0] bufram_addr;
wire [12:0] bufram_full_addr = { 2'b00, bufram_addr }; // TODO - IC20 address line selection

dpramv #(.widthad_a(13), .width_a(16)) bufram
(
    .clock_a(CLK_32M),
    .address_a(bufram_full_addr),
    .q_a(bufram_q),
    .wren_a(bufram_we),
    .data_a(bufram_data),

    .clock_b(CLK_32M),
    .address_b(0),
    .data_b(0),
    .wren_b(0),
    .q_b()
);

dpramv #(.widthad_a(13), .width_a(16)) palram
(
    .clock_a(CLK_32M),
    .address_a(bufram_full_addr),
    .q_a(bufram_q),
    .wren_a(bufram_we),
    .data_a(bufram_data),

    .clock_b(CLK_32M),
    .address_b(0),
    .data_b(0),
    .wren_b(0),
    .q_b()
);

GA21 ga21(
    .clk(CLK_32M),
    .ce(ce_9m),

    .reset(),

    .din(cpu_word_out),
    .dout(ga21_dout),

    .addr(cpu_mem_addr[11:1]),

    .reg_cs(sprite_control_memrq),
    .buf_cs(buffer_memrq),
    .wr(MWR),

    .busy(dma_busy),

    .obj_dout(objram_data),
    .obj_din(objram_q),
    .obj_addr(objram_addr),
    .obj_we(objram_we),

    .buffer_dout(bufram_data),
    .buffer_din(bufram_q),
    .buffer_addr(bufram_addr),
    .buffer_we(bufram_we),

    .count(ga22_count),

    .pal_addr(ga21_palram_addr),
    .pal_dout(palram_data),
    .pal_din(palram_q),
    .pal_we(ga21_palram_we)
);

GA22 ga22(
    .clk(CLK_32M),
    .clk_ram(CLK_96M),

    .ce(ce_13m), // 13.33Mhz

    .ce_pix(ce_pix), // 6.66Mhz

    .reset(~n_reset),

    .color(ga22_color),

    .NL(NL),
    .hpulse(hpulse),
    .vpulse(vpulse),

    .count(ga22_count),

    .obj_data(objram_q64),

    .sdr_data(sdr_sprite_dout),
    .sdr_addr(sdr_sprite_addr),
    .sdr_req(sdr_sprite_req),
    .sdr_rdy(sdr_sprite_rdy)
);

endmodule
