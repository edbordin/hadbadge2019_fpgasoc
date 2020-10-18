module qpi_sdram_adapter (

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

	// Clock
	input  wire clk,
	input  wire rst
);

endmodule