//============================================================================
//  Irem M92 for MiSTer FPGA - Sprites
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

module GA22 (
    input clk,
    input clk_ram,

    input ce, // 13.33Mhz

    input ce_pix, // 6.66Mhz

    input reset,

    output reg [11:0] color,

    input NL,
    input hpulse,
    input vpulse,

    output reg [9:0] count,

    input [63:0] obj_in,

    input [63:0] sdr_data,
    output reg [24:0] sdr_addr,
    output reg sdr_req,
    input sdr_rdy,

    input dbg_solid_sprites
);

reg [6:0] linebuf_color;
reg linebuf_prio;
reg [63:0] linebuf_bits;
reg [9:0] linebuf_x;
reg linebuf_write;
reg scan_toggle = 0;
reg [9:0] scan_pos = 0;
wire [9:0] scan_pos_nl = scan_pos ^ {10{NL}};
wire [11:0] scan_out;

double_linebuf line_buffer(
    .clk(clk),
    .ce_pix(ce_pix),
    
    .scan_pos(scan_pos_nl),
    .scan_toggle(scan_toggle),
    .scan_out(scan_out),

    .bits(linebuf_bits),
    .color(linebuf_color),
    .prio(linebuf_prio),
    .pos(linebuf_x),
    .we(linebuf_write)
);

// d is 16 pixels stored as 2 sets of 4 bitplanes
// d[31:0] is 8 pixels, made up from planes d[7:0], d[15:8], etc
// d[63:32] is 8 pixels made up from planes d[39:32], d[47:40], etc
// Returns 16 pixels stored as 4 bit planes d[15:0], d[31:16], etc
function [63:0] deswizzle(input [63:0] d, input rev);
    begin
        integer i;
        bit [7:0] plane[8];
        bit [7:0] t;
        for( i = 0; i < 8; i = i + 1 ) begin
            t = d[(i*8) +: 8];
            plane[i] = rev ? { t[0], t[1], t[2], t[3], t[4], t[5], t[6], t[7] } : t;
        end

        deswizzle[15:0]  = rev ? { plane[4], plane[0] } : { plane[0], plane[4] };
        deswizzle[31:16] = rev ? { plane[5], plane[1] } : { plane[1], plane[5] };
        deswizzle[47:32] = rev ? { plane[6], plane[2] } : { plane[2], plane[6] };
        deswizzle[63:48] = rev ? { plane[7], plane[3] } : { plane[3], plane[7] };
    end
endfunction

reg [63:0] obj_data;

wire [8:0] obj_org_y = obj_data[8:0];
wire [1:0] obj_height = obj_data[10:9];
wire [1:0] obj_width = obj_data[12:11];
wire [2:0] obj_layer = obj_data[15:13];
wire [15:0] obj_code = obj_data[31:16];
wire [6:0] obj_color = obj_data[38:32];
wire obj_pri = obj_data[39];
wire obj_flipx = obj_data[40];
wire obj_flipy = obj_data[41];
wire [9:0] obj_org_x = obj_data[57:48];

reg data_rdy;

always_ff @(posedge clk_ram) begin
    if (sdr_req)
        data_rdy <= 0;
    else if (sdr_rdy)
        data_rdy <= 1;
end

always_ff @(posedge clk) begin
    reg visible;
    reg [3:0] span;
    reg [3:0] end_span;
    reg [8:0] V;

    reg [15:0] code;
    reg [8:0] height_px;
    reg [3:0] width;
    reg [8:0] rel_y;
    reg [8:0] row_y;

    sdr_req <= 0;
    linebuf_write <= 0;

    if (reset) begin
        V <= 9'd0;
    end else if (ce) begin
        count <= count + 10'd1;

        if (ce_pix) begin
            color <= scan_out[11:0];
            scan_pos <= scan_pos + 10'd1;
            if (hpulse) begin
                count <= 10'd0;
                V <= V + 9'd1;
                scan_pos <= 10'd44;
                scan_toggle <= ~scan_toggle;
                span <= 0;
                end_span <= 0;
                visible <= 0;
            end
        end

        if (vpulse) begin
            V <= 9'd126;
        end
        case(count[1:0])
        0: begin
            linebuf_bits <= dbg_solid_sprites ? 64'hffff_ffff_ffff_ffff : deswizzle(sdr_data, obj_flipx);
            linebuf_color <= obj_color;
            linebuf_prio <= obj_pri;
            linebuf_x <= obj_org_x + ( 10'd16 * span );
            linebuf_write <= visible;
            if (span == end_span) begin
                span <= 4'd0;
                obj_data <= obj_in;
            end else begin
                span <= span + 4'd1;
            end
        end
        1: begin
            end_span <= ( 4'd1 << obj_width ) - 1;
            height_px = 9'd16 << obj_height;
            width = 4'd1 << obj_width;
            rel_y = V + obj_org_y + ( 9'd16 << obj_height );
            row_y = obj_flipy ? (height_px - rel_y - 9'd1) : rel_y;

            if (rel_y < height_px) begin
                code = obj_code + row_y[8:4] + ( ( obj_flipx ? ( width - span - 16'd1 ) : span ) * 16'd8 );
                sdr_addr <= REGION_SPRITE.base_addr[24:0] + { code[15:0], row_y[3:0], 3'b000 };
                sdr_req <= 1;
                visible <= 1;
            end else begin
                visible <= 0;
            end
        end
        1: begin
        end
        3: begin
        end
        endcase
    end

end

endmodule