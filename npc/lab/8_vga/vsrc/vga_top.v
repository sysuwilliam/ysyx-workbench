// ============================================================================
// vga_top —— 实验八静态图片显示顶层
//
// clkgen 把系统时钟二分频成 25 MHz 像素时钟，vga 用它产生扫描时序和坐标，
// vmem 按坐标给出 24 位颜色，直接送进 vga 的颜色输入。
// NVBoard 的 VGA 模型每个系统时钟取一个像素，所以 main.cpp 里要用
// nvboard_init(2) 告诉它每两个系统时钟取一次，和这里的二分频对齐。
// ============================================================================
module vga_top (
    input  wire       clk,
    input  wire       rst,
    output wire       VGA_HSYNC,
    output wire       VGA_VSYNC,
    output wire       VGA_BLANK_N,
    output wire [7:0] VGA_R,
    output wire [7:0] VGA_G,
    output wire [7:0] VGA_B
);

    wire        pclk;
    wire [9:0]  h_addr;
    wire [8:0]  v_addr;
    wire [23:0] color24;
    wire        valid;
    wire [7:0]  r8;
    wire [7:0]  g8;
    wire [7:0]  b8;

    clkgen #(25000000) u_clk (
        .clkin(clk),
        .rst(1'b0),
        .clken(1'b1),
        .clkout(pclk)
    );

    vga u_vga (
        .pclk(pclk),
        .reset(rst),
        .vga_data(color24),
        .h_addr(h_addr),
        .v_addr(v_addr),
        .hsync(VGA_HSYNC),
        .vsync(VGA_VSYNC),
        .valid(valid),
        .vga_r(r8),
        .vga_g(g8),
        .vga_b(b8)
    );

    vmem u_mem (
        .h_addr(h_addr),
        .v_addr(v_addr),
        .color(color24)
    );

    assign VGA_BLANK_N = valid;
    assign VGA_R = valid ? r8 : 8'd0;
    assign VGA_G = valid ? g8 : 8'd0;
    assign VGA_B = valid ? b8 : 8'd0;

endmodule
