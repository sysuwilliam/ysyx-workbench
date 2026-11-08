`timescale 1ns/1ns

// uart_tx —— 8N1 串口发送器
//
// 用途
//   把 8 位字节按 8N1 格式串行输出，供 NVBoard 的 UART 终端显示。
//
// 接口
//   参数
//     CLK_PER_BIT  每个比特持续的时钟数，NVBoard 下取 16
//   端口
//     clk/rst   时钟与同步复位
//     send      发送请求，高电平一拍
//     data      待发送字节
//     tx        串行输出，空闲为 1
//     busy      发送中
//     done      停止位结束时报一拍
//
// 使用方法
//   send 拉高后的下一拍开始起始位；数据低位在前，8 位之后是停止位。
//   NVBoard 每 16 次 nvboard_update 采样一位，主循环每拍调用一次 update，
//   所以 CLK_PER_BIT 取 16。
module uart_tx #(
    parameter CLK_PER_BIT = 16
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       send,
    input  wire [7:0] data,
    output wire       tx,
    output wire       busy,
    output wire       done
);

    localparam S_IDLE  = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA  = 2'd2;
    localparam S_STOP  = 2'd3;

    localparam PHASE_W = (CLK_PER_BIT <= 2) ? 1 : $clog2(CLK_PER_BIT);
    localparam integer PHASE_LAST = CLK_PER_BIT - 1;

    wire [1:0]         state;
    wire [PHASE_W-1:0] phase;
    wire [2:0]         bitcnt;
    wire [7:0]         shift;

    wire state_is_idle = (state == S_IDLE);
    wire phase_last = (phase == PHASE_LAST[PHASE_W-1:0]);
    wire bit_advance = (state == S_DATA) && phase_last;

    assign tx = state_is_idle ? 1'b1 :
                (state == S_START) ? 1'b0 :
                (state == S_DATA) ? shift[0] : 1'b1;

    assign busy = !state_is_idle;
    assign done = (state == S_STOP) && phase_last;

    wire [1:0] state_next =
        send ? S_START :
        (state == S_START && phase_last) ? S_DATA :
        (state == S_DATA && phase_last && bitcnt == 3'd7) ? S_STOP :
        (state == S_STOP && phase_last) ? S_IDLE : state;

    Reg #(.WIDTH(2), .RESET_VAL(S_IDLE)) u_state (
        .clk(clk),
        .rst(rst),
        .wen(send || !state_is_idle),
        .din(state_next),
        .dout(state)
    );

    wire [PHASE_W-1:0] phase_next =
        send ? {PHASE_W{1'b0}} :
        (!state_is_idle && phase_last) ? {PHASE_W{1'b0}} :
        (!state_is_idle) ? phase + 1'b1 : phase;

    Reg #(.WIDTH(PHASE_W), .RESET_VAL({PHASE_W{1'b0}})) u_phase (
        .clk(clk),
        .rst(rst),
        .wen(send || !state_is_idle),
        .din(phase_next),
        .dout(phase)
    );

    wire [2:0] bitcnt_next = send ? 3'd0 :
                             bit_advance ? bitcnt + 3'd1 : bitcnt;

    Reg #(.WIDTH(3), .RESET_VAL(3'd0)) u_bitcnt (
        .clk(clk),
        .rst(rst),
        .wen(send || bit_advance),
        .din(bitcnt_next),
        .dout(bitcnt)
    );

    wire [7:0] shift_next = send ? data : {1'b0, shift[7:1]};

    Reg #(.WIDTH(8), .RESET_VAL(8'd0)) u_shift (
        .clk(clk),
        .rst(rst),
        .wen(send || bit_advance),
        .din(shift_next),
        .dout(shift)
    );

endmodule
