`timescale 1ns/1ns

// adder —— 参数化加法器
//
// 用途
//   计算 a + b + cin，同时给出最高位的进位。pc+4、ALU 的加法、
//   访存地址计算都用它。
//
// 参数
//   WIDTH  操作数与结果位宽，默认 32
//
// 端口
//   a / b  两个加数
//   cin    进位输入，普通加法接 1'b0
//   cout   最高位向外的无符号进位
//   sum    和，按 2^WIDTH 回绕
//
// 使用方法
//   和与进位一次给全：需要进位用 {cout, sum} 取，不需要时把 cout
//   接到名字含 unused 的线，避免引脚悬空告警。
//   这是无符号加法，结果按 32 位回绕，与 EMU 的加法语义一致。

module adder #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire             cin,
    output wire             cout,
    output wire [WIDTH-1:0] sum
);

    assign {cout, sum} = {1'b0, a} + {1'b0, b} + cin;

endmodule
