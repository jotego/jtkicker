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
    Date: 12-3-2022 */

module jtroadf_main(
    input               rst,
    input               clk,        // 24 MHz
    input               cpu4_cen,   // 6 MHz
    output              cpu_cen,    // Q clock
    // ROM
    output      [15:0]  rom_addr,
    output reg          rom_cs,
    input       [ 7:0]  rom_data,
    input               rom_ok,

    // cabinet I/O
    input       [ 1:0]  start_button,
    input       [ 1:0]  coin_input,
    input       [ 5:0]  joystick1,
    input       [ 5:0]  joystick2,
    input               service,

    // GFX
    output              cpu_rnw,
    output      [ 7:0]  cpu_dout,
    output reg          vram_cs,
    output reg          objram_cs,
    output reg          obj_frame,

    // Sound
    output reg  [ 7:0]  snd_latch,
    output reg          snd_on,

    // configuration
    output reg  [ 2:0]  pal_sel,
    output reg          flip,

    // interrupt triggers
    input               LVBL,

    input      [7:0]    vram_dout,
    input      [7:0]    vscr_dout,  // output from Konami 085 custom chip
    input      [7:0]    obj_dout,
    // DIP switches
    input               dip_pause,
    input      [7:0]    dipsw_a,
    input      [7:0]    dipsw_b,
    input      [2:0]    dipsw_c // three jumpers at the board
);

reg  [ 7:0] cabinet, cpu_din;
wire [ 7:0] ram_dout;
wire [15:0] A;
wire        RnW, irq_n, nmi_n;
wire        irq_trigger;
reg         irq_clrn, ram_cs, snd_cs;
reg         ior_cs, in5_cs, intst_cs, intst_l,
            color_cs, iow_cs, intshow_cs;
// reg         afe_cs; // watchdog
wire        VMA;

assign irq_trigger = ~LVBL & dip_pause;
assign cpu_rnw     = RnW;
assign rom_addr    = A;

always @(*) begin
    // the ROM logic has some optional jumpers and the PCB we got
    // had G13 missing, apparently it was never there
    rom_cs  = VMA && A[15:13]>2 && RnW && VMA; // ROM = 4000 - FFFF
    iow_cs     = 0;
    in5_cs     = 0;
    intst_cs   = 0;
    ior_cs     = 0;
    color_cs   = 0;
    intshow_cs = 0;
    objram_cs  = 0;
    vram_cs    = 0;
    ram_cs     = 0;
    snd_cs     = 0;

    if( VMA ) begin
        if( A[15:13]==1 )
            case( A[12:11] ) // chip H13
                0: begin
                    // Half othe SCR RAM is repurposed as
                    // regular RAM in the original board, based
                    // on bit 5.
                    if( A[5] )
                        ram_cs = 1;
                    else
                        vram_cs = 1; // Divided down in two signals originally: V1_cs and V2_cs
                end
                2,3: ram_cs = 1; // 3 is the NVRAM (2kB)
            endcase
        if( A[15:13]==0 )
            case( A[12:10] ) // chip H14
                4: objram_cs = 1;
                5: case( A[9:7]) // chip H8
                    0: intst_cs= 1; // intst / afe, two signals on board B, the same signal on board A
                    1: iow_cs  = 1;
                    2: snd_cs  = 1;
                    4: in5_cs  = 1;
                    5: ior_cs  = 1;
                    default:;
                endcase
                default:;
            endcase
    end


    if( VMA && A[15:13]==1 ) begin // 2000-3FFF
        case( A[12:11] )
            0:  case( A[10:8] )  // 2000-27FF
                    0: iow_cs      = 1; // 2000
                    // 1: watchdog    // 2100
                    2: color_cs = 1;  // 2200
                    3: intshow_cs = 1;
                    4: begin
                        ior_cs = 1;    // 2400-2403
                        snd_cs = ~RnW;
                    end
                    5: { in6_cs, in5_cs } = { A[0], ~A[0] };
                    default:;
                endcase
            1: objram_cs = 1;   // 2800-2FFF
            2: ram_cs   = 1;    // 3800-3BFF    - part of VRAM chip
            3: vram_cs  = 1;    // 3C00-3FFF
        endcase
    end
end

always @(posedge clk) begin
    case( A[1:0] )
        0: cabinet <= { dipsw_c, start_button, service, coin_input };
        1: cabinet <= { 1'b1, joystick1[6:4], joystick1[2], joystick1[3], joystick1[0], joystick1[1]};
        2: cabinet <= { 1'b1, joystick2[6:4], joystick2[2], joystick2[3], joystick2[0], joystick2[1]};
        3: cabinet <= dipsw_a;
    endcase
    cpu_din <= rom_cs  ? rom_data  :
               vram_cs ? vram_dout :
               ram_cs  ? ram_dout  :
               intshow_cs ? vscr_dout :
               objram_cs  ? obj_dout :
               ior_cs  ? cabinet  :
               in5_cs  ? dipsw_b  : 8'hff;
end

always @(posedge clk) begin
    if( rst ) begin
        irq_clrn <= 0;
        flip     <= 0;
        snd_on   <= 0;
        pal_sel  <= 0;
        snd_latch<= 0;
        obj_frame<= 0;
        intst_l  <= 0;
    end else if(cpu_cen) begin
        intst_l <= intst_cs;
        if( intst_cs && !intst_l ) obj_frame <= ~obj_frame;
        if( iow_cs && !RnW ) begin
            case(A[2:0]) // 74LS259 @ F2
                0: flip      <= cpu_dout[0];
                1: snd_on    <= cpu_dout[0];
                // 2: END - this must be some test output
                // 3: coin 1 counter
                // 4: coin 2 counter
                // 5: SA ?
                // 6: unconnected
                7: irq_clrn  <= cpu_dout[0];
                default:;
            endcase
        end
        if( color_cs ) pal_sel <= cpu_dout[2:0];
        if( snd_cs   ) snd_latch <= cpu_dout;
    end
end

jtframe_ff u_irq(
    .rst      ( rst         ),
    .clk      ( clk         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( irq_n       ),
    .set      (             ),    // active high
    .clr      ( ~irq_clrn   ),    // active high
    .sigedge  ( irq_trigger )     // signal whose edge will trigger the FF
);

// 13 bits is a bit more than needed because
// half of the SCR RAM is embedded in sys6809
jtframe_sys6809 #(.RAM_AW(13)) u_cpu(
    .rstn       ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cpu4_cen  ),   // This is normally the input clock to the CPU
    .cpu_cen    ( cpu_cen   ),   // 1/4th of cen -> 3MHz

    // Interrupts
    .nIRQ       ( irq_n     ),
    .nFIRQ      ( 1'b1      ),
    .nNMI       ( 1'b1      ),
    .irq_ack    (           ),
    // Bus sharing
    .bus_busy   ( 1'b0      ),
    .waitn      (           ),
    // memory interface
    .A          ( A         ),
    .RnW        ( RnW       ),
    .VMA        ( VMA       ),
    .ram_cs     ( ram_cs    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    // Bus multiplexer is external
    .ram_dout   ( ram_dout  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_din    ( cpu_din   )
);

endmodule
