`timescale 1ns/1ns

// adder —— 参数化加法器
//
// 用途
//   计算 a + b + cin，同时给出最高位的进位。
//
// 接口
//   参数
//     WIDTH  操作数与结果位宽
//   端口
//     a / b  两个加数
//     cin    进位输入
//     cout   最高位向外的无符号进位
//     sum    和，按 2^WIDTH 回绕
//
// 使用方法
//   普通加法把 cin 接 1'b0；不需要进位时把 cout 接到名字含 unused 的线，
//   避免 PINMISSING。需要进位时用 {cout, sum} 一起取结果。

module adder #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire             cin,
    output wire             cout,
    output wire [WIDTH-1:0] sum
);

    assign {cout, sum} = {1'b0, a} + {1'b0, b} + cin;

endmodule
