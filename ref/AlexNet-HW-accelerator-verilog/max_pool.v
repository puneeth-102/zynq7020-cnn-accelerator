`timescale 1ns/10ps

module max_pool(
	clk,
	en,
	num1,
	num2,
	num3,
	num4,
	num5,
	num6,
	num7,
	num8,
	num9,
	write_ready,
	out
);

input clk, en;
input [22:0] num1, num2, num3, num4, num5, num6, num7, num8, num9;
output reg [22:0] out;
output reg write_ready;

reg [22:0] num1_r, num2_r, num3_r, num4_r, num5_r, num6_r, num7_r, num8_r, num9_r;
reg [22:0] max_value;
reg start;

always@(posedge clk) begin
	if(en) begin
		num1_r <= num1;
		num2_r <= num2;
		num3_r <= num3;
		num4_r <= num4;
		num5_r <= num5;
		num6_r <= num6;
		num7_r <= num7;
		num8_r <= num8;
		num9_r <= num9;
		start <= 1'b1;
	end
	if(start) begin
		max_value = num1_r;
		if (num2_r > max_value) max_value = num2_r;
		if (num3_r > max_value) max_value = num3_r;
		if (num4_r > max_value) max_value = num4_r;
		if (num5_r > max_value) max_value = num5_r;
		if (num6_r > max_value) max_value = num6_r;
		if (num7_r > max_value) max_value = num7_r;
		if (num8_r > max_value) max_value = num8_r;
		if (num9_r > max_value) max_value = num9_r;
		out <= max_value;
		write_ready <= 1'b1;	
		start <= 1'b0;
	end
	else begin
		write_ready <= 1'b0;
	end
end

endmodule










