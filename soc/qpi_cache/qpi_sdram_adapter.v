module qpi_sdram_adapter #(
	parameter integer AW = 23,
	parameter integer DW = 32
)(

	// QPI memory interface
    input  wire qpi_do_read,
    input  wire qpi_do_write,
    input  wire [24:0] qpi_addr,
    output wire qpi_is_idle,

    input  wire [31:0] qpi_wdata,
    output wire [31:0] qpi_rdata,
    output qpi_next_word,

	// // Wishbone interface for CSRs
	// input  wire [ 3:0] bus_addr,
	// input  wire [31:0] bus_wdata,
	// output reg  [31:0] bus_rdata,
	// input  wire bus_cyc,
	// output wire bus_ack,
	// input  wire bus_we,

	// Wishbone master for sdram controller
	output o_wb_cyc,
	output o_wb_stb,
	output o_wb_we,
	output [(AW-1):0] o_wb_addr,
	
	output [(DW/8-1):0] o_wb_sel,
	input i_wb_ack,
	input i_wb_stall,
	input [(DW-1):0] i_wb_data,
	output [(DW-1):0] o_wb_data,

	// Clock
	input  wire clk,
	input  wire clk_sdram,
	input  wire rst
);

	localparam
		ST_IDLE = 0,
		ST_WAIT_STALL = 1,
		ST_BEGIN_TXN = 2,
		ST_WAIT_ACK = 3;

	assign qpi_is_idle = (state == ST_IDLE) && !qpi_do_read && !qpi_do_write;
	assign qpi_next_word = (state == ST_IDLE);

	// Main Control FSM
	reg  [ 3:0] state;
	reg  [ 3:0] state_nxt;

	// State register
	always @(posedge clk)
		if (rst)
			state <= ST_IDLE;
		else
			state <= state_nxt;

	// Next-State logic
	always @(*)
	begin
		// Default is to stay put
		state_nxt = state;

		// Transition?
		case (state)
			ST_IDLE:
				if (qpi_do_read | qpi_do_write)
					if (~i_wb_stall) begin
						state_nxt = ST_BEGIN_TXN;
					end else begin
						state_nxt = ST_WAIT_STALL;
					end


			ST_BEGIN_TXN:
				if (~i_wb_stall) begin
					state_nxt = ST_WAIT_ACK;


				end

			ST_WAIT_ACK:
				if (i_wb_ack)
					state_nxt = ST_IDLE;
		endcase
	end

endmodule
