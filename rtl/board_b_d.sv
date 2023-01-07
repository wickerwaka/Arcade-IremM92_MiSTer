//============================================================================
//  Irem M92 for MiSTer FPGA - B-D board, two background layers
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


module board_b_d (
    input clk,
    input clk_ram,
    input ce_pix,

    output [15:0] DOUT,
    input [15:0] DIN,
    input [19:0] A,

    input [7:0] IO_A,
    input [7:0] IO_DIN,

    input MRD,
    input MWR,
    input IORD,
    input IOWR,
    input vram_memrq,
    input NL,

    output [10:0] color_index,
    output prio,

    input [63:0] sdr_data,
    output [24:0] sdr_addr,
    output sdr_req,
    input sdr_rdy,

    input paused,
    
    input [2:0] en_layers,

    output vblank,
    output hblank,
    output vsync,
    output hsync,
    output hpulse,
    output vpulse
);

GA23 ga23(
    .clk(clk),
    .ce(ce_pix),
    
    .reset(0),

    .vblank(vblank),
    .vsync(vsync),
    .hblank(hblank),
    .hsync(hsync),

    .hpulse(hpulse),
    .vpulse(vpulse)
);

dpramv_16 #(.widthad_a(15)) vram(
    .clock_a(clk),
    .address_a(A[15:1]),
    .q_a(DOUT),
    .wren_a((vram_memrq & MWR) ? 2'b11 : 2'b00),
    .data_a(DIN),

    .clock_b(clk),
    .address_b(0),
    .q_b(),
    .wren_b(2'b00),
    .data_b()
);

endmodule
