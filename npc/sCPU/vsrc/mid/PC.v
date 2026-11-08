`timescale 1ns/1ns

// PC —— 8 位程序计数器
//
// 用途
//   保存当前指令地址，每个时钟沿给出下一条指令地址。
//
// 接口
//   clk           时钟
//   rst           同步复位，复位后 pc = 0
//   en            运行使能，1 时每拍更新，0 时保持
//   offset        4 位补码分支偏移
//   branch_taken  1：下一条为 pc + offset；0：下一条为 pc + 1
//   pc            当前指令地址
//
// 使用方法
//   rst 至少保持一个上升沿完成复位；en 接顶层 run，run=0 时 PC 停住，
//   run=1 后每个上升沿把 branch_taken 与 offset 的结果装入 PC。
module PC (
    input  wire       clk,
    input  wire       rst,
    input  wire       en,
    input  wire [3:0] offset,
    input  wire       branch_taken,
    output wire [7:0] pc
);

    wire [7:0] pc_next;
    wire [7:0] offset_8;
    wire [7:0] pcadder_b;
    wire       unused_cout;

    ext #(.IN_W(4), .OUT_W(8), .SIGNED(1)) u_offset_ext (
        .din(offset),
        .dout(offset_8)
    );

    mux #(.WIDTH(8), .NR_IN(2)) u_next_sel (
        .din({offset_8, 8'd1}),
        .sel(branch_taken),
        .dout(pcadder_b)
    );

    Reg #(.WIDTH(8), .RESET_VAL(8'd0)) u_pc_reg (
        .clk(clk),
        .rst(rst),
        .wen(en),
        .din(pc_next),
        .dout(pc)
    );

    adder #(.WIDTH(8)) u_pc_adder (
        .cin(1'b0),
        .a(pc),
        .b(pcadder_b),
        .cout(unused_cout),
        .sum(pc_next)
    );

endmodule
