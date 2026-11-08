`timescale 1ns/1ns

// cmp —— 参数化三路比较器
//
// 用途
//   对两个无符号数做大于、等于、小于比较。
//
// 接口
//   参数
//     WIDTH  操作数位宽
//   端口
//     a / b  两个操作数
//     gt     a > b
//     eq     a == b
//     lt     a < b
//
// 使用方法
//   三个输出互斥且完备，直接接译码或分支逻辑即可；
//   模块名用 cmp 是为了让端口能叫 eq，端口名不能与模块名相同。

module cmp #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    output wire             gt,
    output wire             eq,
    output wire             lt
);

    assign gt = (a > b);
    assign eq = (a == b);
    assign lt = (a < b);

endmodule
