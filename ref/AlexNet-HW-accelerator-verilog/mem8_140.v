`timescale 1ns/10ps

module mem8_140(
	input clk,
	input [7:0] addr,
	input [7:0] data_in,
	output reg [7:0] data_out,
	input wr_en
);

reg [7:0] mem[0:139];

always@(posedge clk) begin
	if(wr_en) begin
        	mem[addr] <= data_in;
	end
       	data_out <= mem[addr];
end

endmodule
