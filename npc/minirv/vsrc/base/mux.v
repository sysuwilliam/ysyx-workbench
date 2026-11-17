`timescale 1ns/1ns

// mux —— 参数化多路选择器
//
// 用途
//   从 NR_IN 路数据中选一路输出。写回来源、ALU 操作数、PC 下一值
//   这类选择都用它。
//
// 参数
//   WIDTH   每路数据位宽，默认 32
//   NR_IN   输入路数
//   SEL_W   选择端位宽，默认 $clog2(NR_IN)，最小 1
//
// 端口
//   din     扁平输入，第 i 路位于 din[i*WIDTH +: WIDTH]
//   sel     选择端
//   dout    选中的一路
//
// 使用方法
//   din 按 {inN-1, ..., in0} 拼接，in0 落在最低 WIDTH 位。
//   NR_IN 不必是 2 的幂：内部按 1<<SEL_W 开数组，用不到的槽位补零，
//   所以三路、五路也能用，sel 越界时输出 0 而不是 x。
//   SEL_W 大于 $clog2(NR_IN) 时，超出的选择值同样落到补零槽位。

module mux #(
    parameter WIDTH = 32,
    parameter NR_IN = 2,
    parameter SEL_W = (NR_IN <= 2) ? 1 : $clog2(NR_IN)
) (
    input  wire [NR_IN*WIDTH-1:0] din,
    input  wire [SEL_W-1:0]       sel,
    output wire [WIDTH-1:0]       dout
);

    localparam NR_SEL = 1 << SEL_W;

    wire [WIDTH-1:0] in_slice [0:NR_SEL-1];

    genvar i;
    generate
        for (i = 0; i < NR_SEL; i = i + 1) begin : g_unpack
            if (i < NR_IN) begin : g_used
                assign in_slice[i] = din[i*WIDTH +: WIDTH];
            end else begin : g_pad
                assign in_slice[i] = {WIDTH{1'b0}};
            end
        end
    endgenerate

    assign dout = in_slice[sel];

endmodule
