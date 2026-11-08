`timescale 1ns/1ns

// io_dev —— sISA 的 io 设备与 NVBoard 输出
//
// 用途
//   实现拨码开关输入、LED 与三位十进制数码管输出，并直接给出 NVBoard 段码；
//   数码管在写出结果之前保持全灭。
//
// 接口
//   端口
//     clk/rst   时钟与同步复位
//     io_en     io 指令使能
//     io_dir    1 输出、0 输入
//     idx       设备编号，000 为 SW/LED，001 为 DEC
//     rdata2    要输出的寄存器值
//     sw        拨码开关输入
//     io_in     输入数据，接写回选择
//     led       8 位 LED 锁存值
//     hex       8 位结果锁存值，供 testbench 检查
//     seg0      个位段码
//     seg1      十位段码
//     seg2      百位段码
//
// 使用方法
//   io 输出写 LED 或 DEC 任一设备时，两个显示寄存器同时更新，
//   保证 LED 和数码管始终显示同一个值；输入只有拨码开关，io_in 恒等于 sw。
//   hex 先经 bin2bcd 转成三位 BCD，再按十进制显示；
//   百位和十位的前导零熄灭，例如 5 显示 "5"、55 显示 "55"、120 显示 "120"。
//   seg0/seg1/seg2 每 8 位按 (A,B,C,D,E,F,G,DP) 排列、低电平点亮。
module io_dev (
    input  wire       clk,
    input  wire       rst,
    input  wire       io_en,
    input  wire       io_dir,
    input  wire [2:0] idx,
    input  wire [7:0] rdata2,
    input  wire [7:0] sw,
    output wire [7:0] io_in,
    output wire [7:0] led,
    output wire [7:0] hex,
    output wire [7:0] seg0,
    output wire [7:0] seg1,
    output wire [7:0] seg2
);

    wire led_wen = io_en & io_dir & (idx == 3'd0);
    wire hex_wen = io_en & io_dir & (idx == 3'd1);
    wire out_wen = led_wen | hex_wen;

    Reg #(.WIDTH(8), .RESET_VAL(8'd0)) u_led (
        .clk(clk),
        .rst(rst),
        .wen(out_wen),
        .din(rdata2),
        .dout(led)
    );

    Reg #(.WIDTH(8), .RESET_VAL(8'd0)) u_hex (
        .clk(clk),
        .rst(rst),
        .wen(out_wen),
        .din(rdata2),
        .dout(hex)
    );

    assign io_in = sw;

    wire disp_valid;

    Reg #(.WIDTH(1), .RESET_VAL(1'b0)) u_valid (
        .clk(clk),
        .rst(rst),
        .wen(out_wen),
        .din(1'b1),
        .dout(disp_valid)
    );

    wire [11:0] bcd;

    bin2bcd #(.BIN_W(8), .DIGITS(3)) u_bcd (
        .bin(hex),
        .bcd(bcd)
    );

    wire [6:0] lit0;
    wire [6:0] lit1;
    wire [6:0] lit2;

    seg7 #(.ACTIVE_LOW(1)) u_seg0 (
        .bin(bcd[3:0]),
        .seg(lit0)
    );

    seg7 #(.ACTIVE_LOW(1)) u_seg1 (
        .bin(bcd[7:4]),
        .seg(lit1)
    );

    seg7 #(.ACTIVE_LOW(1)) u_seg2 (
        .bin(bcd[11:8]),
        .seg(lit2)
    );

    function [7:0] pack;
        input [6:0] s;
        begin
            pack = {s[0], s[1], s[2], s[3], s[4], s[5], s[6], 1'b1};
        end
    endfunction

    wire show_tens = (hex >= 8'd10);
    wire show_hund = (hex >= 8'd100);

    assign seg0 = disp_valid ? pack(lit0) : 8'hff;
    assign seg1 = (disp_valid && show_tens) ? pack(lit1) : 8'hff;
    assign seg2 = (disp_valid && show_hund) ? pack(lit2) : 8'hff;

endmodule
