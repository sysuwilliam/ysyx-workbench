// ============================================================================
// vga —— 640x480@60 的 VGA 时序控制器（讲义 Listing 26）
//
// 每个 pclk 周期扫过一个像素点。控制器只负责节拍和坐标：
//   一行 800 个像素：96 同步 + 48 消隐后沿 + 640 有效 + 16 消隐前沿
//   一帧 525 行：    2 同步 + 33 消隐后沿 + 480 有效 + 10 消隐前沿
// 25 MHz 像素时钟下，800 × 525 个周期约 16.8 ms，合 59.5 帧每秒。
//
// 计数器从 1 数起：x_cnt 是 1..800，y_cnt 是 1..525。
// hsync 和 vsync 是负脉冲，在同步区间为低，其余时间为高。
// valid 为高表示当前像素落在 640x480 的有效区内，
// 此时 h_addr / v_addr 是这一点的坐标（0 基）；其余时间两者清零。
// 消隐期间的颜色值在 NVBoard 里不会被采样；接真实 DAC 时
// 上层应在 valid 为低时把 vga_data 置 0。
//
// NVBoard 里 valid 直接接 VGA_BLANK_N 即可，模型按高电平采样；
// DE10 的 BLANK_N 是低有效，需要取反。
// ============================================================================
module vga (
    input           pclk,
    input           reset,
    input  [23:0]   vga_data,
    output [9:0]    h_addr,
    output [8:0]    v_addr,
    output          hsync,
    output          vsync,
    output          valid,
    output [7:0]    vga_r,
    output [7:0]    vga_g,
    output [7:0]    vga_b
);

    parameter h_frontporch = 96;
    parameter h_active     = 144;
    parameter h_backporch  = 784;
    parameter h_total      = 800;

    parameter v_frontporch = 2;
    parameter v_active     = 35;
    parameter v_backporch  = 515;
    parameter v_total      = 525;

    reg [9:0] x_cnt;
    reg [9:0] y_cnt;
    wire      h_valid;
    wire      v_valid;

    always @(posedge pclk) begin
        if (reset == 1'b1)
            x_cnt <= 10'd1;
        else if (x_cnt == h_total)
            x_cnt <= 10'd1;
        else
            x_cnt <= x_cnt + 10'd1;
    end

    always @(posedge pclk) begin
        if (reset == 1'b1)
            y_cnt <= 10'd1;
        else if (x_cnt == h_total) begin
            if (y_cnt == v_total)
                y_cnt <= 10'd1;
            else
                y_cnt <= y_cnt + 10'd1;
        end
    end

    assign hsync = (x_cnt > h_frontporch);
    assign vsync = (y_cnt > v_frontporch);

    assign h_valid = (x_cnt > h_active) & (x_cnt <= h_backporch);
    assign v_valid = (y_cnt > v_active) & (y_cnt <= v_backporch);
    assign valid   = h_valid & v_valid;

    assign h_addr = h_valid ? (x_cnt - 10'd145) : 10'd0;
    assign v_addr = v_valid ? 9'(y_cnt - 10'd36) : 9'd0;

    assign vga_r = vga_data[23:16];
    assign vga_g = vga_data[15:8];
    assign vga_b = vga_data[7:0];

endmodule
