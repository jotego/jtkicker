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
    Date: 15-11-2021 */

module jtkicker_obj(
    input               rst,
    input               clk,        // 48 MHz
    input               clk24,      // 24 MHz

    input               pxl_cen,
    input         [2:0] pal_sel,

    // CPU interface
    input        [10:0] cpu_addr,
    input         [7:0] cpu_din,
    input               obj1_cs,
    input               obj2_cs,
    input               cpu_rnw,
    input               vscr_cs,
    output        [7:0] obj_dout,
    output        [7:0] vscr_dout,

    // video inputs
    input               LHBL,
    input               LVBL,
    input         [7:0] vdump,
    input         [8:0] hdump,
    input               flip,

    // PROMs
    input         [3:0] prog_data,
    input         [7:0] prog_addr,
    input               prog_en,

    // SDRAM
    output       [12:0] rom_addr,
    input        [31:0] rom_data,
    input               rom_ok,

    output        [3:0] pxl,
);

wire [ 7:0] code, attr, vram_high, vram_low;
wire [ 3:0] pal_msb;
reg  [31:0] pxl_data;
wire [ 9:0] scan_addr;
reg  [ 7:0] hdf, vpos, vscr;
reg         cur_hf;
wire        vram_we_low, vram_high;
wire        vflip;

assign obj_dout = obj1_cs ? obj1_dout : obj2_dout;
assign obj1_we  = obj1_cs & ~cpu_rnw;
assign obj2_we  = obj2_cs & ~cpu_rnw;

assign vflip = attr[5];
assign hflip = attr[4];
assign code_msb = attr[7:6];
assign pal_msb  = attr[3:0];

always @(*) begin
    hdf = {8{flip}} ^ hdump;
end

assign rom_addr = { code, vscr[2:0]^{3{vflip}} }; // 2+8+3=13 bits
assign pxl      = cur_hf ? pxl_data[3:0] : pxl_data[31:28];
assign scan_addr  = { vscr[7:3], hdf[7:3] }; // 5+5 = 10
assign vscr_dout= vscr;

// scroll register in custom chip 085
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        vpos <= 0;
        vscr <= 0;
    end else begin
        if( vscr_cs  ) vpos <= cpu_dout;
        if( hdump[8] ) vscr <= {8{flip}} ^ (vpos+vdump);
    end
end

always @(posedge clk) if(pxl_cen) begin
    if( hdf[2:0]==1 ) begin // 2 pixel delay to grab data
        pxl_data <= {
            rom_data[31], rom_data[27], rom_data[23], rom_data[19],
            rom_data[30], rom_data[26], rom_data[22], rom_data[18],
            rom_data[29], rom_data[25], rom_data[21], rom_data[17],
            rom_data[28], rom_data[24], rom_data[20], rom_data[16],

            rom_data[15], rom_data[11], rom_data[ 7], rom_data[ 3],
            rom_data[14], rom_data[10], rom_data[ 6], rom_data[ 2],
            rom_data[13], rom_data[ 9], rom_data[ 5], rom_data[ 1],
            rom_data[12], rom_data[ 8], rom_data[ 4], rom_data[ 0]
        };
        cur_hf   <= hflip;
    end else begin
        pxl_data <= cur_hf ? pxl_data>>4 : pxl_data<<4;
    end
end

jtframe_dual_ram u_low(
    // Port 0, CPU
    .clk0   ( clk24         ),
    .data0  ( cpu_dout      ),
    .addr0  ( cpu_addr[9:0] ),
    .we0    ( obj1_we       ),
    .q0     ( obj1_dout     ),
    // Port 1
    .clk1   ( clk           ),
    .data1  (               ),
    .addr1  ( scan_addr     ),
    .we1    ( 1'b0          ),
    .q1     ( code          )
);

jtframe_dual_ram u_high(
    // Port 0, CPU
    .clk0   ( clk24         ),
    .data0  ( cpu_dout      ),
    .addr0  ( cpu_addr[9:0] ),
    .we0    ( obj2_we       ),
    .q0     ( obj2_dout     ),
    // Port 1
    .clk1   ( clk           ),
    .data1  (               ),
    .addr1  ( scan_addr     ),
    .we1    ( 1'b0          ),
    .q1     ( attr          )
);

jtframe_prom #(
    .dw ( 4     ),
    .aw ( 8     )
//    simfile = "477j08.f16",
) u_palette(
    .clk    ( clk       ),
    .cen    ( pxl_cen   ),
    .data   ( prog_data ),
    .wr_addr( prog_addr ),
    .we     ( prog_en   ),

    .scan_addr( pal_addr  ),
    .q      ( pxl       )
);

endmodule