// https://electrobinary.blogspot.com/2020/08/booth-multiplier-verilog-code.html

module booth2(clk,rst,start,X,Y,valid,Z);

input clk;
input rst;
input start;
input signed [31:0]X,Y;
output signed [63:0]Z;
output valid;

reg signed [63:0] Z,next_Z,Z_temp;
reg next_state, pres_state;
reg [1:0] temp,next_temp;
reg [5:0] count,next_count;
reg valid, next_valid;

parameter IDLE = 1'b0;
parameter START = 1'b1;

always @ (posedge clk or negedge rst)
begin
if(!rst)
begin
  Z          <= 0;
  valid      <= 0;
  pres_state <= 0;
  temp       <= 0;
  count      <= 0;
end
else
begin
  Z          <= next_Z;
  valid      <= next_valid;
  pres_state <= next_state;
  temp       <= next_temp;
  count      <= next_count;
end
end

always @ (*)
begin 
case(pres_state)
IDLE:
begin
next_count = 0;
next_valid = 0;
if(start)
begin
    next_state = START;
    next_temp  = {X[0],1'b0};
    next_Z     = {32'd0,X};
end
else
begin
    next_state = pres_state;
    next_temp  = 0;
    next_Z     = 0;
end
end

START:
begin

	/*
	 * 	Not using default will indcate to quartus to infer muxes rather than equal + selectors.
	 * 	This lead to a gain of frequency of about 35 MHz.
	 */
    case(temp)
	 2'b00: 	 Z_temp = {Z[63:32],Z[31:0]};	
    2'b10:   Z_temp = {Z[63:32]-Y,Z[31:0]};
    2'b01:   Z_temp = {Z[63:32]+Y,Z[31:0]};
	 2'b11: 	 Z_temp = {Z[63:32],Z[31:0]};
endcase
	 
next_temp  = {X[count+1],X[count]};
next_count = count + 1;
next_Z     = Z_temp >>> 1;
next_valid = (&count) ? 1'b1 : 1'b0; 
next_state = (&count) ? IDLE : pres_state;	
end
endcase
end
endmodule