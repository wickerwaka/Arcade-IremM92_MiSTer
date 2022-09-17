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
    input CLK_32M,
    input CLK_96M,
    input CE_PIX,

    output [15:0] DOUT,

    input [15:0] DIN,
    input [19:0] A,
    input [1:0]  BYTE_SEL,

    input [7:0] IO_A,
    input [7:0] IO_DIN,

    input MRD,
    input MWR,
    input IORD,
    input IOWR,
    input vram_memrq,
    input NL,

    input CLD,
    input [8:0] VE,
    input [8:0] HE,
    input [8:0] H,

    output [10:0] color_index,
    output P1L,

    input [63:0] sdr_data,
    output [24:0] sdr_addr,
    output sdr_req,
    input sdr_rdy,

    input paused,
    
    input en_layer_a,
    input en_layer_b,
    input en_palette
);

wire [15:0] prolog_addr;
reg [15:0] tile_addr;

wire [15:0] vram_addr = prolog ? prolog_addr : tile_addr;
wire [15:0] vram_data;

dpramv_16 #(.widthad_a(15)) vram(
    .clock_a(CLK_32M),
    .address_a(A[15:1]),
    .q_a(DOUT),
    .wren_a((vram_memrq & MWR) ? BYTE_SEL : 2'b00),
    .data_a(DIN),

    .clock_b(CLK_32M),
    .address_b(vram_addr[15:1]),
    .q_b(vram_data),
    .wren_b(2'b00),
    .data_b()
);

always_comb begin
	prolog_addr = 16'h0;
    if (prolog) begin
        case (H[2:0])
        0: prolog_addr = 16'hf400 + VE;
        2: prolog_addr = 16'hf800 + VE;
        4: prolog_addr = 16'hfc00 + VE;
        default: prolog_addr = 16'h0;
        endcase
    end
end

always_ff @(posedge CLK_32M) begin
    reg [2:0] st = 0;

    st <= st + 3'd1;
    if (st == 5) st <= 0;

    case (st)
    0: begin tile_addr <= { vram_base[0], 14'd0 } + { tile_index[0], 2'b00 }; tile_data[2][15:0]  <= vram_data; end
    1: begin tile_addr <= { vram_base[0], 14'd0 } + { tile_index[0], 2'b10 }; tile_data[2][31:16] <= vram_data; end
    2: begin tile_addr <= { vram_base[1], 14'd0 } + { tile_index[1], 2'b00 }; tile_data[0][15:0]  <= vram_data; end
    3: begin tile_addr <= { vram_base[1], 14'd0 } + { tile_index[1], 2'b10 }; tile_data[0][31:16] <= vram_data; end
    4: begin tile_addr <= { vram_base[2], 14'd0 } + { tile_index[2], 2'b00 }; tile_data[1][15:0]  <= vram_data; end
    5: begin tile_addr <= { vram_base[2], 14'd0 } + { tile_index[2], 2'b10 }; tile_data[1][31:16] <= vram_data; end
    endcase
end

reg prolog = 0;

reg [10:0] row_scroll[3];
reg [10:0] v_adj[3], h_adj[3];
reg [7:0] control[3];

wire [12:0] tile_index[3];
reg [31:0] tile_data[3];

wire [1:0] vram_base[3] = '{ control[0][1:0], control[1][1:0], control[2][1:0] };
wire wide[3] = '{ control[0][2], control[1][2], control[1][2] };
wire enabled[3] = '{ control[0][3], control[1][3], control[1][3] };
wire row_scrolled[3] = '{ control[0][4], control[1][4], control[1][4] };

always_ff @(posedge CLK_32M) begin
    if (CE_PIX) begin
        if (CLD) begin
            prolog <= 1;
        end
    end
    
    if (prolog) begin
        case (H[2:0])
        1: row_scroll[0] <= vram_data[10:0];
        3: row_scroll[1] <= vram_data[10:0];
        5: row_scroll[2] <= vram_data[10:0];
        7: prolog <= 0;
        default: begin end
        endcase
    end else begin
        if (IOWR) begin
            case (IO_A)
            8'h80: v_adj[0][7:0] <= IO_DIN;
            8'h81: v_adj[0][10:8] <= IO_DIN[2:0];
            8'h84: h_adj[0][7:0] <= IO_DIN;
            8'h85: h_adj[0][10:8] <= IO_DIN[2:0];

            8'h88: v_adj[1][7:0] <= IO_DIN;
            8'h89: v_adj[1][10:8] <= IO_DIN[2:0];
            8'h8c: h_adj[1][7:0] <= IO_DIN;
            8'h8d: h_adj[1][10:8] <= IO_DIN[2:0];

            8'h90: v_adj[2][7:0] <= IO_DIN;
            8'h91: v_adj[2][10:8] <= IO_DIN[2:0];
            8'h94: h_adj[2][7:0] <= IO_DIN;
            8'h95: h_adj[2][10:8] <= IO_DIN[2:0];

            8'h98: control[0] <= IO_DIN;
            8'h9a: control[1] <= IO_DIN;
            8'h9c: control[2] <= IO_DIN;

            default: begin end
            endcase
        end
    end
end

wire [20:0] addr[3];
wire [31:0] data[3];
wire req[3], rdy[3];

wire [3:0] pf_color[3];
wire [5:0] pf_palette[3];
wire pf_cp8[3], pf_cp15[3];

board_b_d_sdram board_b_d_sdram(
    .clk_ram(CLK_96M),
    .clk(CLK_32M),

    .addr_a(addr[0]),
    .data_a(data[0]),
    .req_a(req[0]),
    .rdy_a(rdy[0]),

    .addr_b(addr[1]),
    .data_b(data[1]),
    .req_b(req[1]),
    .rdy_b(rdy[1]),

    .addr_c(addr[2]),
    .data_c(data[2]),
    .req_c(req[2]),
    .rdy_c(rdy[2]),

    .sdr_addr(sdr_addr),
    .sdr_data(sdr_data),
    .sdr_req(sdr_req),
    .sdr_rdy(sdr_rdy)
);

generate
	genvar i;
    for(i = 0; i < 3; i = i + 1 ) begin : generate_pf
        board_b_d_layer pf(
            .CLK_32M(CLK_32M),
            .CE_PIX(CE_PIX),

            .NL(NL),

            .VE(VE),
            .HE(HE),

            .wide(wide[i]),
            .v_adj(v_adj[i]),
            .h_adj(row_scrolled[i] ? row_scroll[i] : h_adj[i]),

            .tile_data(tile_data[i]),
            .tile_index(tile_index[i]),

            .color(pf_color[i]),
            .palette(pf_palette[i]),
            .CP15(pf_cp15[i]),
            .CP8(pf_cp8[i]),

            .sdr_addr(addr[i]),
            .sdr_data(data[i]),
            .sdr_req(req[i]),
            .sdr_rdy(rdy[i]),

            .enabled(en_layer_a),
            .paused(paused)
        );
    end
endgenerate

assign color_index = pf_color[0] != 4'b0000 ? { pf_palette[0], pf_color[0] } : pf_color[1] != 4'b0000 ? { pf_palette[1], pf_color[1] } : { pf_palette[2], pf_color[2] };

endmodule



