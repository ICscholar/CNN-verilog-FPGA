module CNN
(
    input wire clk,                     // 时钟信号
    input wire resetn,                  // 复位信号，低电平有效
    
    input wire start_cnn,               // 启动CNN计算信号
    
    input wire image_tvalid,            // 图像数据有效信号
    output wire image_tready,           // 图像数据准备好信号
    input wire signed [7:0] image_tdata, // 图像数据输入，8位有符号数
    
    input wire weight_tvalid,           // 卷积层权重数据有效信号
    output wire weight_tready,          // 卷积层权重数据准备好信号
    input wire signed [7:0] weight_tdata, // 卷积层权重数据输入，8位有符号数
    
    input wire weightfc_tvalid,         // 全连接层权重数据有效信号
    output wire weightfc_tready,        // 全连接层权重数据准备好信号
    input wire signed [7:0] weightfc_tdata, // 全连接层权重数据输入，8位有符号数
    
    output wire cnn_done,               // CNN计算完成信号
   
    input wire result_tready,           // 结果数据准备好信号
    output wire result_tvalid,          // 结果数据有效信号
    output wire signed [31:0] result_tdata, // 结果数据输出，32位有符号数

    output wire [3:0] conv_cnt          // 当前卷积层计数
);

// 内部寄存器定义
reg image_ready;            // 图像数据准备好信号寄存器
reg weight_ready;           // 卷积层权重数据准备好信号寄存器
reg weightfc_ready;         // 全连接层权重数据准备好信号寄存器
reg result_valid_reg;         // 结果数据有效信号寄存器
reg weight_rerd_reg;          // 权重读取完成信号寄存器
reg cnn_done_reg;             // CNN计算完成信号寄存器
reg signed [31:0] result_data; // 结果数据寄存器

// 输出信号连接到寄存器
assign image_tready = image_ready;
assign weight_tready = weight_ready;
assign weightfc_tready = weightfc_ready;
assign result_tvalid = result_valid_reg;
assign cnn_done = cnn_done_reg;
assign weight_rerd = weight_rerd_reg;
assign result_tdata = result_data;

// 内部状态信号定义
reg start_window;           // 窗口开始信号，用于触发卷积操作
reg start_conv;             // 卷积开始信号

// 操作有效信号
wire [5:0] conv_wr_en;       // 卷积结果写入有效信号
wire [5:0] add_wr_en;        // 加法结果写入有效信号
wire [5:0] relu_wr_en;       // ReLU结果写入有效信号
wire [5:0] pooling_wr_en;    // 池化结果写入有效信号
wire [9:0] fc_wr_en;         // 全连接层结果写入有效信号

// 卷积完成信号
wire [5:0] conv_done;

// 窗口数据线
wire [39:0] taps;
reg signed [31:0] add_data [0:5]; // 加法输入数据
reg signed [31:0] relu_data [0:5]; // ReLU输入数据

// 各层输出结果
wire signed [31:0] conv_result [0:5]; // 卷积层结果
wire signed [31:0] add_result [0:5];  // 加法层结果
wire signed [7:0] relu_result [0:5];  // ReLU层结果
wire signed [7:0] pooling_result [0:5]; // 池化层结果
wire signed [31:0] fc_result [0:9];   // 全连接层结果
reg signed [31:0] result_r0 [0:9];    // 第一次全连接累加结果
reg signed [31:0] result_r1 [0:9];    // 第二次全连接累加结果

// 卷积层计数器
reg [3:0] conv_counter = 4'd0;

// feature map（特征图）读写控制信号
reg [5:0] fmap_rdrst;   // 特征图读地址复位信号
reg [5:0] fmap_rden;    // 特征图读使能信号

// 图像输入寄存器
reg [7:0] image_in;

// 状态寄存器，用于控制卷积操作
reg state;

// 权重计数器，用于控制权重的加载
reg [10:0] weight_counter;

// 卷积层权重存储器
reg signed [7:0] weight_c [0:5];
reg signed [7:0] weight_fc [0:9];

// 时钟计数器
reg [9:0] cnt;

