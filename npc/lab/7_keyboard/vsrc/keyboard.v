// ============================================================================
// keyboard —— 实验七顶层
//
// ps2_keyboard → key_ctrl → scancode2ascii → display
//
// 数码管：seg0/seg1 键码，seg2/seg3 ASCII，seg4/seg5 次数
// 调试 LED：led[0]=ready，led[1]=overflow
// ============================================================================
module keyboard (
    input  wire        clk,
    input  wire        rst,
    input  wire        ps2_clk,
    input  wire        ps2_data,
    output wire [15:0] led,
    output wire [7:0]  seg0,
    output wire [7:0]  seg1,
    output wire [7:0]  seg2,
    output wire [7:0]  seg3,
    output wire [7:0]  seg4,
    output wire [7:0]  seg5
);

    wire clrn;
    assign clrn = ~rst;

    wire [7:0] data;
    wire       ready;
    wire       nextdata_n;
    wire       overflow;

    wire [7:0] code;
    wire [7:0] count;
    wire       show;

    wire [7:0] ascii;
    wire       ascii_valid;

    ps2_keyboard u_ps2 (
        .clk(clk),
        .clrn(clrn),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .nextdata_n(nextdata_n),
        .data(data),
        .ready(ready),
        .overflow(overflow)
    );

    key_ctrl u_ctrl (
        .clk(clk),
        .clrn(clrn),
        .data(data),
        .ready(ready),
        .nextdata_n(nextdata_n),
        .code(code),
        .count(count),
        .show(show)
    );

    scancode2ascii u_lut (
        .code(code),
        .ascii(ascii),
        .valid(ascii_valid)
    );

    display u_disp (
        .code(code),
        .ascii(ascii),
        .ascii_valid(ascii_valid),
        .count(count),
        .show(show),
        .seg0(seg0),
        .seg1(seg1),
        .seg2(seg2),
        .seg3(seg3),
        .seg4(seg4),
        .seg5(seg5)
    );

    assign led[0]      = ready;
    assign led[1]      = overflow;
    assign led[15:2]   = 14'd0;

endmodule
