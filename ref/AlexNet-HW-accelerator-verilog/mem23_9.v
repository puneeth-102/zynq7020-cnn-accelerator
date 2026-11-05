`timescale 1ns/10ps

module mem23_9(
        input clk,
        input [3:0] addr,
        input [22:0] data_in,
        output reg [22:0] data_out,
        input wr_en
);

reg [22:0] mem[0:8];

always@(posedge clk) begin
        if(wr_en) begin
                mem[addr] <= data_in;
        end
        
        data_out <= mem[addr];
end

endmodule

