// ============================================================================
// clkgen —— 通用分频器
//
// 把 clkin 分频成约 clk_freq 的方波：countlimit = 50000000 / 2 / clk_freq，
// 其中 50 MHz 是 clkin 的标称频率。例化时覆盖 clk_freq：
//   clkgen #(25000000) u_vgaclk(.clkin(clk), .rst(rst),
//                               .clken(1'b1), .clkout(vga_clk));
// rst 为高时计数清零、输出低电平；clken 为 0 时计数和输出保持。
// ============================================================================
module clkgen #(
    clk_freq   = 1000,
    countlimit = 50000000 / 2 / clk_freq
)
(
    input       clkin,
    input       rst,
    input       clken,
    output reg  clkout
);

    reg [31:0] clkcount;

    always @(posedge clkin) begin
        if (rst) begin
            clkcount <= 32'd0;
            clkout   <= 1'b0;
        end
        else if (clken) begin
            if (clkcount + 32'd1 >= countlimit) begin
                clkcount <= 32'd0;
                clkout   <= ~clkout;
            end
            else begin
                clkcount <= clkcount + 32'd1;
            end
        end
    end

endmodule
