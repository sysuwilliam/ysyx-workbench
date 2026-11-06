// ============================================================================
// display —— 六位数码管排布
//
//   seg5 seg4 : 按键总次数（十进制，两位）
//   seg3 seg2 : ASCII 码（十六进制，两位）
//   seg1 seg0 : 键码（十六进制，两位）
//
// 松开（show=0）时低四位全灭；ASCII 查不到（ascii_valid=0）时中间两位灭。
// 段码低电平点亮，端口 bit7~bit0 对应 A~G 和 DP。
// ============================================================================
module display (
    input  [7:0] code,
    input  [7:0] ascii,
    input        ascii_valid,
    input  [7:0] count,
    input        show,
    output [7:0] seg0,
    output [7:0] seg1,
    output [7:0] seg2,
    output [7:0] seg3,
    output [7:0] seg4,
    output [7:0] seg5
);

    wire [3:0] tens, ones;
    wire [6:0] code_l, code_h;
    wire [6:0] ascii_l, ascii_h;
    wire [6:0] cnt_l, cnt_h;

    bin2bcd u_cnt (.bin(count), .tens(tens), .ones(ones));

    bcd u_code_l  (.bin(code[3:0]),  .seg(code_l));
    bcd u_code_h  (.bin(code[7:4]),  .seg(code_h));
    bcd u_ascii_l (.bin(ascii[3:0]), .seg(ascii_l));
    bcd u_ascii_h (.bin(ascii[7:4]), .seg(ascii_h));
    bcd u_cnt_l   (.bin(ones),       .seg(cnt_l));
    bcd u_cnt_h   (.bin(tens),       .seg(cnt_h));

    function [7:0] pack;
        input [6:0] s;
        begin
            pack = {s[0], s[1], s[2], s[3], s[4], s[5], s[6], 1'b1};
        end
    endfunction

    assign seg0 = show ? pack(code_l) : 8'hFF;
    assign seg1 = show ? pack(code_h) : 8'hFF;
    assign seg2 = (show && ascii_valid) ? pack(ascii_l) : 8'hFF;
    assign seg3 = (show && ascii_valid) ? pack(ascii_h) : 8'hFF;
    assign seg4 = pack(cnt_l);
    assign seg5 = pack(cnt_h);

endmodule
