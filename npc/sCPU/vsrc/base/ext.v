`timescale 1ns/1ns

// ext —— 参数化位扩展
//
// 用途
//   把 IN_W 位数据扩展到 OUT_W 位，支持符号扩展与零扩展。
//
// 接口
//   参数
//     IN_W    输入位宽
//     OUT_W   输出位宽
//     SIGNED  1 复制符号位，0 补零
//   端口
//     din     输入
//     dout    扩展后的输出
//
// 使用方法
//   OUT_W 必须不小于 IN_W；bner0 的 4 位偏移接 SIGNED=1，
//   其它位宽转换按需要选 0 或 1。扩展方式在展开期确定，不产生选择器。

module ext #(
    parameter IN_W   = 4,
    parameter OUT_W  = 8,
    parameter SIGNED = 1
) (
    input  wire [IN_W-1:0]  din,
    output wire [OUT_W-1:0] dout
);

    generate
        if (SIGNED) begin : g_sign
            assign dout = {{(OUT_W-IN_W){din[IN_W-1]}}, din};
        end else begin : g_zero
            assign dout = {{(OUT_W-IN_W){1'b0}}, din};
        end
    endgenerate

endmodule
