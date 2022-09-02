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
    output reg [11:0] ext_ram_addr,
    input [7:0] ext_ram_din,
    output reg [7:0] ext_ram_dout,
    output reg ext_ram_cs,
    output reg ext_ram_we,
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
                sample_offsets[sample_offsets_count] <= { buffer[1], buffer[2], bram_data };
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

enum {
    INIT,
    WAIT_FOR_INT,
    XOR_DATA,
    WAIT_FOR_C7FE,
    WRITE_CODE,
    WAIT_FOR_INT2,
    WRITE_CHECKSUM,
    DONE
} state = INIT;

always @(posedge CLK_32M or posedge reset) begin
    reg [15:0] ptr;
    if (reset) begin
        state <= INIT;
        ext_ram_cs <= 0;
        ext_ram_we <= 0;
    end else begin
        if (ce_8m) begin
            ext_ram_cs <= 0;
            ext_ram_we <= 0;

            case(state)
            INIT: begin // clear int flag if it's set
                ext_ram_cs <= 1;
                ext_ram_addr <= 12'hfff;
                state <= WAIT_FOR_INT;
            end

            WAIT_FOR_INT: begin
                if (ext_ram_int) begin
                    ext_ram_cs <= 1;
                    ext_ram_addr <= 12'hfff;
                    state <= XOR_DATA;
                    ptr <= 16'hc000;
                end
            end

            XOR_DATA: begin
                if (ptr == 16'hd000) begin
                    state <= WAIT_FOR_C7FE;
                    ext_ram_cs <= 1;
                    ext_ram_addr <= 12'h7fe;
                end else begin
                    ptr <= ptr + 16'd1;
                    ext_ram_cs <= 1;
                    ext_ram_we <= 1;
                    ext_ram_addr <= ptr[11:0];
                    ext_ram_dout <= ~({4'b0, ptr[11:8]} + ptr[7:0]);
                end
            end

				WAIT_FOR_C7FE: begin
                if (ext_ram_din != 8'hfa) begin
                    state <= WRITE_CODE;
                    ptr <= 16'h18;
                end else begin
                    ext_ram_cs <= 1;
                end
            end

            WRITE_CODE: begin
                if (ptr == 16'h128) begin
                    state <= WAIT_FOR_INT2;
                end else begin
                    ext_ram_cs <= 1;
                    ext_ram_we <= 1;
                    ext_ram_addr <= ptr - 16'h18;
                    ext_ram_dout <= protection_data[ptr];
                    ptr <= ptr + 16'd1;
                end
            end

            WAIT_FOR_INT2: begin
                if (ext_ram_int) begin
                    ext_ram_cs <= 1;
                    ext_ram_addr <= 12'hfff;
                    state <= WRITE_CHECKSUM;
                    ptr <= 16'h0;
                end
            end
            
            WRITE_CHECKSUM: begin
                if (ptr == 16'd18) begin
                    state <= DONE;
                end else begin
                    ext_ram_cs <= 1;
                    ext_ram_we <= 1;
                    ext_ram_addr <= 16'h7e0 + ptr;
                    ext_ram_dout <= protection_data[ptr];
                    ptr <= ptr + 16'd1;
                end
            end
            
            DONE: begin
            end
                
            endcase
        end
    end
end

endmodule