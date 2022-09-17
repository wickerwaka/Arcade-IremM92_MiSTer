//============================================================================
//  Irem M92 for MiSTer FPGA - PAL address decoders
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

module address_translator
(
    input logic [19:0] A,
  
    input board_cfg_t board_cfg,

    output [24:0] sdr_addr,
    output writable,
    output ram_rom_memrq,

    output sprite_memrq,
    output palette_memrq,
    output sprite_control_memrq,
    output video_control_memrq,
    output pf_vram_memrq
);


always_comb begin
    ram_rom_memrq = 0;
    writable = 0;
    sdr_addr = 0;

    sprite_memrq = 0;
    palette_memrq = 0;
    sprite_control_memrq = 0;
    video_control_memrq = 0;
    pf_vram_memrq = 0;

    case (board_cfg.memory_map)
    0: begin
        casex (A[19:0])
        // 0xc0000-0xcffff
        20'b1100_xxxx_xxxx_xxxx_xxxx: begin ram_rom_memrq = 1; writable = 0; sdr_addr = REGION_CPU_ROM.base_addr[24:0] | A[15:0]; end
        // 0xd0000-0xdffff
        20'b1101_xxxx_xxxx_xxxx_xxxx: pf_vram_memrq = 1;
        // 0xe0000-0xeffff
        20'b1110_xxxx_xxxx_xxxx_xxxx: begin ram_rom_memrq = 1; writable = 1; sdr_addr = REGION_CPU_RAM.base_addr[24:0] | A[15:0]; end
        // 0xf8000-0xf87ff
        20'b1111_1000_0xxx_xxxx_xxxx: sprite_memrq = 1;
        // 0xf8800-0xf8fff
        20'b1111_1000_1xxx_xxxx_xxxx: palette_memrq = 1;
        // 0xf9000-0xf900f
        20'b1111_1001_0000_0000_xxxx: sprite_control_memrq = 1;
        // 0xf9800-0xf9801
        20'b1111_1001_1000_0000_000x: video_control_memrq = 1;
        // 0xffff0-0xfffff
        20'b1111_1111_1111_1111_xxxx: begin ram_rom_memrq = 1; writable = 0; sdr_addr = REGION_CPU_ROM.base_addr[24:0] | 20'h7fff0 | A[3:0]; end
        // 0x00000-0xbffff
        default: begin ram_rom_memrq = 1; writable = 0; sdr_addr = REGION_CPU_ROM.base_addr[24:0] | A[19:0]; end
        endcase
    end

    default: begin
    end
        
    endcase
end
endmodule
