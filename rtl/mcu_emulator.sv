//============================================================================
//  Irem M72 for MiSTer FPGA - Emulate the protection and sample playback
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

module mcu_emulator(
    input CLK_32M,
    input ce_8m,
    input reset,

    output active,

    // shared ram
    output [11:0] ext_ram_addr,
    input [7:0] ext_ram_din,
    output [7:0] ext_ram_dout,
    output ext_ram_cs,
    output ext_ram_we,
    input ext_ram_int,

    // z80 latch
    input [7:0] z80_din,
    input z80_latch_en,

    output reg [17:0] sample_addr,
    input [7:0] sample_din,
    output reg [7:0] sample_data,

    // ioctl
    input clk_bram,
    input bram_wr,
    input [7:0] bram_data,
    input [19:0] bram_addr,
    input bram_offsets_cs,
    input bram_protect_cs
);

assign active = sample_offsets_count != 0;

reg [5:0] sample_offsets_count = 0;
reg [17:0] sample_offsets[64];
reg sample_playing = 0;
reg [9:0] sample_counter = 0;

// 18 byte checksum, followed by up to 110 bytes of x86 code
reg [7:0] protection_data[128];

// ingest 
always_ff @(posedge clk_bram) begin
    reg [7:0] buffer[3];
    if (bram_wr) begin
        if (bram_offsets_cs) begin
            if (bram_addr[1:0] == 2'b11) begin
                sample_offsets[sample_offsets_count] <= 18'{ buffer[1], buffer[2], bram_data };
                sample_offsets_count <= sample_offsets_count + 6'd1;
            end else begin
                buffer[bram_addr[1:0]] <= bram_data;
            end
        end

        if (bram_protect_cs) begin
            protection_data[bram_addr[6:0]] <= bram_data;
        end
    end
end

always @(posedge CLK_32M or posedge reset) begin
    if (reset) begin
        sample_counter <= 0;
        sample_playing <= 0;
        sample_data <= 8'h80;
    end else begin
        if (ce_8m) begin
            sample_counter <= sample_counter + 10'd1;
            if (sample_playing) begin
                if (sample_din == 8'd0) begin
                    sample_playing <= 0;
                    sample_data <= 8'h80;
                end else if(&sample_counter) begin
                    sample_data <= sample_din;
                    sample_addr <= sample_addr + 18'd1;
                end
            end
        end
    
        if (z80_latch_en) begin
            if (z80_din < sample_offsets_count) begin
                    sample_addr <= sample_offsets[z80_din];
                    sample_playing <= 1;
            end
        end
    end
end

endmodule