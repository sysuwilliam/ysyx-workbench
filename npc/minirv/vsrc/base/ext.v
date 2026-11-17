`timescale 1ns/1ns

// ext —— 参数化位扩展
//
// 用途
//   把 IN_W 位数据扩展到 OUT_W 位，支持符号扩展与零扩展。
//   minirv 里的四处用法：
//     I 型立即数 12 -> 32，SIGNED=1（addi、lw、lbu、jalr）
//     S 型立即数 12 -> 32，SIGNED=1（sw、sb）
//     lbu 读回的字节 8 -> 32，SIGNED=0
//     U 型立即数 20 -> 32，SIGNED=0
//
// 参数
//   IN_W    输入位宽，默认 12
//   OUT_W   输出位宽，默认 32，必须不小于 IN_W
//   SIGNED  1 复制符号位，0 补零
//
// 端口
//   din     输入
//   dout    扩展后的输出
//
// 使用方法
//   扩展方式在展开期确定，不产生运行期选择器；同一份位宽组合多次
//   使用时例化多个实例即可。
//   OUT_W == IN_W 时走直连分支，不会生成 {{0{...}}, din} 这种零次复制。

module ext #(
    parameter IN_W   = 12,
    parameter OUT_W  = 32,
    parameter SIGNED = 1
) (
    input  wire [IN_W-1:0]  din,
    output wire [OUT_W-1:0] dout
);

    generate
        if (OUT_W == IN_W) begin : g_same
            assign dout = din;
        end else if (SIGNED) begin : g_sign
            assign dout = {{(OUT_W-IN_W){din[IN_W-1]}}, din};
        end else begin : g_zero
            assign dout = {{(OUT_W-IN_W){1'b0}}, din};
        end
    endgenerate

endmodule
