module relu
(
    input clk,                         // 时钟信号
    input signed [31:0] din,           // 32位有符号输入数据
    input ivalid,                      // 输入数据有效信号
    input state,                       // 状态信号，用于选择数据输出方式
    output reg ovalid,                 // 输出数据有效信号
    output reg signed [7:0] dout       // 8位有符号输出数据
);

    reg wren;                          // 写入使能信号
    reg [31:0] dout_r;                 // 中间结果寄存器，用于存储ReLU操作后的数据
    reg [31:0] dout_delay;             // 中间结果延迟寄存器

    // 写入使能信号控制
    always @(posedge clk) begin
        if (ivalid)                    // 如果输入数据有效
            wren <= 1'b1;              // 使能写入信号
        else
            wren <= 1'b0;              // 否则，取消写入使能
    end

    // ReLU激活函数实现
    always @(posedge clk) begin
        if (din[31])                   // 如果输入数据的最高位为1，表示负数
            dout_r <= 0;               // 将输出设为0（ReLU的效果是负数部分为0）
        else
            dout_r <= din;             // 否则，直接输出输入数据
    end

    // 数据延迟一拍
    always @(posedge clk) begin
        dout_delay <= dout_r;          // 将当前结果存入延迟寄存器
    end
    
    /*    
    assign dout = (state)?(dout_delay >>> 10):(dout_r >>> 10);
    assign ovalid = wren;
    */
    
    // 数据输出选择
    always @(posedge clk) begin
        if (state)                     // 如果状态信号为1
            dout <= (dout_delay >>> 10); // 使用延迟后的数据右移10位（实现缩放或其他操作）
        else
            dout <= (dout_r >>> 10);   // 否则，直接使用当前数据右移10位
    end
    
    // 输出有效信号设置
    always @(posedge clk) begin
        ovalid <= wren;                // 将写入使能信号直接作为输出有效信号
    end
    
endmodule
