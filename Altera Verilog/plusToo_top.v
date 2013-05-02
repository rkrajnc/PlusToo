module plusToo_top(
    input clk50,
	 input [9:0] sw, 
	 input [3:0] key,
    output hsync,
    output vsync,
    output [3:0] red,
    output [3:0] green,
    output [3:0] blue,
	 output [6:0] hex0,
	 output [6:0] hex1,
	 output [6:0] hex2,
	 output [6:0] hex3,
	 output [7:0] ledg,
	 output [9:0] ledr,
	 output [21:0] flashAddr,
	 input [7:0] flashData,
	 output _flashCE,
	 output _flashOE,
	 output _flashWE,
	 output [17:0] sramAddr,
	 inout [15:0] sramData,
	 output _sramCE,
	 output _sramOE,
	 output _sramWE,
	 output _sramUDS,
	 output _sramLDS,
	 inout mouseClk,
	 inout mouseData
 );

	// NO REAL LOGIC SHOULD GO IN THIS MODULE!
	// It may not exist in the hand-built Plus Too.
	// Only interconnections and interfaces specific to the dev board should go here
	
	// synthesize a 32.5 MHz clock
	wire clk32; 
	clock325MHz cs0(.inclk0(clk50), .c0(clk32));
	
	// set the real-world inputs to sane defaults
	localparam keyClk = 1'b0,
				  keyData = 1'b0,
				  serialIn = 1'b0,
				  interruptButton = 1'b0,
				  configROMSize = 1'b1, // 128K ROM
				  configRAMSize = 2'b01; // 512K RAM
				  
	// interconnects
	// CPU
	wire clk8, _cpuReset, _cpuAS, _cpuUDS, _cpuLDS, _cpuRW, _cpuDTACK, cpuDriveData;
	wire [2:0] _cpuIPL;
	wire [7:0] cpuAddrHi;
	wire [23:0] cpuAddr;
	wire [15:0] cpuDataOut;
	
	// RAM/ROM
	wire _romCS, _romOE;
	wire _ramCS, _ramOE, _ramWE;
	wire _memoryUDS, _memoryLDS;
	wire videoBusControl;
	wire [21:0] memoryAddr;
	wire [15:0] memoryDataOut;
	wire memoryDriveData;
	wire [15:0] memoryDataInMux;
	wire [15:0] ramDataOut;
	wire [15:0] romDataOut;
	
	// peripherals
	wire loadSound, loadNormalPixels, loadDebugPixels, pixelOut, _hblank, _vblank;
	wire memoryOverlayOn, selectSCC, selectIWM, selectVIA, selectInterruptVectors;	 
	wire [15:0] dataControllerDataOut;
	wire dataControllerDriveData;
	
	// debug panel
	wire _debugDTACK, driveDebugData, loadPixels, extraRomReadAck;
	wire [15:0] debugDataOut;
	wire [21:0] extraRomReadAddr;
	
	// LED debug lights
	assign ledg = { 2'b00, diskInDrive[1], diskInDrive[1], diskInDrive[0], diskInDrive[0], 2'b00 };
	assign ledr = 10'h000;
	
	// convert 1-bit pixel data to 4:4:4 RGB
	// force pixels in debug area to appear green
	assign red[3:0] = _vblank == 1'b0 ? 4'h0 : { pixelOut, pixelOut, pixelOut, pixelOut };
	assign green[3:0] = { pixelOut, pixelOut, pixelOut, pixelOut };
	assign blue[3:0] = _vblank == 1'b0 ? 4'h0 : { pixelOut, pixelOut, pixelOut, pixelOut };
	
	// memory-side data input mux
	// In a hand-built system, both RAM and ROM data will be on the same physical pins,
	// making this mux unnecessary
	assign memoryDataInMux = driveDebugData ? debugDataOut :
									_ramOE == 1'b0 ? ramDataOut : 
									romDataOut;
	
	debugPanel dp(
		.clk8(clk8),
		.sw(sw),
		.key(key),
		.videoBusControl(videoBusControl),
		.loadNormalPixels(loadNormalPixels),
		.loadDebugPixels(loadDebugPixels),
		.loadPixelsOut(loadPixels),
		._dtackIn(_cpuDTACK),
		.cpuAddrHi(cpuAddrHi),
		.cpuAddr(cpuAddr),
		._cpuRW(_cpuRW),
		._cpuUDS(_cpuUDS),
		._cpuLDS(_cpuLDS),
		.dataControllerDataOut(dataControllerDataOut),
		.cpuDataOut(cpuDataOut),
		.memoryAddr(memoryAddr),
		._dtackOut(_debugDTACK),
		.hex0(hex0),
		.hex1(hex1),
		.hex2(hex2),
		.hex3(hex3),
		.driveDebugData(driveDebugData),
		.debugDataOut(debugDataOut),
		.extraRomReadAck(extraRomReadAck));
	
	wire [2:0] _debugIPL = sw[0] == 1'b1 ? 3'b111 : _cpuIPL; // suppress interrupts when sw0 on	
	
	TG68 m68k(
		.clk(clk8), 
		.reset(_cpuReset), 
		.clkena_in(1'b1),
		.data_in(dataControllerDataOut), 
		.IPL(_debugIPL), 
		.dtack(_debugDTACK), 
		.addr({cpuAddrHi, cpuAddr}), 
		.data_out(cpuDataOut), 
		.as(_cpuAS), 
		.uds(_cpuUDS), 
		.lds(_cpuLDS), 
		.rw(_cpuRW), 
		.drive_data(cpuDriveData)); 
	
	addrController_top ac0(
		.clk8(clk8), 
		.cpuAddr(cpuAddr), 
		._cpuAS(_cpuAS), 
		._cpuUDS(_cpuUDS),
		._cpuLDS(_cpuLDS),
		._cpuRW(_cpuRW), 
		._cpuDTACK(_cpuDTACK), 
		.configROMSize(configROMSize), 
		.configRAMSize(configRAMSize), 
		.memoryAddr(memoryAddr),			
		._memoryUDS(_memoryUDS),
		._memoryLDS(_memoryLDS),
		._romCS(_romCS),
		._romOE(_romOE), 
		._ramCS(_ramCS), 
		._ramOE(_ramOE), 
		._ramWE(_ramWE),
		.videoBusControl(videoBusControl),	
		.selectSCC(selectSCC),
		.selectIWM(selectIWM),
		.selectVIA(selectVIA),
		.selectInterruptVectors(selectInterruptVectors),
		.hsync(hsync), 
		.vsync(vsync),
		._hblank(_hblank),
		._vblank(_vblank),
		.loadNormalPixels(loadNormalPixels),
		.loadDebugPixels(loadDebugPixels),
		.loadSound(loadSound), 
		.memoryOverlayOn(memoryOverlayOn),
		
		.extraRomReadAddr(extraRomReadAddr),
		.extraRomReadAck(extraRomReadAck));
	
	wire [1:0] diskInDrive;
	
	dataController_top dc0(
		.clk32(clk32), 
		.clk8out(clk8),
		.clk8(clk8),  
		._systemReset(key[1]|key[0]), 
		._cpuReset(_cpuReset), 
		._cpuIPL(_cpuIPL),
		._cpuUDS(_cpuUDS), 
		._cpuLDS(_cpuLDS), 
		._cpuRW(_cpuRW), 
		.cpuDataIn(cpuDataOut),
		.cpuDataOut(dataControllerDataOut), 	
		.cpuDriveData(dataControllerDriveData),
		.cpuAddrRegHi(cpuAddr[12:9]),
		.cpuAddrRegLo(cpuAddr[2:1]),		
		.selectSCC(selectSCC),
		.selectIWM(selectIWM),
		.selectVIA(selectVIA),
		.selectInterruptVectors(selectInterruptVectors),
		.videoBusControl(videoBusControl),
		.memoryDataOut(memoryDataOut),
		.memoryDataIn(memoryDataInMux),
		.memoryDriveData(memoryDriveData),
		.keyClk(keyClk), 
		.keyData(keyData), 
		.mouseClk(mouseClk),
		.mouseData(mouseData),
		.serialIn(serialIn), 
		._hblank(_hblank),
		._vblank(_vblank), 
		.pixelOut(pixelOut), 
		.loadPixels(loadPixels), 
		.loadSound(loadSound),
		.interruptButton(1'b1), 
		.memoryOverlayOn(memoryOverlayOn),
		.insertDisk({ sw[0] == 1'b0 && key[2] == 1'b0, sw[0] == 1'b0 && key[1] == 1'b0 }),
		.diskInDrive(diskInDrive),
		
		.extraRomReadAddr(extraRomReadAddr),
		.extraRomReadAck(extraRomReadAck));
	
	assign sramAddr = memoryAddr[18:1];
	assign sramData = memoryDriveData == 1'b1 ? memoryDataOut : 16'hZZZZ;
	assign ramDataOut = sramData;
	assign _sramCE = _ramCS;
	assign _sramOE = _ramOE;
	assign _sramWE = _ramWE;
	assign _sramUDS = _memoryUDS;
	assign _sramLDS = _memoryLDS;
	
	romAdapter rom(
		.clk8(clk8),
		.addr(memoryAddr[21:1]),
		.dataOut(romDataOut),
		._OE(_romOE),
		._CS(_romCS),
		._UDS(_memoryUDS), 
		._LDS(_memoryLDS),
		
		.extraRomRead(extraRomReadAck),
		.A0(memoryAddr[0]),
	 
		.flashAddr(flashAddr),
		.flashData(flashData),
		._flashCE(_flashCE),
		._flashOE(_flashOE));
	
	assign _flashWE = 1'b1;

endmodule