// 卷积层输入数据读写控制信号
reg [5:0] fmap_wr_en;
wire signed [7:0] fmap_dout [0:5];

// 中间结果存储器（FIFO）
reg [11:0] s_fifo_valid;  // 中间结果FIFO输入有效信号
reg signed [31:0] s_fifo_data [0:11]; // 中间结果FIFO输入数据
wire [11:0] s_fifo_ready; // 中间结果FIFO准备好信号
wire [11:0] m_fifo_valid; // 中间结果FIFO输出有效信号
wire signed [31:0] m_fifo_data [0:11]; // 中间结果FIFO输出数据
reg [11:0] m_fifo_ready; // 中间结果FIFO输出准备好信号

// 卷积开始信号寄存器
reg start_conv_ff_0;
reg start_conv_ff_1;
reg start_conv_ff_2;

// 卷积开始信号上升沿检测信号
wire start_conv_rise;

// 全连接计数器
reg [10:0] cnt_fc;
// 全连接层权重使能信号
reg [9:0] weight_fc_en;

// 当前卷积层计数输出
assign conv_cnt = conv_counter;

// 延迟启动信号寄存器
reg start_cnn_delay;

// 延迟启动信号逻辑
always @(posedge clk or negedge resetn)
if (!resetn)
    start_cnn_delay <= 0;
else
    start_cnn_delay <= start_cnn;

/////////////////////////// 结果计数器 //////////////////////////////

// 卷积结果计数器，用于控制卷积结果写入操作
reg [9:0] conv_result_cnt;
always @(posedge clk)
if (!start_conv)
    conv_result_cnt <= 0;
