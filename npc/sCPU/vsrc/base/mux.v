`timescale 1ns/1ns

// mux —— 参数化多路选择器
//
// 用途
//   从 NR_IN 路数据中选一路输出。
//
// 接口
//   参数
//     WIDTH   每路数据位宽
//     NR_IN   输入路数
//     SEL_W   选择端位宽，默认 $clog2(NR_IN)
//   端口
//     din     扁平输入，第 i 路位于 din[i*WIDTH +: WIDTH]
//     sel     选择端，取值 0 ~ NR_IN-1
//     dout    选中的一路
//
// 使用方法
//   NR_IN 取 2、4、8 这类 2 的幂；din 按 {inN-1, ..., in0} 拼接，
//   in0 落在最低 WIDTH 位。非 2 的幂会让 sel 越界，不要用。

module mux #(
    parameter WIDTH = 8,
    parameter NR_IN = 2,
    parameter SEL_W = $clog2(NR_IN)
) (
    input  wire [NR_IN*WIDTH-1:0] din,
    input  wire [SEL_W-1:0]       sel,
    output wire [WIDTH-1:0]       dout
);

    wire [WIDTH-1:0] in_slice [0:NR_IN-1];

    genvar i;
    generate
        for (i = 0; i < NR_IN; i = i + 1) begin : g_unpack
            assign in_slice[i] = din[i*WIDTH +: WIDTH];
        end
    endgenerate

    assign dout = in_slice[sel];

endmodule
