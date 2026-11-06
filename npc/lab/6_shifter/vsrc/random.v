`timescale 1ns/1ns

module random (
    input  wire       clk_btn,
    input  wire       rst_btn,
    input  wire [7:0] seed,
    output wire [7:0] seg0,
    output wire [7:0] seg1,
    output wire [7:0] led
);

    reg [7:0] rng;

    always @(posedge clk_btn or posedge rst_btn) begin
        if (rst_btn)
            rng <= (seed == 8'h00) ? 8'h01 : seed;
        else if (rng == 8'h00)
            rng <= 8'h01;
        else
            rng <= {rng[4] ^ rng[3] ^ rng[2] ^ rng[0], rng[7:1]};
    end

    wire [6:0] hex_lo;
    wire [6:0] hex_hi;

    bcd u_hex_lo (.bin(rng[3:0]), .seg(hex_lo));
    bcd u_hex_hi (.bin(rng[7:4]), .seg(hex_hi));

    assign seg0 = {hex_lo[0], hex_lo[1], hex_lo[2], hex_lo[3],
                   hex_lo[4], hex_lo[5], hex_lo[6], 1'b1};
    assign seg1 = {hex_hi[0], hex_hi[1], hex_hi[2], hex_hi[3],
                   hex_hi[4], hex_hi[5], hex_hi[6], 1'b1};

    assign led = rng;

endmodule
