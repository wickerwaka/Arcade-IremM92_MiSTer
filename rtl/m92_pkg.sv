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
    parameter region_t REGION_CPU_RAM = '{ base_addr:'h010_0000, reorder_64:0, bram_cs:5'b00000 };
    parameter region_t REGION_SOUND =   '{ base_addr:'h020_0000, reorder_64:0, bram_cs:5'b00000 };
    parameter region_t REGION_GA20 =    '{ base_addr:'h030_0000, reorder_64:0, bram_cs:5'b00000 };
    parameter region_t REGION_SPRITE =  '{ base_addr:'h040_0000, reorder_64:1, bram_cs:5'b00000 };
    parameter region_t REGION_TILE =    '{ base_addr:'h080_0000, reorder_64:0, bram_cs:5'b00000 };
    parameter region_t REGION_CRYPT =   '{ base_addr:'h000_0000, reorder_64:0, bram_cs:5'b00001 };

    parameter region_t LOAD_REGIONS[6] = '{
        REGION_CPU_ROM,
        REGION_TILE,
        REGION_SPRITE,
        REGION_SOUND,
        REGION_GA20,
        REGION_CRYPT
    };

    
    typedef struct packed {
        bit [3:0] reserved;
        bit [3:0] bank_mask;
    } board_cfg_t;
endpackage