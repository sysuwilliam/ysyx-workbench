// ============================================================================
// vmem —— 静态图片的只读显存
//
// 640 列 × 512 行，每像素 24 位（RGB 各 8 位），按列优先存放：
// addr = {h_addr[9:0], v_addr[8:0]}，同一列的 512 个点地址连续。
// 内容由 $readmemh 从 resource/picture.hex 读入，路径相对运行目录。
// 组合读，NVBoard 下没有延迟；上 FPGA 想用 Block RAM 时再改成时钟沿读。
// ============================================================================
module vmem (
    input  [9:0]  h_addr,
    input  [8:0]  v_addr,
    output [23:0] color
);

    reg [23:0] mem [0:327679];

    initial $readmemh("resource/picture.hex", mem);

    assign color = mem[{h_addr, v_addr}];

endmodule
