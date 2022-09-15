//============================================================================
//  Irem M92 for MiSTer FPGA - Z80-based sound system
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

module sound (
    input CLK_32M,

    input reset,

    input [15:0] DIN,
    output [15:0] DOUT,
    output DOUT_VALID,
    
    input [19:0] A,
    input [1:0] BYTE_SEL,

    input [7:0] IO_A,
    input [7:0] IO_DIN,

    output [7:0] snd_io_addr,
    output [7:0] snd_io_data,
    output snd_io_req,

    output reg sample_inc,
    output reg [15:0] sample_addr,
    output reg [1:0] sample_addr_wr,
    output reg [7:0] sample_out,
    input [7:0] sample_in,

    input SDBEN,
    input MRD,
    input MWR,
    input SND,
    input SND2,
    input BRQ,

    input pause,

    input m84,

    output [15:0] ym_audio_l,
    output [15:0] ym_audio_r,

    // ioctl
    input clk_bram,
    input bram_wr,
    input [7:0] bram_data,
    input [19:0] bram_addr,
    input bram_cs
);


wire CE_AUDIO, CE_AUDIO_P1;
jtframe_frac_cen #(2) jt51_cen
(
    .clk(CLK_32M),
    .n(10'd83),
    .m(10'd742),
    .cen({CE_AUDIO_P1, CE_AUDIO})
);


wire [7:0] ram_dout;

assign DOUT = { ram_dout, ram_dout };
assign DOUT_VALID = MRD & SDBEN;

wire ram_region = m84 ? &ram_addr[15:12] : 1'b1;
wire ram_write = (MWR & SDBEN) | (ram_region & ~z80_MREQ_n & ~z80_WR_n);

dpramv #(.widthad_a(16)) sound_rom_ram
(
    .clock_a(CLK_32M),
    .address_a(ram_addr[15:0]),
    .q_a(ram_dout),
    .wren_a(ram_write),
    .data_a(ram_data),

    .clock_b(clk_bram),
    .address_b(bram_addr[15:0]),
    .data_b(bram_data),
    .wren_b(bram_cs & bram_wr),
    .q_b()
);

wire [7:0] SD_IN = z80_dout;
wire [7:0] SD_OUT;

wire SA0 = z80_addr[0];
wire SCS = ~z80_IORQ_n & ~|z80_addr[7:1];
wire SIRQ_N;
wire SRESET;
wire SWR_N = z80_WR_n;

wire M1_n;
wire [15:0] z80_addr;
wire z80_IORQ_n, z80_RD_n, z80_WR_n, z80_MREQ_n, z80_M1_n;

wire [15:0] ram_addr = BRQ ? A[15:0] : z80_addr;
wire [7:0] ram_data = BRQ ? DIN[7:0] : z80_dout;
wire [7:0] z80_din;
wire [7:0] z80_dout;


always_comb begin
    z80_din = 8'hff;
    if ( ~z80_M1_n & ~z80_IORQ_n ) begin
        z80_din = {2'b11, ~snd_latch1_ready, SIRQ_N, 4'b1111};
    end else if ( ~z80_RD_n ) begin
        if (SCS) begin
            z80_din = SD_OUT;
        end else if (~z80_IORQ_n) begin
            if (m84) begin
                casex (z80_addr[7:0])
                8'h80: z80_din = snd_latch1;
                8'h84: z80_din = sample_in;
                default: z80_din = 8'hff;
                endcase
            end else begin
                casex (z80_addr[7:0])
                8'bxxxx_x01x: z80_din = snd_latch1;
                8'bxxxx_x10x: z80_din = snd_latch2;
                default: z80_din = 8'hff;
                endcase
            end
        end else begin
            z80_din = ram_dout;
        end
    end
end

assign snd_io_addr = z80_addr[7:0];
assign snd_io_req = ~z80_IORQ_n;
assign snd_io_data = z80_dout;

T80s z80(
    .RESET_n(~BRQ & ~reset),
    .CLK(CLK_32M),
    .CEN(CE_AUDIO & ~pause),
    .INT_n(~(~SIRQ_N | snd_latch1_ready)),
    .BUSRQ_n(~BRQ),
    .M1_n(z80_M1_n),
    .MREQ_n(z80_MREQ_n),
    .IORQ_n(z80_IORQ_n),
    .RD_n(z80_RD_n),
    .WR_n(z80_WR_n),
    .A(z80_addr),
    .DI(z80_din),
    .DO(z80_dout),
    .NMI_n(m84 ? ~m84_nmi : ~snd_latch2_ready)
);

jt51 ym2151(
    .rst(BRQ | reset),
    .clk(CLK_32M),
    .cen(CE_AUDIO & ~pause),
    .cen_p1(CE_AUDIO_P1 & ~pause),
    .cs_n(~SCS),
    .wr_n(SWR_N),
    .a0(SA0),
    .din(SD_IN),
    .dout(SD_OUT),
    .irq_n(SIRQ_N),
    .xleft(ym_audio_l),
    .xright(ym_audio_r)
);

reg [7:0] snd_latch1;
reg snd_latch1_ready = 0;

reg [7:0] snd_latch2;
reg snd_latch2_ready = 0;

reg [11:0] nmi_counter = 0;
reg m84_nmi = 0;
reg z80_IORQ_n_old;

always @(posedge CLK_32M) begin
    sample_inc <= 0;
    sample_addr_wr <= 2'b00;

    if (reset) begin
        m84_nmi <= 0;
        nmi_counter <= 0;
    end else if (~pause) begin

        nmi_counter <= nmi_counter + 12'd1;
        if (&nmi_counter) m84_nmi <= 1;

        if (SND & ~IO_A[0]) begin
            snd_latch1 <= IO_DIN[7:0];
            snd_latch1_ready <= 1;
        end

        if (SND2 & ~IO_A[0]) begin
            snd_latch2 <= IO_DIN[7:0];
            snd_latch2_ready <= 1;
        end

        if (~z80_M1_n && ~z80_MREQ_n && z80_addr == 16'h0066)
            m84_nmi <= 0;

        z80_IORQ_n_old <= z80_IORQ_n;
        if (z80_IORQ_n_old & ~z80_IORQ_n) begin

            if (m84) begin
                if (~z80_WR_n & z80_addr[7:0] == 8'h80) begin
                    sample_addr <= { 8'h00, z80_dout };
                    sample_addr_wr <= 2'b01;
                end

                if (~z80_WR_n & z80_addr[7:0] == 8'h81) begin
                    sample_addr <= { z80_dout, 8'h00 };
                    sample_addr_wr <= 2'b10;
                end

                if (~z80_WR_n & z80_addr[7:0] == 8'h82) begin
                    sample_out <= z80_dout;
                    sample_inc <= 1;
                end

                if (~z80_WR_n & z80_addr[7:0] == 8'h83) snd_latch1_ready <= 0;
            end else begin
                if (~z80_WR_n & z80_addr[2:1] == 2'b11) snd_latch1_ready <= 0;
                if (~z80_RD_n & (z80_addr[2:1] == 2'b10)) snd_latch2_ready <= 0;
            end
        end
    end
end


endmodule