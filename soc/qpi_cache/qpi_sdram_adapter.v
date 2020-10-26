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
    output reg [31:0] qpi_rdata,
    output reg qpi_next_word,

	// // Wishbone interface for CSRs
	// input  wire [ 3:0] bus_addr,
	// input  wire [31:0] bus_wdata,
	// output reg  [31:0] bus_rdata,
	// input  wire bus_cyc,
	// output wire bus_ack,
	// input  wire bus_we,

	// Wishbone master for sdram controller
	output reg o_wb_cyc,
	output reg o_wb_stb,
	output reg o_wb_we,
	output reg [(AW-1):0] o_wb_addr,
	
	output reg [(DW/8-1):0] o_wb_sel,
	input i_wb_ack,
	input i_wb_stall,
	input [(DW-1):0] i_wb_data,
	output reg [(DW-1):0] o_wb_data,

	// Clock
	input  wire clk,
	input  wire rst
);

	localparam
		ST_IDLE = 0,
		ST_WAIT_STALL = 1,
		ST_WAIT_ACK = 2,
		ST_END_WB = 3;

	assign qpi_is_idle = (state == ST_IDLE) && !qpi_do_read && !qpi_do_write;
	assign o_wb_sel = {(DW/8) {1'b1}};

	// Main Control FSM
	reg  [ 3:0] state;
	reg  [ 3:0] state_nxt;

	assign o_wb_cyc = (state != ST_IDLE);
	assign qpi_rdata = i_wb_data;
	assign o_wb_data = qpi_wdata;

	// State register
	always @(posedge clk)
		if (rst) begin
			state <= ST_IDLE;
			o_wb_stb <= 1'b0;
			o_wb_we <= 1'b0;
			o_wb_addr <= {AW{1'b0}};
			qpi_next_word <= 0;
		end else begin
			state <= state_nxt;

			case (state_nxt)
				ST_IDLE: begin
					o_wb_stb <= 1'b0;
					o_wb_we <= 1'b0;
					o_wb_addr <= {AW{1'b0}};
					qpi_next_word <= 0;
				end
				ST_WAIT_STALL: begin
					qpi_next_word <= 1'b0;
					o_wb_stb <= 1'b1;
					o_wb_addr <= qpi_addr;
					o_wb_we <= qpi_do_write;
				end
				ST_WAIT_ACK: begin
					o_wb_stb <= 1'b1;
					o_wb_addr <= qpi_addr;
					o_wb_we <= qpi_do_write;
					qpi_next_word <= i_wb_ack;
				end
				ST_END_WB: begin
					o_wb_stb <= 1'b0;
					o_wb_addr <= qpi_addr;
					o_wb_we <= qpi_do_write;
					qpi_next_word <= 1'b1;
				end
			endcase
		end

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
						state_nxt = ST_WAIT_ACK;
					end else begin
						state_nxt = ST_WAIT_STALL;
					end

			ST_WAIT_STALL:
				if (~i_wb_stall) begin
					state_nxt = ST_WAIT_ACK;
				end

			ST_WAIT_ACK:
				if (i_wb_ack) begin
					state_nxt = ST_END_WB;
				end
			ST_END_WB:
				if (~qpi_do_read & ~qpi_do_write) begin
					state_nxt = ST_IDLE;
				end else if (~i_wb_stall) begin
					state_nxt = ST_WAIT_ACK;
				end else begin
					state_nxt = ST_WAIT_STALL;
				end
		endcase
	end

endmodule
