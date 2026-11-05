`timescale 1ns/10ps

module mem88_11(
	input clk, 
	input [3:0] addr, 
	input [3:0] offset, 
	input [7:0] data_in, 
	output reg [87:0] data_out, 
	input wr_en
);
	reg [87:0] filter[0:10];	

        always@(posedge clk) begin
                if(wr_en) begin
                        filter[addr][(offset*8)+:8] <= data_in;
                end 
		data_out <= filter[addr];
        end

endmodule	
