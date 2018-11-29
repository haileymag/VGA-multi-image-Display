`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/23/2018 11:02:03 PM
// Design Name: 
// Module Name: top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module top(
    input wire [1:0] Sel,  // Selects for the output image
    input wire CLK,             // board clock: 100 MHz on Arty/Basys3/Nexys
    input wire RST_BTN,         // reset button
    output wire VGA_HS_O,       // horizontal sync output
    output wire VGA_VS_O,       // vertical sync output
    output reg [3:0] VGA_R,     // 4-bit VGA red output
    output reg [3:0] VGA_G,     // 4-bit VGA green output
    output reg [3:0] VGA_B      // 4-bit VGA blue output
    );

    //wire rst = ~RST_BTN;    // reset is active low on Arty & Nexys Video
     wire rst = RST_BTN;  // reset is active high on Basys3 (BTNC)

    // generate a 25 MHz pixel strobe
    reg [15:0] cnt;
    reg pix_stb;
    always @(posedge CLK)
        {pix_stb, cnt} <= cnt + 16'h4000;  // divide by 4: (2^16)/4 = 0x4000

    wire [9:0] x;  // current pixel x position: 10-bit value: 0-1023
    wire [8:0] y;  // current pixel y position:  9-bit value: 0-511
    wire active;   // high during active pixel drawing

    vga640x360 display (
        .i_clk(CLK), 
        .i_pix_stb(pix_stb),
        .i_rst(rst),
        .o_hs(VGA_HS_O), 
        .o_vs(VGA_VS_O), 
        .o_x(x), 
        .o_y(y),
        .o_active(active)
    );

    // VRAM frame buffers (read-write)
    localparam SCREEN_WIDTH = 640;
    localparam SCREEN_HEIGHT = 360;
    localparam VRAM_DEPTH = SCREEN_WIDTH * SCREEN_HEIGHT; 
    localparam VRAM_A_WIDTH = 18;  // 2^18 > 640 x 360
    localparam VRAM_D_WIDTH = 6;   // colour bits per pixel

    // 3 wires go into mux  
    // 1 image outputted at a time
    reg [VRAM_A_WIDTH-1:0] address;
    wire [VRAM_D_WIDTH-1:0] dataout4;
    wire [VRAM_D_WIDTH-1:0] dataout3; //recovered
    wire [VRAM_D_WIDTH-1:0] dataout2; //chaos
    wire [VRAM_D_WIDTH-1:0] dataout1; //Original

    sram #(
        .ADDR_WIDTH(VRAM_A_WIDTH), 
        .DATA_WIDTH(VRAM_D_WIDTH), 
        .DEPTH(VRAM_DEPTH), 
        .MEMFILE("Yoshi1.mem"))  // bitmap to load
        vram (
        .i_addr(address), 
        .i_clk(CLK), 
        .i_write(0),  // we're always reading
        .i_data(0), 
        .o_data(dataout1)
    );
    
    Encrypter encrpt(
        .i_addr(address), 
        .i_clk(CLK), 
        .i_write(0),  // we're always reading
        .i_data(dataout1), 
        .o_data(dataout2)
    );
    
    sram #(
            .ADDR_WIDTH(VRAM_A_WIDTH), 
            .DATA_WIDTH(VRAM_D_WIDTH), 
            .DEPTH(VRAM_DEPTH), 
            .MEMFILE("scan1.mem"))  // bitmap to load
            vram2 (
            .i_addr(address), 
            .i_clk(CLK), 
            .i_write(0),  // we're always reading
            .i_data(0), 
            .o_data(dataout4)
        );
    
    sram #(
        .ADDR_WIDTH(VRAM_A_WIDTH), 
        .DATA_WIDTH(VRAM_D_WIDTH), 
        .DEPTH(VRAM_DEPTH), 
        .MEMFILE("Yoshi1.mem"))  // bitmap to load
        vram3 (
        .i_addr(address), 
        .i_clk(CLK), 
        .i_write(0),  // we're always reading
        .i_data(0), 
        .o_data(dataout3)
    );
        
    reg [11:0] palette1 [0:63];  // 64 x 12-bit colour palette entries
	reg [11:0] palette2 [0:63];
 	reg [11:0] palette3 [0:63];
	reg [11:0] colour;
    
    always@(posedge CLK) begin
        address <= y * SCREEN_WIDTH + x;
        if(active) // pixel drawing time
            case(Sel)
                2'b00: begin
                        
                        $display("Loading palette1.");
                        $readmemh("Yoshi1_palette.mem", palette1);  // bitmap palette to load
                        colour <= palette1[dataout1];
                       end
                2'b01: begin
                        $display("Loading palette.");
                        $readmemh("Yoshi1_palette.mem", palette2);  // bitmap palette to load
                        colour <= palette2[dataout2];
                       end
                2'b10: begin
                        $display("Loading palette3.");
                        $readmemh("scan1_palette.mem", palette3);
                        colour <= palette3[dataout3];
                       end
                2'b11:begin 
                        $display("Loading palette3.");
                        $readmemh("scan1_palette.mem", palette3);
                        colour <= palette3[dataout4];
                      end
                
                
                
                
                default: begin;
                        $display("Loading palette1.");
                        $readmemh("Yoshi1_palette.mem", palette2);  // bitmap palette to load
                        colour <= palette2[dataout2];
                       end
            endcase
        else
            colour <= 0;
            VGA_R <= colour[11:8];  // values for RGB are described by the color palettes being processed
            VGA_G <= colour[7:4];
            VGA_B <= colour[3:0];
    end
endmodule