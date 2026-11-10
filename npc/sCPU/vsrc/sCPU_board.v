`timescale 1ns/1ns

// sCPU_board —— NVBoard 顶层
//
// 用途
//   sCPU 加指令跟踪与 UART 发送，上板时每执行一条指令打印一行 "PC:INSTR"。
//
// 接口
//   参数
//     GAP  每行之后的空拍数，用来放慢显示节奏；越小跑得越快
//   端口
//     clk/rst/btn/sw  与 sCPU 相同
//     led/seg0/seg1/seg2/seg_off  与 sCPU 相同
//     uart_tx        串口输出，接 NVBoard 的 UART_TX
//
// 使用方法
//   trace 的 busy 接回 sCPU 的 hold，发送一行期间 CPU 暂停；
//   一行发送完后按 GAP 等待，再执行下一条指令。
module sCPU_board #(
    parameter GAP = 150000
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       btn,
    input  wire [7:0] sw,
    output wire [7:0] led,
    output wire [7:0] seg0,
    output wire [7:0] seg1,
    output wire [7:0] seg2,
    output wire [7:0] seg_off,
    output wire       uart_tx
);

    wire [7:0] unused_hex;
    wire [7:0] unused_r0;
    wire [7:0] unused_r1;
    wire [7:0] unused_r2;
    wire [7:0] unused_r3;
    wire [7:0] unused_pc;
    wire [7:0] dbg_instr;
    wire       dbg_exec;
    wire       trace_busy;

    sCPU u_cpu (
        .clk(clk),
        .rst(rst),
        .hold(trace_busy),
        .btn(btn),
        .sw(sw),
        .led(led),
        .hex(unused_hex),
        .seg0(seg0),
        .seg1(seg1),
        .seg2(seg2),
        .seg_off(seg_off),
        .dbg_pc(unused_pc),
        .dbg_instr(dbg_instr),
        .dbg_r0(unused_r0),
        .dbg_r1(unused_r1),
        .dbg_r2(unused_r2),
        .dbg_r3(unused_r3),
        .dbg_exec(dbg_exec)
    );

    trace #(.GAP(GAP)) u_trace (
        .clk(clk),
        .rst(rst),
        .exec(dbg_exec),
        .instr(dbg_instr),
        .uart_tx(uart_tx),
        .busy(trace_busy)
    );

endmodule
