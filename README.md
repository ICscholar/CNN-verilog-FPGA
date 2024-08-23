## Statement:
### Most of the code and associated materials are referenced from https://github.com/JiachengCao/cnn_accelerator. This project is a detailed annotated version of the code.The annotations were independently added by me to enhance clarity based on my understanding of the code and algorithms.
#### 本代码及其配套内容大部分参考了 https://github.com/JiachengCao/cnn_accelerator，本工程为代码详细注释版本。注释部分由我根据对代码和算法的理解自行添加，以提高其清晰度。

项目实现了使用纯verilog语法实现LeNet-5（简单CNN网络）结构进行手写数字识别并进行仿真，采用八位无符号数量化。  

输入图片（28x28）-> 卷积 (2x2x6) -> 24x24x6 feature map -> 激活（relu）-> maxpooling(2x2) -> 12x12x6 feature map -> 卷积 (2x2x12) -> 8x8x12 feature map -> maxpooling(2x2) -> 4x4x12 feature map
-> 192 fully connect -> 10 output 

The project implemented handwritten digit recognition and simulation using a pure Verilog syntax to construct the LeNet-5 architecture (a simple CNN network), with 8-bit unsigned quantization.  

input figure（28x28）-> conv (2x2x6) -> 24x24x6 feature map -> activation（relu）-> maxpooling(2x2) -> 12x12x6 feature map -> conv (2x2x12) -> 8x8x12 feature map -> maxpooling(2x2) -> 4x4x12 feature map
-> 192 fully connect -> 10 output 
