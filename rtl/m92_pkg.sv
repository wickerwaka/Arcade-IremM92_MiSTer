//============================================================================
//  Irem M92 for MiSTer FPGA - Common definitions
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

package m92_pkg;

    typedef struct packed {
        bit [24:0] base_addr;
        bit reorder_64;
        bit [4:0] bram_cs;
    } region_t;

    parameter region_t REGION_CPU_ROM = '{ base_addr:'h000_0000, reorder_64:0, bram_cs:5'b00000 };
    parameter region_t REGION_SPRITE =  '{ base_addr:'h010_0000, reorder_64:1, bram_cs:5'b00000 };
    parameter region_t REGION_BG_A =    '{ base_addr:'h100_0000, reorder_64:0, bram_cs:5'b00000 };
    parameter region_t REGION_BG_B =    '{ base_addr:'h020_0000, reorder_64:0, bram_cs:5'b00000 };
    parameter region_t REGION_MCU =     '{ base_addr:'h000_0000, reorder_64:0, bram_cs:5'b00001 };
    parameter region_t REGION_SAMPLES = '{ base_addr:'h000_0000, reorder_64:0, bram_cs:5'b00010 };
    parameter region_t REGION_OFFSETS = '{ base_addr:'h000_0000, reorder_64:0, bram_cs:5'b00100 };
    parameter region_t REGION_PROTECT = '{ base_addr:'h000_0000, reorder_64:0, bram_cs:5'b01000 };
    parameter region_t REGION_SOUND   = '{ base_addr:'h000_0000, reorder_64:0, bram_cs:5'b10000 };

    parameter region_t LOAD_REGIONS[9] = '{
        REGION_CPU_ROM,
        REGION_SPRITE,
        REGION_BG_A,
        REGION_BG_B,
        REGION_MCU,
        REGION_SAMPLES,
        REGION_OFFSETS,
        REGION_PROTECT,
        REGION_SOUND
    };

    parameter region_t REGION_CPU_RAM = '{ 'h400000, 0, 5'b00000 };

    typedef struct packed {
        bit [2:0] reserved;
        bit m84;
        bit main_mculatch;
        bit [2:0] memory_map;
    } board_cfg_t;
endpackage