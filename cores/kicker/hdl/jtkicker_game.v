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

module jtkicker_game(
    input           rst,
    input           clk,
    input           rst24,
    input           clk24,
    output          pxl2_cen,   // 12   MHz
    output          pxl_cen,    //  6   MHz
    output   [3:0]  red,
    output   [3:0]  green,
    output   [3:0]  blue,
    output          LHBL,
    output          LVBL,
    output          HS,
    output          VS,
    // cabinet I/O
    input   [ 1:0]  start_button,
    input   [ 1:0]  coin_input,
    input   [ 5:0]  joystick1,
    input   [ 5:0]  joystick2,
    // SDRAM interface
    input           downloading,
    output          dwnld_busy,
    output          sdram_req,
    output  [21:0]  sdram_addr,
    input   [15:0]  data_read,
    input           data_dst,
    input           data_rdy,
    input           sdram_ack,
    // ROM LOAD
    input   [24:0]  ioctl_addr,
    input   [ 7:0]  ioctl_dout,
    input           ioctl_wr,
    output reg [21:0] prog_addr,
    output  [ 7:0]  prog_data,
    output  [ 1:0]  prog_mask,
    output          prog_we,
    output          prog_rd,
    // DIP switches
    input   [31:0]  status,     // only bits 31:16 are looked at
    input   [31:0]  dipsw,
    input           dip_pause,
    input           service,
    inout           dip_flip,
    input           dip_test,
    input   [ 1:0]  dip_fxlevel, // Not a DIP on the original PCB
    // Sound output
    output  signed [15:0] snd,
    output          sample,
    output          game_led,
    input           enable_psg,
    input           enable_fm,
    // Debug
    input   [ 3:0]  gfx_en,
    input   [ 7:0]  debug_bus,
    output  [ 7:0]  debug_view
);

// SDRAM offsets
localparam [21:0] SCR_START   =  `SCR_START,
                  OBJ_START   =  `OBJ_START,
                  PCM_START   =  `PCM_START;
localparam [24:0] PROM_START  =  `PROM_START;

wire        main_cs, main_ok;

wire [12:0] scr_addr;
wire [13:0] obj_addr;
wire [31:0] scr_data, obj_data;
wire        scr_ok, obj_ok, objrom_cs;

wire [ 7:0] main_data;
wire [15:0] main_addr;

wire [ 7:0] dipsw_a, dipsw_b;
wire [ 3:0] dipsw_c;
wire        V16;

wire [ 2:0] pal_sel;
wire        cpu_cen, cpu4_cen, ti1_cen, ti2_cen;
wire        cpu_rnw, cpu_irqn, cpu_nmin;
wire        vscr_cs, vram_cs, obj1_cs, obj2_cs,
            prom_we, flip;
wire [ 7:0] vscr_dout, vram_dout, obj_dout, cpu_dout;
wire        vsync60;

// PCM - used by yiear
wire [15:0] pcm_addr;
wire [ 7:0] pcm_data;
wire        pcm_ok;

assign prog_rd    = 0;
assign dwnld_busy = downloading;
assign { dipsw_c, dipsw_b, dipsw_a } = dipsw[19:0];
assign dip_flip = ~dipsw_c[0];
assign debug_view = {4'hf, dipsw_c};

wire [21:0] pre_addr;
wire [ 7:0] nc;

always @(*) begin
    prog_addr = pre_addr;
    if( ioctl_addr[21:0] >= SCR_START && ioctl_addr[21:0]<OBJ_START ) begin
        prog_addr[0]   = ~pre_addr[3];
        prog_addr[3:1] =  pre_addr[2:0];
    end
    if( ioctl_addr[21:0] >= OBJ_START && ioctl_addr[21:0]<PCM_START ) begin
        prog_addr[0]   = ~pre_addr[3];
        prog_addr[1]   = ~pre_addr[4];
        prog_addr[5:2] =  { pre_addr[5], pre_addr[2:0] }; // making [5] explicit for now
    end
end

jtkicker_clocks u_clocks(
    .status     ( status    ),
    // 24 MHz domain
    .clk24      ( clk24     ),
    .cpu4_cen   ( cpu4_cen  ),
    .snd_cen    (           ),
    .psg_cen    (           ),
    .ti1_cen    ( ti1_cen   ),
    .ti2_cen    ( ti2_cen   ),
    // 48 MHz domain
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  )
);

jtframe_dwnld #(.PROM_START(PROM_START))
u_dwnld(
    .clk            ( clk           ),
    .downloading    ( downloading   ),
    .ioctl_addr     ( ioctl_addr    ),
    .ioctl_dout     ( ioctl_dout    ),
    .ioctl_wr       ( ioctl_wr      ),
    .prog_addr      ( pre_addr      ),
    .prog_data      ( {nc,prog_data}),
    .prog_mask      ( prog_mask     ), // active low
    .prog_we        ( prog_we       ),
    .prom_we        ( prom_we       ),
    .sdram_ack      ( sdram_ack     ),
    .header         (               )
);

