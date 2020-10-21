module qpi_sdram_adapter #(
	parameter integer AW = 23,
	parameter integer DW=32
)(

	// QPI memory interface
    input  wire qpi_do_read,
    input  wire qpi_do_write,
    input  wire [23:0] qpi_addr,
    output wire qpi_is_idle,

    input  wire [31:0] qpi_wdata,
    output wire [31:0] qpi_rdata,
    output wire qpi_next_word,

	// // Wishbone interface for CSRs
	// input  wire [ 3:0] bus_addr,
	// input  wire [31:0] bus_wdata,
	// output reg  [31:0] bus_rdata,
	// input  wire bus_cyc,
	// output wire bus_ack,
	// input  wire bus_we,

	// Wishbone interface for sdram controller

	input i_wb_cyc,
	input i_wb_stb,
	input i_wb_we,
	input [(AW-1):0] i_wb_addr,
	
	input [(DW/8-1):0] i_wb_sel,
	output o_wb_ack,
	output o_wb_stall,
	inout [(DW-1):0] wb_data,

	// Clock
	input  wire clk,
	input  wire clk_sdram,
	input  wire rst
);

	// Wishbone
	//	inputs
	input	wire			i_wb_cyc, i_wb_stb, i_wb_we;
	input	wire	[(AW-1):0]	i_wb_addr;
	input	wire	[(DW-1):0]	i_wb_data;
	input	wire	[(DW/8-1):0]	i_wb_sel;
	//	outputs
	output	wire		o_wb_ack;
	output	reg		o_wb_stall;
	output	wire [31:0]	o_wb_data;

endmodule