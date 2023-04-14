//============================================================================
//  Copyright (C) 2023 Martin Donlon
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

module mame_keys(
    input clk,
    input reset,

    input [10:0] ps2_key,

    output reg [3:0] start,
    output reg [3:0] coin,

    // { 8'h0, Y, X, B, A, U, D, L, R }
    output reg [7:0] p1,
    output reg [7:0] p2,
    output reg [7:0] p3,
    output reg [7:0] p4,

    output reg pause
);

always_ff @(posedge clk) begin
    reg old_state;
    bit p;
		 

    if (reset) begin
        p1 <= 8'd0;
        p2 <= 8'd0;
        p3 <= 8'd0;
        p4 <= 8'd0;

        start <= 4'd0;
        coin  <= 4'd0;

        pause <= 0;
    end else begin
		p = ps2_key[9];
        
        old_state <= ps2_key[10];
        if(old_state != ps2_key[10]) begin
            case(ps2_key[8:0])
                'h016: start[0] <= p; // 1
                'h01e: start[1] <= p; // 2
                'h026: start[2] <= p; // 3
                'h025: start[3] <= p; // 4

                'h02e: coin[0]  <= p; // 5
                'h036: coin[1]  <= p; // 6
                'h03D: coin[2]  <= p; // 7
                'h03e: coin[2]  <= p; // 8

                'h175: p1[3]    <= p; // up
                'h172: p1[2]    <= p; // down
                'h16b: p1[1]    <= p; // left
                'h174: p1[0]    <= p; // right
                'h014: p1[4]    <= p; // ctrl
                'h011: p1[5]    <= p; // alt
                'h029: p1[6]    <= p; // space
                'h012: p1[7]    <= p; // shift

                'h02d: p2[3]    <= p; // r
                'h02b: p2[2]    <= p; // f
                'h023: p2[1]    <= p; // d
                'h034: p2[0]    <= p; // g
                'h01c: p2[4]    <= p; // a
                'h01b: p2[5]    <= p; // s
                'h015: p2[6]    <= p; // q
                'h01d: p2[7]    <= p; // w

                'h043: p3[3]    <= p; // i
                'h042: p3[2]    <= p; // k
                'h03b: p3[1]    <= p; // j
                'h04b: p3[0]    <= p; // l
                'h114: p3[4]    <= p; // rctrl
                'h059: p3[5]    <= p; // rshift
                'h05a: p3[6]    <= p; // enter

                'h075: p4[3]    <= p; // num 8
                'h072: p4[2]    <= p; // num 2
                'h06b: p4[1]    <= p; // num 4
                'h074: p4[0]    <= p; // num 6
                'h070: p4[4]    <= p; // num 0
                'h071: p4[5]    <= p; // num .
                'h15a: p4[6]    <= p; // num enter

                'h04d: pause    <= p; // pause
            endcase
        end
    end
end

endmodule