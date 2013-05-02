module romAdapter(
	 // CPU interface
	 input clk8,
    input [20:0] addr, // word address
	 output [15:0] dataOut,
    input _OE,
    input _CS,
    input _UDS,
    input _LDS,
	 
	 input extraRomRead,
	 input A0,
	 
	 // external interface to 8-bit Flash
	 output [21:0] flashAddr, // byte address
	 input [7:0] flashData,
	 output _flashCE,
	 output _flashOE
);

	/* The 68000 CPU latches data on the negative clock edge. At 8.125 MHz, if the address
		is presented at the positive clock edge, that leaves 61.5 ns until the negative edge.
		The S29AL032D70 Flash ROM has an address-to-output delay of 70 ns, so that won't work.
		
		This adapter changes the LSB of the address at the negative clock edge, which provides
		a full clock cycle (123 ns) until the data is latched.
		
		This technique relies on the video module releasing the bus after at most 1.5 clocks
		of the 4 clock bus cycle. Otherwise not enough time will have elapsed since the higher 
		order address bits changed from video to CPU address before the data is latched. 
	*/
	
	// read the low and high byte on alternating clock cycles
	reg hiByte;
	always @(negedge clk8) begin
		hiByte <= ~hiByte;
	end	
	
	// Byte to word address mapping: 68000 defines the "upper byte" as the one with the even address,
	// so we provide an address ending in zero to get the high byte. 
	assign flashAddr = { addr, extraRomRead ? A0 : ~hiByte };
	
	reg [15:0] word;
	always @(negedge clk8) begin
		if (hiByte)
			word[15:8] <= flashData;
		else
			word[7:0] <= flashData;
	end
	
	wire [15:0] flashWord;
	assign flashWord = extraRomRead ? { 8'h00, flashData } :
							 hiByte ? { flashData, word[7:0] } : { word[15:8], flashData };
	
	assign dataOut[15:8] = _UDS == 1'b0 ? flashWord[15:8] : 8'hBE;
	assign dataOut[7:0] = _LDS == 1'b0 ? flashWord[7:0] : 8'hEF;
	
	assign _flashCE = _CS;
	assign _flashOE = _OE;
endmodule
