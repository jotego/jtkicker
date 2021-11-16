/*  This file is part of JTKICKER.
    JTKICKER program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTKICKER program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTKICKER.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 11-11-2021 */

module jtkicker_video(
    input               rst,
    input               clk,        // 48 MHz
    input               clk24,      // 24 MHz

    input               pxl_cen,
    input               pxl2_cen,

    // configuration
    input         [2:0] pal_sel,
    input               flip,

    // CPU interface
    input        [10:0] cpu_addr,
    input         [7:0] cpu_dout,
    input               cpu_rnw,

    input               vram_cs,
    input               vscr_cs,
    output        [7:0] vram_dout,
    output        [7:0] vscr_dout,

    input               obj1_cs,
    input               obj2_cs,
    output        [7:0] obj_dout,

    // PROMs
    input         [3:0] prog_data,
    input        [10:0] prog_addr,
    input               prom_en,

    // Scroll
    output       [12:0] scr_addr,
    input        [31:0] scr_data,
    input               scr_ok,

    // Objects
    output       [12:0] obj_addr,
    input        [31:0] obj_data,
    input               obj_ok,

    output              HS,
    output              VS,
    output              V16,
    output              LVBL,
    output              LHBL_dly,
    output              LVBL_dly,
    output        [3:0] red,
    output        [3:0] green,
    output        [3:0] blue
);

wire       LHBL;
wire [8:0] vdump, vrender, hdump;
wire [3:0] obj_pxl, scr_pxl;
reg  [4:0] prom_we;

assign V16 = vdump[4];

always @* begin
    prom_we = 0;
    prom_we[ prog_addr[10:8] ] = prom_en;
end

// The original counter keeps hdump[7] high
// while hdump[8] is hight (i.e. during HBLANK)
// The rest of the count should match quite well
// the original, particularly VBLANK, H period
// and V period
jtframe_vtimer #(
    .VB_START   (  9'd236   ),
    .VB_END     (  9'd019   ),
    .VCNT_END   (  9'd263   ),
    .VS_START   (  9'd254   ),
    .VS_END     (  9'd2     ),
    .HB_END     (  9'd383   ),
    .HB_START   (  9'd255   ),
    .HCNT_END   (  9'd383   ),
    .HS_START   (  9'd320   ),
    .HS_END     (  9'd338   )
) u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   (           ),
    .H          ( hdump     ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .HS         ( HS        ),
    .VS         ( VS        )
);

jtkicker_scroll u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk24      ( clk24     ),

    .pxl_cen    ( pxl_cen   ),
    .pal_sel    ( pal_sel   ),

    // CPU interface
    .cpu_addr   ( cpu_addr  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_rnw    ( cpu_rnw   ),
    .vram_cs    ( vram_cs   ),
    .vscr_cs    ( vscr_cs   ),
    .vram_dout  ( vram_dout ),
    .vscr_dout  ( vscr_dout ),

    // video inputs
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .vdump      ( vdump[7:0]),
    .hdump      ( hdump     ),
    .flip       ( flip      ),

    // PROMs
    .prog_data  ( prog_data ),
    .prog_addr  ( prog_addr[7:0] ),
    .prog_en    ( prom_we[3]),

    // SDRAM
    .rom_addr   ( scr_addr  ),
    .rom_data   ( scr_data  ),
    .rom_ok     ( scr_ok    ),

    .pxl        ( scr_pxl   )
);

jtkicker_obj u_obj(
    .rst        ( rst       ),
    .clk        ( clk       ),        // 48 MHz
    .clk24      ( clk24     ),      // 24 MHz

    .pxl_cen    ( pxl_cen   ),

    // CPU interface
    .cpu_addr   ( cpu_addr  ),
    .cpu_dout   ( cpu_dout  ),
    .obj1_cs    ( obj1_cs   ),
    .obj2_cs    ( obj2_cs   ),
    .cpu_rnw    ( cpu_rnw   ),
    .obj_dout   ( obj_dout  ),

    // video inputs
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    .flip       ( flip      ),

    // PROMs
    .prog_data  ( prog_data ),
    .prog_addr  ( prog_addr[7:0] ),
    .prog_en    ( prom_we[4]),

    // SDRAM
    .rom_addr   ( obj_addr  ),
    .rom_data   ( obj_data  ),
    .rom_ok     ( obj_ok    ),

    .pxl        ( obj_pxl   )
);

jtkicker_colmix u_colmix(
    .clk        ( clk       ),

    .pxl_cen    ( pxl_cen   ),
    .pal_sel    ( pal_sel   ),

    // video inputs
    .obj_pxl    ( obj_pxl   ),
    .scr_pxl    ( scr_pxl   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),

    // PROMs
    .prog_data  ( prog_data ),
    .prog_addr  (prog_addr[7:0]),
    .prog_en    (prom_we[2:0]),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    .LHBL_dly   ( LHBL_dly  ),
    .LVBL_dly   ( LVBL_dly  )
);

endmodule