`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module gpmc
  (// GPMC signals
   input EM_CLK, inout [15:0] EM_D, input [10:1] EM_A, input [1:0] EM_NBE,
   input EM_WAIT0, input EM_NCS4, input EM_NCS6, input EM_NWE, input EM_NOE,

   // Wishbone signals
   input wb_clk, input wb_rst,
   output reg [10:0] wb_adr_o, output reg [15:0] wb_dat_mosi, input [15:0] wb_dat_miso,
   output reg [1:0] wb_sel_o, output wb_cyc_o, output reg wb_stb_o, output reg wb_we_o, input wb_ack_i,

   // RAM Interface signals
   input ram_clk, 
   input read_en, input read_sel, input [8:0] read_addr, output [31:0] read_data, output read_rdy,
   input write_en, input write_sel, input [8:0] write_addr, input [31:0] write_data, output write_rdy
   );

   wire 	EM_output_enable = (~EM_NOE & (~EM_NCS4 | ~EM_NCS6));
   wire [15:0] 	EM_D_ram;
   wire [15:0] 	EM_D_wb;

   assign EM_D = ~EM_output_enable ? 16'bz : ~EM_NCS4 ? EM_D_ram : EM_D_wb;

   // CS4 is RAM_2PORT for high-speed data
   // Writes go into one RAM, reads come from the other
   
   ram_2port_mixed_width buffer_from_host
     (.clk16(wb_clk), .en16(~EM_NCS4), .we16(~EM_NWE), .addr16({store_pg,EM_A}), .di16(EM_D), .do16(),
      .clk32(ram_clk), .en32(read_en), .we32(0), .addr32({read_sel,read_addr}), .di32(0), .do32(read_data));

   ram_2port_mixed_width buffer_to_host
     (.clk16(wb_clk), .en16(~EM_NCS4), .we16(0), .addr16({retr_page,EM_A}), .di16(0), .do16(EM_D_ram),
      .clk32(ram_clk), .en32(write_en), .we32(write_en), .addr32({write_sel,write_addr}), .di32(write_data), .do32());

   // CS6 is Control, Wishbone bus bridge (wb master)
   // Sync version
   reg [1:0] 	cs_del, we_del, oe_del;

   // Synchronize the async control signals
   always @(posedge wb_clk)
     begin
	cs_del <= { cs_del[0], EM_NCS6 };
	we_del <= { we_del[0], EM_NWE };
	oe_del <= { oe_del[0], EM_NOE };
     end

   always @(posedge wb_clk)
     if(cs_del == 2'b10)  // Falling Edge
       wb_adr_o <= { EM_A, 1'b0 };

   always @(posedge wb_clk)
     if(we_del == 2'b10)  // Falling Edge
       begin
	  wb_dat_mosi <= EM_D;
	  wb_sel_o <= ~EM_NBE;
       end

   reg [15:0] EM_D_wb_reg;
   always @(posedge wb_clk)
     if(wb_ack_i)
       EM_D_wb_reg <= wb_dat_miso;

   assign EM_D_wb = wb_ack_i ? wb_dat_miso : EM_D_wb_reg;
   
   assign wb_cyc_o = wb_stb_o;

   always @(posedge wb_clk)
     if( ~cs_del[0] & (we_del == 2'b10) )
       wb_we_o <= 1;
     else if(wb_ack_i)  // Turn off we when done.  Could also use we_del[0], others...
       wb_we_o <= 0;

   always @(posedge wb_clk)
     if( ~cs_del[0] & ((we_del == 2'b10) | (oe_del == 2'b10)))
       wb_stb_o <= 1;
     else if(wb_ack_i)
       wb_stb_o <= 0;
   
endmodule // gpmc
