// 滑窗法，滑窗读取数据
// 用于给卷积模块提供输入数据
module window   
(
    input  clk,
    input  rstn,
    input  start,       // 开始标志
    input  state,                   
    input  [7:0]  din,  
    output [39:0] taps  // 一列数据 taps的长度是40位是因为它拼接了5个8位的数据。它的作用是在滑窗操作中为卷积模块提供5个连续行的像素数据，用于卷积操作
);
           
	integer i;
	reg [7:0] mem [0:139];
	
	// 串行存储140（28*5）个输入数据
	always@(posedge clk)begin
		if(start)
			begin
				mem[0] <= din;           
				for(i=0;i<139;i=i+1) 
					mem[i+1] <= mem[i];
			end
	end
	// state=0:28*28   state=1:12*12
	// 139,111 83 55 27: interval 28; 59,47,35,23,11: interval 12
	assign taps = (!state)?{mem[139],mem[111],mem[83],mem[55],mem[27]}:{mem[59],mem[47],mem[35],mem[23],mem[11]};

endmodule



