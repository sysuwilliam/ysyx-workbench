`timescale 1ns/1ns

// sCPU —— sISA 单周期处理器顶层
//
// 用途
//   按 sISA 连接取指、译码、寄存器堆、执行和 io 设备；
//   复位后默认停机，每按一次 btn 开始新一轮计算。
//
// 接口
//   端口
//     clk/rst     时钟与同步复位
//     hold        暂停请求，为 1 时 PC/GPR/io 都不更新
//     btn         启动/重算按钮，高电平有效
//     sw          拨码开关输入
//     led         LED 锁存值
//     hex         Hex 锁存值，供 testbench 检查
//     seg0/seg1/seg2 个位/十位/百位七段段码，接 NVBoard
//     seg_off     未使用的六位数码管，恒为全灭
//     dbg_pc      当前 PC
//     dbg_instr   当前指令
//     dbg_r0~r3   四个 GPR 的当前值
//     dbg_exec    当前拍确实执行了一条指令
//
// 使用方法
//   rst 至少保持一个上升沿完成复位；复位后 run=0，PC、GPR、LED/Hex 都不更新。
//   btn 的上升沿产生一个 start 脉冲，把 PC、GPR、io 复位到初值并锁存 run=1，
//   所以每按一次都会从地址 0 重新算一轮；一轮结束后再按同样会重算。
//   rst 会把 run 清 0。sw 接拨码，led/seg0/seg1 接 NVBoard。
//   hold 供外部的指令跟踪模块在串口发送期间拉住 CPU；dbg_exec 在该模块里
//   作为“这一拍执行了一条指令”的指示。
module sCPU (
    input  wire       clk,
    input  wire       rst,
    input  wire       hold,
    input  wire       btn,
    input  wire [7:0] sw,
    output wire [7:0] led,
    output wire [7:0] hex,
    output wire [7:0] seg0,
    output wire [7:0] seg1,
    output wire [7:0] seg2,
    output wire [7:0] seg_off,
    output wire [7:0] dbg_pc,
    output wire [7:0] dbg_instr,
    output wire [7:0] dbg_r0,
    output wire [7:0] dbg_r1,
    output wire [7:0] dbg_r2,
    output wire [7:0] dbg_r3,
    output wire       dbg_exec
);

    wire run;
    wire run_eff;
    wire start;
    wire btn_d;
    wire rst_all;
    wire gpr_wen_run;
    wire io_en_run;

    wire [7:0] pc;
    wire [7:0] instr;

    wire       add_en;
    wire       io_en;
    wire       li_en;
    wire       bner0_en;
    wire [1:0] raddr1;
    wire [1:0] raddr2;
    wire [1:0] waddr;
    wire       gpr_wen;
    wire [7:0] imm8;
    wire [3:0] offset;
    wire       io_dir;
    wire [2:0] idx;

    wire [7:0] rdata1;
    wire [7:0] rdata2;
    wire [7:0] r0;
    wire [7:0] r1;
    wire [7:0] r2;
    wire [7:0] r3;

    wire [7:0] wdata;
    wire       branch_taken;
    wire [7:0] io_in;

    Reg #(.WIDTH(1), .RESET_VAL(1'b0)) u_btn_d (
        .clk(clk),
        .rst(rst),
        .wen(1'b1),
        .din(btn),
        .dout(btn_d)
    );

    assign start = btn & ~btn_d;
    assign rst_all = rst | start;

    Reg #(.WIDTH(1), .RESET_VAL(1'b0)) u_run (
        .clk(clk),
        .rst(rst),
        .wen(start),
        .din(1'b1),
        .dout(run)
    );

    assign run_eff = run & ~hold;
    assign gpr_wen_run = gpr_wen & run_eff;
    assign io_en_run = io_en & run_eff;
    assign dbg_exec = run_eff & ~rst_all;

    PC u_pc (
        .clk(clk),
        .rst(rst_all),
        .en(run_eff),
        .offset(offset),
        .branch_taken(branch_taken),
        .pc(pc)
    );

    ROM u_rom (
        .addr(pc),
        .instr(instr)
    );

    Instruction_Decoder u_decoder (
        .instr(instr),
        .add_en(add_en),
        .io_en(io_en),
        .li_en(li_en),
        .bner0_en(bner0_en),
        .raddr1(raddr1),
        .raddr2(raddr2),
        .waddr(waddr),
        .gpr_wen(gpr_wen),
        .imm8(imm8),
        .offset(offset),
        .io_dir(io_dir),
        .idx(idx)
    );

    GPR u_gpr (
        .clk(clk),
        .rst(rst_all),
        .raddr1(raddr1),
        .raddr2(raddr2),
        .rdata1(rdata1),
        .rdata2(rdata2),
        .waddr(waddr),
        .wdata(wdata),
        .wen(gpr_wen_run),
        .r0(r0),
        .r1(r1),
        .r2(r2),
        .r3(r3)
    );

    exec u_exec (
        .add_en(add_en),
        .li_en(li_en),
        .bner0_en(bner0_en),
        .rdata1(rdata1),
        .rdata2(rdata2),
        .imm8(imm8),
        .io_in(io_in),
        .wdata(wdata),
        .branch_taken(branch_taken)
    );

    io_dev u_io (
        .clk(clk),
        .rst(rst_all),
        .io_en(io_en_run),
        .io_dir(io_dir),
        .idx(idx),
        .rdata2(rdata2),
        .sw(sw),
        .io_in(io_in),
        .led(led),
        .hex(hex),
        .seg0(seg0),
        .seg1(seg1),
        .seg2(seg2)
    );

    assign seg_off = 8'hff;

    assign dbg_pc = pc;
    assign dbg_instr = instr;
    assign dbg_r0 = r0;
    assign dbg_r1 = r1;
    assign dbg_r2 = r2;
    assign dbg_r3 = r3;

endmodule
