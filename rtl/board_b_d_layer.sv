//============================================================================
//  Irem M92 for MiSTer FPGA - Background layer
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

module board_b_d_layer(
    input CLK_32M,
    input CE_PIX,

    input NL,

    input [8:0] VE,
    input [8:0] HE,

    input wide,
    input [9:0] v_adj,
    input [9:0] h_adj,


    input [31:0] tile_data,
    output reg [12:0] tile_index,

    output [3:0] color,
    output reg [5:0] palette,
    output reg CP15,
    output reg CP8,

    input [31:0] sdr_data,
    output [20:0] sdr_addr,
    output sdr_req,
    input sdr_rdy,

    input enabled,
    input paused
);


reg [31:0] rom_data;
wire [3:0] BITF, BITR;

kna6034201 kna6034201(
    .clock(CLK_32M),
    .CE_PIXEL(CE_PIX),
    .LOAD(SH[2:0] == 3'b111),
    .byte_1(enabled ? rom_data[7:0] : 8'h00),
    .byte_2(enabled ? rom_data[15:8] : 8'h00),
    .byte_3(enabled ? rom_data[23:16] : 8'h00),
    .byte_4(enabled ? rom_data[31:24] : 8'h00),
    .bit_1(BITF[0]),
    .bit_2(BITF[1]),
    .bit_3(BITF[2]),
    .bit_4(BITF[3]),
    .bit_1r(BITR[0]),
    .bit_2r(BITR[1]),
    .bit_3r(BITR[2]),
    .bit_4r(BITR[3])
);

wire [9:0] SV = VE + v_adj;
wire [9:0] SH = ( HE + h_adj ) ^ { 7'b0, {3{NL}} };

reg HREV2;

wire [2:0] RV = SV[2:0] ^ {3{VREV}};
wire VREV = tile_data[26];
wire HREV1 = tile_data[25];
wire [16:0] COD = {tile_data[31], tile_data[15:0]};

assign color = (HREV2 ^ NL) ? BITR : BITF;

always @(posedge CLK_32M) begin
    reg do_rom;

    sdr_req <= 0;
    do_rom <= 0;

    if (do_rom) begin
        sdr_addr <= {COD[15:0], RV[2:0], 2'b00}; // TODO, truncating COD here
        sdr_req <= 1;
    end else if (sdr_rdy) begin
        rom_data <= sdr_data;
    end

    if (CE_PIX) begin
        if (SH[2:0] == 2'b000) begin
            if (wide)
                tile_index <= {SV[8:3], SH[9:3]};
            else
                tile_index <= {1'b0, SV[8:3], SH[8:3]};
        end
        
        if (SH[2:0] == 2'b010) begin
            do_rom <= 1;
        end
        
        if (SH[2:0] == 3'b111) begin
            palette <= tile_data[21:16]; // TODO 7-bit palette
            CP15 <= tile_data[24];
            CP8 <= tile_data[23];
            HREV2 <= HREV1;
        end
    end
end


endmodule