`ifndef NOMAIN
`MAIN_MODULE u_main(
    .rst            ( rst24         ),
    .clk            ( clk24         ),        // 24 MHz
    .cpu4_cen       ( cpu4_cen      ),
    .cpu_cen        ( cpu_cen       ),
    .ti1_cen        ( ti1_cen       ),
    .ti2_cen        ( ti2_cen       ),
    // ROM
    .rom_addr       ( main_addr     ),
    .rom_cs         ( main_cs       ),
    .rom_data       ( main_data     ),
    .rom_ok         ( main_ok       ),
    // cabinet I/O
    .start_button   ( start_button  ),
    .coin_input     ( coin_input    ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .service        ( service       ),
    // GFX
    .cpu_dout       ( cpu_dout      ),
    .cpu_rnw        ( cpu_rnw       ),

    .vscr_cs        ( vscr_cs       ),
    .vram_cs        ( vram_cs       ),
    .vram_dout      ( vram_dout     ),
    .vscr_dout      ( vscr_dout     ),

    .obj1_cs        ( obj1_cs       ),
    .obj2_cs        ( obj2_cs       ),
    .obj_dout       ( obj_dout      ),
    // GFX configuration
    .pal_sel        ( pal_sel       ),
    .flip           ( flip          ),
    // interrupt triggers
    .LVBL           ( LVBL          ),
    .V16            ( V16           ),
    // DIP switches
    .dip_pause      ( dip_pause     ),
    .dipsw_a        ( dipsw_a       ),
    .dipsw_b        ( dipsw_b       ),
    .dipsw_c        ( dipsw_c       ),
    // Sound
`ifdef PCM
    .pcm_addr       ( pcm_addr      ),
    .pcm_data       ( pcm_data      ),
    .pcm_ok         ( pcm_ok        ),
`endif
    .snd            ( snd           ),
    .sample         ( sample        ),
    .peak           ( game_led      )
);
`else
    assign main_cs = 0;
    assign obj1_cs = 0;
    assign obj2_cs = 0;
    assign snd     = 0;
    assign sample  = 0;
    assign game_led= 0;
    assign pal_sel = 0;
    assign flip    = 0;
    assign pcm_addr= 0;
`endif

`ifndef PCM
    assign pcm_addr = 0;
`endif

`VIDEO_MODULE u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk24      ( clk24     ),

    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),

    // configuration
    .pal_sel    ( pal_sel   ),
    .flip       ( flip      ),

    // CPU interface
    .cpu_addr   ( main_addr[10:0]  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_rnw    ( cpu_rnw   ),
    // Scroll
    .vram_cs    ( vram_cs   ),
    .vscr_cs    ( vscr_cs   ),
    .vram_dout  ( vram_dout ),
    .vscr_dout  ( vscr_dout ),
    // Objects
    .obj1_cs    ( obj1_cs   ),
    .obj2_cs    ( obj2_cs   ),
    .obj_dout   ( obj_dout  ),

    // PROMs
    .prog_data  ( prog_data ),
    .prog_addr  ( prog_addr[10:0] ),
    .prom_en    ( prom_we   ),

    // Scroll
    .scr_addr   ( scr_addr  ),
    .scr_data   ( scr_data  ),
    .scr_ok     ( scr_ok    ),
    // Objects
    .obj_addr   ( obj_addr  ),
    .obj_data   ( obj_data  ),
    .obj_cs     ( objrom_cs ),
    .obj_ok     ( obj_ok    ),

    .V16        ( V16       ),
    .HS         ( HS        ),
    .VS         ( VS        ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus )
);


jtframe_rom #(
    .SLOT0_AW    ( 14              ),
    .SLOT0_DW    ( 32              ),
    .SLOT0_OFFSET( SCR_START>>1    ),

    .SLOT1_AW    ( 15              ),
    .SLOT1_DW    ( 32              ),
    .SLOT1_OFFSET( OBJ_START>>1    ),

    .SLOT2_AW    ( 16              ),
    .SLOT2_DW    (  8              ),
    .SLOT2_OFFSET( PCM_START>>1    ),

    .SLOT7_AW    ( 16              ),
    .SLOT7_DW    (  8              ),
    .SLOT7_OFFSET(  0              )  // Main
) u_rom (
    .rst         ( rst           ),
    .clk         ( clk           ),

    .slot0_cs    ( LVBL          ),
    .slot1_cs    ( objrom_cs     ),
    .slot2_cs    ( 1'b1          ),
    .slot3_cs    ( 1'b0          ),
    .slot4_cs    ( 1'b0          ),
    .slot5_cs    ( 1'b0          ),
    .slot6_cs    ( 1'b0          ),
    .slot7_cs    ( main_cs       ),
    .slot8_cs    ( 1'b0          ),

    .slot0_ok    ( scr_ok        ),
    .slot1_ok    ( obj_ok        ),
    .slot2_ok    ( pcm_ok        ),
    .slot3_ok    (               ),
    .slot4_ok    (               ),
    .slot5_ok    (               ),
    .slot6_ok    (               ),
    .slot7_ok    ( main_ok       ),
    .slot8_ok    (               ),

    .slot0_addr  ({scr_addr,1'b0}),
    .slot1_addr  ({obj_addr,1'b0}),
    .slot2_addr  ( pcm_addr      ),
    .slot3_addr  (               ),
    .slot4_addr  (               ),
    .slot5_addr  (               ),
    .slot6_addr  (               ),
    .slot7_addr  ( main_addr     ),
    .slot8_addr  (               ),

    .slot0_dout  ( scr_data      ),
    .slot1_dout  ( obj_data      ),
    .slot2_dout  ( pcm_data      ),
    .slot3_dout  (               ),
    .slot4_dout  (               ),
    .slot5_dout  (               ),
    .slot6_dout  (               ),
    .slot7_dout  ( main_data     ),
    .slot8_dout  (               ),

    // SDRAM interface
    .sdram_req   ( sdram_req     ),
    .sdram_ack   ( sdram_ack     ),
    .data_dst    ( data_dst      ),
    .data_rdy    ( data_rdy      ),
    .downloading ( downloading   ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     )
);

endmodule