else
    if (conv_wr_en == 6'b111111)
        conv_result_cnt <= conv_result_cnt + 1;
    else
        conv_result_cnt <= conv_result_cnt;

// 加法结果计数器，用于控制加法结果写入操作
reg [6:0] add_result_cnt;
always @(posedge clk)
begin
    case (conv_counter)
    4'd4, 4'd5, 4'd6, 4'd7, 4'd8, 4'd9, 4'd10, 4'd11, 4'd12, 4'd13:
        begin
            if (add_result_cnt == 7'd64)
                add_result_cnt <= 7'd0;
            else if (add_wr_en == 6'b111111)
                add_result_cnt <= add_result_cnt + 7'd1;
            else
                add_result_cnt <= add_result_cnt;
        end
    default: add_result_cnt <= 7'd0;
    endcase
end

// 池化结果计数器，用于控制池化结果写入操作
reg [7:0] pooling_result_cnt;
always @(posedge clk)
begin
    case (conv_counter)
    4'd1:
        begin
            if (pooling_result_cnt == 8'd144)
                pooling_result_cnt <= 8'd0;
            else if (pooling_wr_en == 6'b111111)
                pooling_result_cnt <= pooling_result_cnt + 8'd1;
            else
                pooling_result_cnt <= pooling_result_cnt;
        end
    4'd12, 4'd13:
        begin
            if (pooling_result_cnt == 8'd16)
                pooling_result_cnt <= 8'd0;
            else if (pooling_wr_en == 6'b111111)
                pooling_result_cnt <= pooling_result_cnt + 8'd1;
            else
                pooling_result_cnt <= pooling_result_cnt;
        end
    default: pooling_result_cnt <= 8'd0;
    endcase
end

///////////////////////////////////////////////////////////////////////////
// 全连接层操作，控制权重加载
always @(posedge clk or negedge resetn)
begin
    if (!resetn)
        cnt_fc <= 0;
    else
    begin
        if (cnt_fc == 11'd1923)
            cnt_fc <= cnt_fc;
        else if (start_cnn_delay)
            cnt_fc <= cnt_fc + 1'b1;
    end
end

// 权重使能信号逻辑
//对应10个输出通道（手写数字识别10分类）
always @(*)
if (cnt_fc <= 10'd1)
    weight_fc_en <= 10'b0000000000;
else if (cnt_fc <= 11'd193)
    weight_fc_en <= 10'b0000000001;
else if (cnt_fc <= 10'd385)
    weight_fc_en <= 10'b0000000010;
else if (cnt_fc <= 11'd577)
    weight_fc_en <= 10'b0000000100;
else if (cnt_fc <= 11'd769)
    weight_fc_en <= 10'b0000001000;
else if (cnt_fc <= 11'd961)
    weight_fc_en <= 10'b0000010000;
else if (cnt_fc <= 11'd1153)
    weight_fc_en <= 10'b0000100000;
else if (cnt_fc <= 11'd1345)
    weight_fc_en <= 10'b0001000000;
else if (cnt_fc <= 11'd1537)
    weight_fc_en <= 10'b0010000000;
else if (cnt_fc <= 11'd1729)
    weight_fc_en <= 10'b0100000000;
else if (cnt_fc <= 11'd1921)
    weight_fc_en <= 10'b1000000000;
else
    weight_fc_en <= 10'b0000000000;

// 权重准备信号逻辑
always @(posedge clk or negedge resetn)
if (!resetn)
    weightfc_ready <= 1'b0;
else
    begin
        if (cnt_fc >= 11'd1921)
            weightfc_ready <= 1'b0;
        else if (cnt_fc == 11'd0)
            weightfc_ready <= 1'b0;
        else
            weightfc_ready <= 1'b1;
    end

// **********************卷积层循环操作*********************** // 
reg start_conv_delay;
   
always @(posedge clk or negedge resetn)
if (!resetn)
    start_conv_delay <= 0;
else
    start_conv_delay <= start_conv;

assign start_conv_rise = start_conv && (~start_conv_delay);
 
always @(posedge clk) 
if (cnn_done)
    conv_counter <= 4'd0;
else if (start_conv_rise)
    conv_counter <= conv_counter + 1;

// ********************状态控制*********************** // 
always @(*)
    case (conv_counter)
        4'd0, 4'd1: state <= 0; // 状态0，卷积操作
        default: state <= 1;    // 状态1，后续操作
    endcase

// ********************卷积权重读取*********************** // 
always @(posedge clk or negedge resetn)
if (!resetn)
    weight_ready <= 1'b0;
else
    begin
        if (!start_conv || cnt >= 10'd150)
            weight_ready <= 1'b0;
        else
            weight_ready <= 1'b1;
    end                      
    
always @(posedge clk or negedge resetn)
if (!resetn)
    weight_rerd_reg <= 0;
else if (cnn_done)
    weight_rerd_reg <= 1;
else
    weight_rerd_reg <= 0;   

always @(posedge clk or negedge resetn)
if (!resetn)
    weight_counter <= 0;
else if (cnn_done)
    weight_counter <= 0;
else if (weight_tvalid && weight_tready)
    weight_counter <= weight_counter + 1;  
    
// 每次卷积开始前，需要150个时钟周期加载权重;
always @(*)
begin
    if (weight_counter <= 11'd24)                                    
        weight_c[0] <= weight_tdata;
    else if (weight_counter <= 11'd49)
        weight_c[1] <= weight_tdata;
    else if (weight_counter <= 11'd74)
        weight_c[2] <= weight_tdata;    
    else if (weight_counter <= 11'd99)
        weight_c[3] <= weight_tdata;
    else if (weight_counter <= 11'd124)
        weight_c[4] <= weight_tdata;
    else if (weight_counter <= 11'd149)
        weight_c[5] <= weight_tdata;
    // 以下类似循环逻辑省略...
end

// 全连接层权重加载逻辑
always @(*)
begin
    if (cnt_fc <= 11'd1)
        begin
            weight_fc[0] <= 0;
            weight_fc[1] <= 0;
            weight_fc[2] <= 0;
            weight_fc[3] <= 0;
            weight_fc[4] <= 0;
            weight_fc[5] <= 0;
            weight_fc[6] <= 0;
            weight_fc[7] <= 0;
            weight_fc[8] <= 0;
            weight_fc[9] <= 0;
        end    
    // 全连接层权重加载逻辑，省略...
end   

// ***********************窗口启动控制逻辑*********************** // 
always @(posedge clk or negedge resetn)
begin
    if (!resetn)
        start_window <= 0;
    else
        if (conv_done == 6'b111111)
            start_window <= 0;
        else
            case (state)
            1'b0: if (cnt == 10'd11) start_window <= 1;
            1'b1: if (cnt == 10'd91) start_window <= 1;
            endcase
end

// *********************窗口实例化*********************** //
window window_inst(
    .clk(clk),
    .rstn(resetn),
    .start(start_window),
    .state(state),
    .din(image_in),
    .taps(taps)
);

// ********************卷积启动控制逻辑******************** //
always @(posedge clk or negedge resetn)
begin
    if (!resetn)
        start_conv <= 0;
    else
        case (conv_counter)
            4'd0: begin
                 if (conv_done[0] && conv_done[1] && conv_done[2] && conv_done[3] && conv_done[4] && conv_done[5])
                    start_conv <= 0;
                 else 
                    if (start_cnn_delay && ~cnn_done)
                        start_conv <= 1;
                    else
                        start_conv <= start_conv;
                 end
            4'd1: begin
                 if (conv_done[0] && conv_done[1] && conv_done[2] && conv_done[3] && conv_done[4] && conv_done[5])
                     start_conv <= 0;
                 else 
                     if (pooling_result_cnt == 8'd144)
                         start_conv <= 1;
                     else
                         start_conv <= start_conv;
                 end
            4'd2, 4'd3: begin
                      if (conv_done[0] && conv_done[1] && conv_done[2] && conv_done[3] && conv_done[4] && conv_done[5])
                          start_conv <= 0;
                      else
                          if (conv_result_cnt == 10'd64)
                              start_conv <= 1;
                          else
                              start_conv <= start_conv;
                      end
            // 以下是卷积层不同阶段的逻辑控制，省略...
        endcase
end

// 卷积权重使能控制信号
reg [5:0] weight_en = 6'b000000;

always @(*)
begin
    if (cnt == 10'd0)
        weight_en <= 6'b000000;
    else if (cnt <= 10'd25)
        weight_en <= 6'b000001;
    else if (cnt <= 10'd50)
        weight_en <= 6'b000010;
    else if (cnt <= 10'd75)
        weight_en <= 6'b000100;
    else if (cnt <= 10'd100)
        weight_en <= 6'b001000;
    else if (cnt <= 10'd125)
        weight_en <= 6'b010000;
    else if (cnt <= 10'd150)
        weight_en <= 6'b100000;
    else
        weight_en <= 6'b000000;
    end

// ********************卷积模块实例化********************* //
genvar i;
generate
    for (i = 0; i <= 5; i = i + 1)
        begin: conv_inst
            conv u_conv(
                .clk(clk),
                .rstn(resetn),
                .start(start_conv),
                .weight_en(weight_en[i]),
                .weight(weight_c[i]),
                .taps(taps),
                .state(state),
                .dout(conv_result[i]),
                .ovalid(conv_wr_en[i]),
                .done(conv_done[i])
            );
        end
endgenerate

// *******************中间结果FIFO写入控制***************** //
always @(*)
case (conv_counter)
    4'd2: if (conv_wr_en == 6'b111111) s_fifo_valid <= 12'b000000111111;
         else s_fifo_valid <= 12'b000000000000;
    4'd3: if (conv_wr_en == 6'b111111) s_fifo_valid <= 12'b111111000000;
         else s_fifo_valid <= 12'b000000000000;
    4'd4, 4'd6, 4'd8, 4'd10: if (add_wr_en == 6'b111111) s_fifo_valid <= 12'b000000111111;
         else s_fifo_valid <= 12'b000000000000;
    4'd5, 4'd7, 4'd9, 4'd11: if (add_wr_en == 6'b111111) s_fifo_valid <= 12'b111111000000;
         else s_fifo_valid <= 12'b000000000000;
    default: s_fifo_valid <= 12'b000000000000;     
endcase

// 中间结果FIFO写入数据
integer j;
always @(*)
case (conv_counter)
    4'd2: for (j = 0; j <= 5; j = j + 1)
                 s_fifo_data[j] <= conv_result[j];
    4'd3: for (j = 0; j <= 5; j = j + 1)
                 s_fifo_data[j + 6] <= conv_result[j];                     
    4'd4, 4'd6, 4'd8, 4'd10: for (j = 0; j <= 5; j = j + 1)
                             s_fifo_data[j] <= add_result[j]; 
    4'd5, 4'd7, 4'd9, 4'd11: for (j = 0; j <= 5; j = j + 1)
                             s_fifo_data[j + 6] <= add_result[j];                                                      
    default: for (j = 0; j <= 11; j = j + 1)
                s_fifo_data[j] <= 0;
           
endcase

// ****************中间结果FIFO读出控制****************** //
always @(*)
case (conv_counter)
    4'd4, 4'd6, 4'd8, 4'd10, 4'd12: if (conv_wr_en == 6'b111111) m_fifo_ready <= 12'b000000111111;
         else if (conv_wr_en == 6'b000000) m_fifo_ready <= 12'b000000000000;
    4'd5, 4'd7, 4'd9, 4'd11, 4'd13: if (conv_wr_en == 6'b111111) m_fifo_ready <= 12'b111111000000;
         else if (conv_wr_en == 6'b000000) m_fifo_ready <= 12'b000000000000;
    default: m_fifo_ready <= 12'b000000000000;     
endcase

// ********************加法操作（add_data）********************** //
integer k;
always @(posedge clk)
begin
    case (conv_counter)
    4'd4, 4'd6, 4'd8, 4'd10, 4'd12: begin
         for (k = 0; k <= 5; k = k + 1)
             if (m_fifo_valid[k] && m_fifo_ready[k])
                 add_data[k] <= m_fifo_data[k];
             else 
                 add_data[k] <= 0;
         end
    4'd5, 4'd7, 4'd9, 4'd11, 4'd13: begin
         for (k = 0; k <= 5; k = k + 1)
             if (m_fifo_valid[k + 6] && m_fifo_ready[k + 6])
                 add_data[k] <= m_fifo_data[k + 6];
             else 
                 add_data[k] <= 0;
         end
    default: begin
            for (k = 0; k <= 5; k = k + 1)
                add_data[k] <= 0;
            end
    endcase
end

// 重置FIFO信号
reg reset_fifo;

always @(posedge clk or negedge resetn)
if (!resetn)
    reset_fifo <= 0;
else
    if (cnn_done)
        reset_fifo <= 0;
    else
        reset_fifo <= 1;
   
// ***************** FIFO模块实例化 ****************** //
genvar a;
generate
    for (a = 0; a <= 11; a = a + 1)
        begin: fifo_inst
            user_fifo_ip your_instance_name(
              .s_axis_aresetn(reset_fifo),         // FIFO复位信号
              .s_axis_aclk(clk),                   // FIFO时钟信号
              .s_axis_tvalid(s_fifo_valid[a]),     // FIFO输入有效信号
              .s_axis_tready(s_fifo_ready[a]),     // FIFO输入准备好信号
              .s_axis_tdata(s_fifo_data[a]),       // FIFO输入数据
              .m_axis_tvalid(m_fifo_valid[a]),     // FIFO输出有效信号
              .m_axis_tready(m_fifo_ready[a]),     // FIFO输出准备好信号
              .m_axis_tdata(m_fifo_data[a])        // FIFO输出数据
            );
        end
endgenerate

// ********************加法模块实例化**************** //
reg ivalid_add;
always @(*)
case (conv_counter)
4'd4, 4'd5, 4'd6, 4'd7, 4'd8, 4'd9, 4'd10, 4'd11, 4'd12, 4'd13: 
    if (conv_wr_en == 6'b111111) ivalid_add <= 1'b1;
    else ivalid_add <= 1'b0;
default: ivalid_add <= 1'b0;
endcase

genvar b;
generate
    for (b = 0; b <= 5; b = b + 1)
        begin: add_inst 
            add u_add(
                .clk(clk),
                .ivalid(ivalid_add),
                .din_0(conv_result[b]),
                .din_1(add_data[b]),
                .ovalid(add_wr_en[b]),
                .dout(add_result[b])
            );    
        end
endgenerate
    
// ******************ReLU模块启用信号控制************** //
reg ivalid_relu;
always @(*)
case (conv_counter)
4'd1: if (conv_wr_en == 6'b111111) ivalid_relu <= 1'b1;
     else ivalid_relu <= 1'b0;
4'd12, 4'd13: if (add_wr_en == 6'b111111) ivalid_relu <= 1'b1;
     else ivalid_relu <= 1'b0;
default: ivalid_relu <= 1'b0;
endcase

// ******************ReLU模块输入数据控制****************** //
integer m;
always @(*)
case (conv_counter)
    4'd1: for (m = 0; m <= 5; m = m + 1)
             relu_data[m] <= conv_result[m];
    4'd12, 4'd13: for (m = 0; m <= 5; m = m + 1)
             relu_data[m] <= add_result[m];    
    default: for (m = 0; m <= 5; m = m + 1)
             relu_data[m] <= 0;
endcase

// ********************ReLU模块实例化******************* //
genvar c;
generate
    for (c = 0; c <= 5; c = c + 1)
        begin: relu_inst 
            relu u_relu(
                .clk(clk),
                .ivalid(ivalid_relu),
                .state(state),
                .din(relu_data[c]),
                .ovalid(relu_wr_en[c]),
                .dout(relu_result[c])
            );    
        end
endgenerate

// ******************池化模块实例化****************** //
reg ivalid_pooling;
always @(*) begin
    case (conv_counter)
        4'd1, 4'd12, 4'd13:
            if (relu_wr_en == 6'b111111) 
                ivalid_pooling <= 1'b1;
            else 
                ivalid_pooling <= 1'b0;
        default: ivalid_pooling <= 1'b0;
    endcase
end
	
genvar d;
generate
    for (d = 0; d <= 5; d = d + 1)
        begin: pooling_inst
            maxpooling u_pooling(
                .clk(clk),
                .rstn(resetn),
                .ivalid(ivalid_pooling),
                .state(state),
                .din(relu_result[d]),
                .ovalid(pooling_wr_en[d]),
                .dout(pooling_result[d])                                     
            );
        end
endgenerate

// ************特征图写入控制************** //
always @(*)
if (conv_counter == 4'd1 && pooling_wr_en == 6'b111111)
    fmap_wr_en <= 6'b111111;
else
    fmap_wr_en <= 6'b000000;

reg reset_fmap;

always @(posedge clk or negedge resetn)
if (!resetn)
    reset_fmap <= 0;
else
    if (cnn_done)
        reset_fmap <= 0;
    else
        reset_fmap <= 1;

// 特征图FIFO模块实例化
genvar e;
generate
    for (e = 0; e <= 5; e = e + 1)
        begin: fmap_inst
            FIFO_fmap u_FIFO_fmap (
              .clk(clk),
              .rstn(reset_fmap),
              .din(pooling_result[e]),
              .wr_en(fmap_wr_en[e]),
              .rd_en(fmap_rden[e]),
              .rd_rst(fmap_rdrst[e]),     // 读地址复位信号
              .dout(fmap_dout[e]),
              .full(),
              .empty()
            );
        end
endgenerate

// ***************全连接层实例化***************** //
reg ivalid_fc;
always @(*)
case (conv_counter)
4'd12, 4'd13: if (pooling_wr_en == 6'b111111) ivalid_fc <= 1;
      else ivalid_fc <= 0;
default: ivalid_fc <= 0;
endcase

genvar f;
generate
    for (f = 0; f < 10; f = f + 1)
        begin: fullconnect_inst
            fc u_fullconnect(
                .clk(clk),
                .rstn(resetn),
                .ivalid(ivalid_fc),
                .din_0(pooling_result[0]),
                .din_1(pooling_result[1]),
                .din_2(pooling_result[2]),
                .din_3(pooling_result[3]),
                .din_4(pooling_result[4]),
                .din_5(pooling_result[5]),
                .weight(weight_fc[f]),
                .weight_en(weight_fc_en[f]),
                .ovalid(fc_wr_en[f]),
                .dout(fc_result[f])
            );
        end
endgenerate

// *************全连接层累加结果存储************** //
integer r;
always @(posedge clk)
case (conv_counter)
4'd12: if (fc_wr_en == 10'b1111111111)
      begin
          result_r0[0] <= fc_result[0];
          result_r0[1] <= fc_result[1];
          result_r0[2] <= fc_result[2];
          result_r0[3] <= fc_result[3];
          result_r0[4] <= fc_result[4];
          result_r0[5] <= fc_result[5];
          result_r0[6] <= fc_result[6];
          result_r0[7] <= fc_result[7];
          result_r0[8] <= fc_result[8];
          result_r0[9] <= fc_result[9];
      end
4'd13: if (fc_wr_en == 10'b1111111111)
      begin
          result_r1[0] <= fc_result[0] + result_r0[0];
          result_r1[1] <= fc_result[1] + result_r0[1];
          result_r1[2] <= fc_result[2] + result_r0[2];
          result_r1[3] <= fc_result[3] + result_r0[3];
          result_r1[4] <= fc_result[4] + result_r0[4];
          result_r1[5] <= fc_result[5] + result_r0[5];
          result_r1[6] <= fc_result[6] + result_r0[6];
          result_r1[7] <= fc_result[7] + result_r0[7];
          result_r1[8] <= fc_result[8] + result_r0[8];
          result_r1[9] <= fc_result[9] + result_r0[9];
      end
default: begin
          result_r0[0] <= 0;
          result_r0[1] <= 0;
          result_r0[2] <= 0;
          result_r0[3] <= 0;
          result_r0[4] <= 0;
          result_r0[5] <= 0;
          result_r0[6] <= 0;
          result_r0[7] <= 0;
          result_r0[8] <= 0;
          result_r0[9] <= 0;
          result_r1[0] <= 0;
          result_r1[1] <= 0;
          result_r1[2] <= 0;
          result_r1[3] <= 0;
          result_r1[4] <= 0;
          result_r1[5] <= 0;
          result_r1[6] <= 0;
          result_r1[7] <= 0;
          result_r1[8] <= 0;
          result_r1[9] <= 0;
        end
endcase

// 结果有效信号逻辑
reg result_valid;
reg [3:0] cnt4;

always @(posedge clk or negedge resetn)
begin
if (!resetn)
    result_valid <= 0;
else
    if (!start_cnn_delay)
        result_valid <= 0;
    else if (cnt4 > 4'd10)
        result_valid <= 0; 
    else if (conv_counter == 4'd13 && fc_wr_en == 10'b1111111111)
        result_valid <= 1;    
end

wire start_cnn_r;

assign start_cnn_r = start_cnn && ~start_cnn_delay;

// CNN完成信号逻辑
always @(posedge clk or negedge resetn)
begin
if (!resetn)
    cnn_done_reg <= 0;
else
    if (start_cnn_r)
        cnn_done_reg <= 0;
    else if (cnt4 == 4'd10)
        cnn_done_reg <= 1;
end
   
always @(posedge clk or negedge resetn)
begin
if (!resetn)
    cnt4 <= 0;
else
    if (!result_valid)
        cnt4 <= 0;
    else
        cnt4 <= cnt4 + 1;
end

// 结果数据输出逻辑
always @(posedge clk or negedge resetn)
begin
if (!resetn)
    result_valid_reg <= 1'b0;
else    
    if (cnt4 == 4'd0)
        result_valid_reg <= 1'b0;
    else if (cnt4 <= 4'd10)
        result_valid_reg <= 1'b1;
    else
        result_valid_reg <= 1'b0;
end

always @(posedge clk)
begin
if (cnt4 > 4'd0 && cnt4 <= 4'd10)
    result_data <= result_r1[cnt4-1];
else
    result_data <= 0;
end

// 输出信号分配
assign conv_start = start_conv;
assign window_start = start_window;
assign done_conv = conv_done;

endmodule
