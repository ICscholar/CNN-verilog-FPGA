module FIFO_fmap
(
    input  clk,             // 时钟信号
    input  rstn,            // 复位信号，低电平有效
    input  [7:0] din,       // 8位输入数据
    input  wr_en,           // 写入使能信号
    input  rd_en,           // 读取使能信号
    input  rd_rst,          // 读指针复位信号
    output empty,           // FIFO为空标志信号
    output full,            // FIFO为满标志信号
    output [7:0] dout       // 8位输出数据
);

    // 定义读写指针寄存器
    reg [7:0] rd_ptr, wr_ptr;
    
    // 定义FIFO存储器，深度为150，每个存储单元为8位
    reg [7:0] mem [0:149];
    
    // 输出数据寄存器
    reg [7:0] dout_r;
    
    // 循环变量，用于初始化内存
    integer i;
    
    // 判断FIFO是否为空
    assign empty = (wr_ptr == rd_ptr);
    
    // 判断FIFO是否为满
    assign full  = ((wr_ptr - rd_ptr) == 8'd150);
    
    // 写使能信号延迟一拍
    reg wr_en_delay;
    always @(posedge clk) begin
        if (!rstn)
            wr_en_delay <= 0;           // 如果复位信号有效，延迟使能信号复位
        else
            wr_en_delay <= wr_en;        // 否则将当前写使能信号赋值给延迟使能信号
    end
    
    // 读操作
    always @(posedge clk or negedge rstn) begin
        if (!rstn)
            dout_r <= 0;                 // 如果复位信号有效，输出数据复位
        else if (rd_en && !empty)
            dout_r <= mem[rd_ptr];       // 如果读使能有效且FIFO不为空，读取数据到输出寄存器
    end
    
    // 写操作
    always @(posedge clk) begin
        if (rstn && wr_en_delay && !full)
            mem[wr_ptr] <= din;          // 如果复位信号无效且写使能有效且FIFO未满，将输入数据写入存储器
    end
    
    // 写指针递增
    always @(posedge clk or negedge rstn) begin
        if (!rstn) 
            wr_ptr <= 0;                 // 如果复位信号有效，写指针复位
        else if (!full && wr_en_delay)   // 如果FIFO未满且写使能有效
            wr_ptr <= wr_ptr + 1;        // 写指针递增
    end
    
    // 读指针递增
    always @(posedge clk or negedge rstn) begin
        if (!rstn)
            rd_ptr <= 0;                 // 如果复位信号有效，读指针复位
        else if (rd_rst) 
            rd_ptr <= 0;                 // 如果读指针复位信号有效，读指针复位
        else if (!empty && rd_en)        // 如果FIFO不为空且读使能有效
            rd_ptr <= rd_ptr + 1;        // 读指针递增
    end
    
    // 输出数据连接到输出寄存器
    assign dout = dout_r;

endmodule 
