//============================================================================
//  Irem M72 for MiSTer FPGA - Background layer SDRAM interface
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

import m72_pkg::*;

module board_b_d_sdram(
    input clk,
    input clk_ram,

    input [17:0] addr_a,
    output [31:0] data_a,
    input req_a,
    output rdy_a,

    input [17:0] addr_b,
    output [31:0] data_b,
    input req_b,
    output rdy_b,

    output [24:1] sdr_addr,
    input [31:0] sdr_data,
    output sdr_req,
    input sdr_rdy
);

reg [1:0] active = 0;

reg active_rq = 0;
reg active_ack = 0;
reg [31:0] active_data;

reg req_a_2 = 0;
reg req_b_2 = 0;
reg [24:1] addr_a_2, addr_b_2;

always @(posedge clk) begin
    sdr_req <= 0;
    rdy_a <= 0;
    rdy_b <= 0;

    if (req_a & ~req_a_2) begin
        req_a_2 <= 1;
        addr_a_2 <= { REGION_BG_A.base_addr[24:19], addr_a };
    end

    if (req_b & ~req_b_2) begin
        req_b_2 <= 1;
        addr_b_2 <= { REGION_BG_B.base_addr[24:19], addr_b };
    end

    if (active) begin
        if (active_ack == active_rq) begin
            active <= 0;
            if (active == 2'd1) begin
                data_a <= active_data;
                rdy_a <= 1;
            end

            if (active == 2'd2) begin
                data_b <= active_data;
                rdy_b <= 1;
            end
        end
    end else begin
        if (req_a_2) begin
            sdr_addr <= addr_a_2;
            sdr_req <= 1;
            active_rq <= ~active_rq;
            active <= 2'd1;
            req_a_2 <= 0;
        end else if (req_b_2) begin
            sdr_addr <= addr_b_2;
            sdr_req <= 1;
            active_rq <= ~active_rq;
            active <= 2'd2;
            req_b_2 <= 0;
        end
    end
end

always @(posedge clk_ram) begin
    if (sdr_rdy) begin
        active_ack <= active_rq;
        active_data <= sdr_data;
    end
end

endmodule