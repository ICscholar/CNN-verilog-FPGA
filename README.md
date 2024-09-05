## Statement:
### Most of the code and associated materials are referenced from https://github.com/JiachengCao/cnn_accelerator. This project is a detailed annotated version of the code.The annotations were independently added by me to enhance clarity based on my understanding of the code and algorithms.
#### 本代码及其配套内容大部分参考了 https://github.com/JiachengCao/cnn_accelerator，本工程为代码详细注释版本。注释部分由我根据对代码和算法的理解自行添加，以提高其清晰度。

项目实现了使用纯verilog语法实现LeNet-5（简单CNN网络）结构进行手写数字识别并进行仿真，采用八位无符号数量化。  

输入图片（28x28）-> 卷积 (2x2x6) -> 24x24x6 feature map -> 激活（relu）-> maxpooling(2x2) -> 12x12x6 feature map -> 卷积 (2x2x12) -> 8x8x12 feature map -> maxpooling(2x2) -> 4x4x12 feature map
-> 192 fully connect -> 10 output 

The project implemented handwritten digit recognition and simulation using a pure Verilog syntax to construct the LeNet-5 architecture (a simple CNN network), with 8-bit unsigned quantization.  

input figure（28x28）-> conv (2x2x6) -> 24x24x6 feature map -> activation（relu）-> maxpooling(2x2) -> 12x12x6 feature map -> conv (2x2x12) -> 8x8x12 feature map -> maxpooling(2x2) -> 4x4x12 feature map
-> 192 fully connect -> 10 output 

### 卷积部分代码'conv.v'周期数据解释
	always@(posedge clk)
	begin
		if(!start)
			sum_valid<=1'b0;
		else
			case(state)
			// 输入图像 Size 为 28*28
			1'b0:if(cnt1==10'd829 - 2'd1)      // 到 829 才完成所有窗口的卷积计算
					sum_valid <= 1'b0;
				else if(cnt1 == (8'd161 - 2'd1)) // 150 + 4 + 7 ,提前一拍进行同步（因为cnt1从0开始计数）
					//understanding of 150: 5*5*6 FIFOs, windows数据加载为140个周期，因此需要150个达到同步
					// 4: loading data into window, 4 time cycle
					// 7 seven stages of calculation of one conv manipulation
					// understanding of 829: 161+24*24+23*4, 
					// where 23:纵向剩余的23行加载所需要的时钟周期,4 是用来同步窗口， 24*24为实际需要的数据输出量
					sum_valid <= 1'b1;  // 此时的计算结果才有效
			// 输入图像 Size 为 12*12		
			1'b1:if(cnt1==10'd255)
					sum_valid <= 1'b0;   
				else if(cnt1==8'd163)
					sum_valid <= 1'b1;    
			endcase
	end

### max_pooling part:
	// 两行对应索引数据对比，缓存较大值
	//由于池化窗口为2*2，因此缓存一行且输入第二行才可以进行计算、比较。不同行相同索引的像素值比较大小存入较大的数值存入reg0 or reg1，且reg0 or 1 是以0，1，0，1，...交替进行的
	always@(posedge clk)
	begin
		case({state,cnt}) // 这里的 cnt是触发时的值，而不是计算后的值
		2'b00:begin
			if(ptr >= 7'd24)
			begin
				//对于data_reg_0 要么存上一行 要么存下一行
				if(din>data[ptr-7'd24])
					data_reg_0 <= din;
				else
					data_reg_0 <= data[ptr-7'd24];
			end
			else
				data_reg_0 <= 0;
			end
		2'b01:begin
			if(ptr >= 7'd24)
			begin
				//对于data_reg_1 要么存上一行 要么存下一行
				if(din>data[ptr-7'd24])
					data_reg_1 <= din;
				else
					data_reg_1 <= data[ptr-7'd24];
			end
			else
				data_reg_1 <= 0;
			end
		2'b10:begin
			if(ptr >= 7'd9)
			begin
				if(din>data[ptr-7'd9])
					data_reg_0 <= din;
				else
					data_reg_0 <= data[ptr-7'd9];
			end
			else
				data_reg_0 <= 0;
			end
		2'b11:begin
			if(ptr >= 7'd9)
			begin
				if(din>data[ptr-7'd9])
					data_reg_1 <= din;
				else
					data_reg_1 <= data[ptr-7'd9];
			end
			else
				data_reg_1 <= 0;
			end 
		default:begin
				data_reg_1 <= 0; 
				data_reg_0 <= 0;
				end         
		endcase
	end
 #### 延时锁存器(边沿检测器)
 	// 打拍采沿
	reg cnt_d;
	always@(posedge clk)begin
		if(!rstn)
			cnt_d <= 0;
		else
			cnt_d <= cnt;
	end
	
	// cnt 为 1时，输出才是有效的，即 2*2 的kernel， cnt=1含义为第二行且为偶数位索引（从1计数）
	// 筛选输出数据
	assign ovalid = ~cnt && cnt_d; // 采样下降沿,当 cnt 从 1 变为 0 时（即 cnt_d = 1 且 cnt = 0），ovalid 信号会变为有效。也就是信号的下降沿被捕捉到了，这一时刻输出数据是有效的。
