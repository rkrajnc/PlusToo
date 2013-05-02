module videoShifter(
    input clk32,
	 input [1:0] clkPhase,
	 input [15:0] dataIn,
	 input loadPixels,
    output pixelOut
    );
	
	reg [15:0] shiftRegister;
	
	// a 0 bit is white, and a 1 bit is black
	// data is shifted out MSB first
	assign pixelOut = ~shiftRegister[15];
	
	always @(posedge clk32) begin
		// loadPixels is generated by a module running on the 8 MHz CPU clock. Therefore this module
		// only honors loadPixels when clkPhase is 1, indicating the last quarter of the 8 MHz clock cycle.
		if (loadPixels && clkPhase == 2'b01) begin
			shiftRegister <= dataIn;
		end
		else begin
			shiftRegister <= { shiftRegister[14:0], 1'b1 };
		end
	end
	
endmodule
