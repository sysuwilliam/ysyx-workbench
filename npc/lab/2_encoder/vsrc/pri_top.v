`timescale 1ns/1ns

module pri_top (
    input  wire [8:0]  sw,
    output wire [15:0] led,
    output wire [7:0]  seg
);

    wire [2:0] code;      
    wire       valid;     
    wire [6:0] seg_lit;  

    pri_enc u_enc (
        .en    (sw[8]),
        .x     (sw[7:0]),
        .y     (code),
        .valid (valid)
    );

    bcd u_bcd (
        .bin ({1'b0, code}),
        .seg (seg_lit)
    );

    wire lit = sw[8] & (|sw[7:0]);

    wire [6:0] seg_en = lit ? seg_lit : 7'b111_1111;

    assign led = {11'd0, valid, 1'b0, code & {3{lit}}};

    assign seg = {seg_en[0], seg_en[1], seg_en[2], seg_en[3],
                  seg_en[4], seg_en[5], seg_en[6], 1'b1};

endmodule
