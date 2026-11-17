`timescale 1ns/1ns

// Reg —— 参数化寄存器
//
// 用途
//   保存 WIDTH 位数据，同步复位，带写使能。PC、GPR 的每一项、
//   以及将来的流水线寄存器都用它。
//
// 参数
//   WIDTH      数据位宽，默认 32
//   RESET_VAL  同步复位值，按 WIDTH 自动定宽，写 8'hA5 或
//              32'h8000_0000 都不用手动补位
//
// 端口
//   clk    时钟，上升沿写入
//   rst    同步复位，高有效，优先于 wen
//   wen    写使能，1 装入 din，0 保持
//   din    写入数据
//   dout   当前值
//
// 使用方法
//   复位必须至少跨一个上升沿才生效；rst 与 wen 同时为 1 时复位优先。
//   不需要写使能时把 wen 接 1'b1；只读寄存器把 wen 接 1'b0。

module Reg #(
    parameter WIDTH = 32,
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
