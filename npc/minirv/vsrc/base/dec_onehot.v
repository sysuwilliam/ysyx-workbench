`timescale 1ns/1ns

// dec_onehot —— 参数化独热译码器
//
// 用途
//   根据 sel 把一根输出线置 1，其余为 0。典型用法：
//   funct3 转控制信号、addr[1:0] 转字节通道、一热的状态编码。
//
// 参数
//   IN_W   选择端位宽，默认 2
//   OUT_W  输出位宽，默认 1 << IN_W
//
// 端口
//   en     使能，高有效
//   sel    选择端
//   onehot 独热输出，onehot[sel] 为 1
//
// 使用方法
//   常开实例把 en 接 1'b1；en=0 时输出全 0。
//   OUT_W 取 1<<IN_W 时 sel 的任何取值都有对应输出线；
//   OUT_W 小于 1<<IN_W 时高位被截掉，用不到的选择值输出全 0。

module dec_onehot #(
    parameter IN_W  = 2,
    parameter OUT_W = 1 << IN_W
) (
    input  wire             en,
    input  wire [IN_W-1:0]  sel,
    output wire [OUT_W-1:0] onehot
);

    assign onehot = en ? ({{(OUT_W-1){1'b0}}, 1'b1} << sel) : {OUT_W{1'b0}};

endmodule
