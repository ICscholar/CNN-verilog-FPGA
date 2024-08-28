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

