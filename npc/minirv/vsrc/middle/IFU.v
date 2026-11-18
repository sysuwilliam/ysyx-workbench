`timescale 1ns/1ns

// IFU —— 取指单元
//
// 保存 PC，产生 pc+4，并在跳转时选择 jump_target。
// 时序部分只有 PC 寄存器；rst 同步高有效，stop_now 冻结 PC。
// pc 永远 4 字节对齐，取指由顶层通过 DPI-C 的 pmem_read(pc) 完成。

module IFU (
    input  wire        clk,
    input  wire        rst,
    input  wire        jump_en,
    input  wire [31:0] jump_target,
    input  wire        stop_now,
    output wire [31:0] pc,
    output wire [31:0] pc_plus4
);

    wire [31:0] next_pc;   // 下一拍 PC：顺序走 pc+4，跳转走 jump_target
    wire unused_cout;
    mux #(.WIDTH(32), .NR_IN(2)) u_target_sel (
        .din({jump_target, pc_plus4}),
        .sel(jump_en),
        .dout(next_pc)
    );

    // PC 寄存器：trap 或 ebreak 时 stop_now 为 1，PC 保持不动
    Reg #(.WIDTH(32), .RESET_VAL(32'h8000_0000)) u_PC (
        .din(next_pc),
        .dout(pc),
        .wen(~stop_now),
        .rst(rst),
        .clk(clk)
    );

    // 顺序执行的下一地址
    adder #(.WIDTH(32)) u_pc_plus4 (
        .a(pc),
        .b(32'd4),
        .sum(pc_plus4),
        .cin(1'b0),
        .cout(unused_cout)
    );

endmodule
