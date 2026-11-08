`timescale 1ns/1ns

// Reg —— 参数化寄存器
//
// 用途
//   保存 WIDTH 位数据，带同步复位与写使能。
//
// 接口
//   参数
//     WIDTH      数据位宽
//     RESET_VAL  同步复位值
//   端口
//     clk    时钟
//     rst    同步复位，高有效
//     wen    写使能
//     din    写入数据
//     dout   当前值
//
// 使用方法
//   复位优先：rst 为 1 时装 RESET_VAL，至少跨一个上升沿才生效；
//   rst 为 0 时 wen=1 装入 din，wen=0 保持。其它模块不直接写 always。

module Reg #(
    parameter WIDTH = 8,
    parameter [WIDTH-1:0] RESET_VAL = {WIDTH{1'b0}}
) (
    input  wire             clk,
    input  wire             rst,
    input  wire             wen,
    input  wire [WIDTH-1:0] din,
    output reg  [WIDTH-1:0] dout
);

    always @(posedge clk) begin
        if (rst)
            dout <= RESET_VAL;
        else if (wen)
            dout <= din;
    end

endmodule
