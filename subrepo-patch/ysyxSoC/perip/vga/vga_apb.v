`timescale 1ns/1ns

module VGA_APB (
    input  wire        clock,
    input  wire        reset,
    input  wire [31:0] in_paddr,
    input  wire        in_psel,
    input  wire        in_penable,
    input  wire        in_pwrite,
    input  wire [31:0] in_pwdata,
    input  wire [3:0]  in_pstrb,
    output wire        in_pready,
    output wire [31:0] in_prdata,
    output wire        in_pslverr,

    output wire [7:0]  vga_r,
    output wire [7:0]  vga_g,
    output wire [7:0]  vga_b,
    output wire        vga_hsync,
    output wire        vga_vsync,
    output wire        vga_valid
);

    localparam H_TOTAL = 800;
    localparam V_TOTAL = 525;

    reg [9:0] x_cnt;
    reg [9:0] y_cnt;

    always @(posedge clock) begin
        if (reset)
            x_cnt <= 10'd1;
        else if (x_cnt == H_TOTAL)
            x_cnt <= 10'd1;
        else
            x_cnt <= x_cnt + 10'd1;
    end

    always @(posedge clock) begin
        if (reset)
            y_cnt <= 10'd1;
        else if (x_cnt == H_TOTAL) begin
            if (y_cnt == V_TOTAL)
                y_cnt <= 10'd1;
            else
                y_cnt <= y_cnt + 10'd1;
        end
    end

    wire h_valid = (x_cnt > 10'd144) && (x_cnt <= 10'd784);
    wire v_valid = (y_cnt > 10'd35) && (y_cnt <= 10'd515);
    wire valid   = h_valid && v_valid;

    wire [9:0] h_addr = h_valid ? (x_cnt - 10'd145) : 10'd0;
    wire [9:0] v_addr_full = v_valid ? (y_cnt - 10'd36) : 10'd0;
    wire [8:0] v_addr = v_addr_full[8:0];

    assign vga_hsync = (x_cnt > 10'd96);
    assign vga_vsync = (y_cnt > 10'd2);
    assign vga_valid = valid;

    reg [7:0] frame_mem [0:2399];

    wire [7:0] src_x = h_addr[9:2];
    wire [6:0] src_y = v_addr[8:2];
    wire [15:0] pix_idx_full = {1'b0, src_y, 7'b0} + {3'b0, src_y, 5'b0} + {8'b0, src_x};
    wire [14:0] pix_idx = pix_idx_full[14:0];
    wire [11:0] byte_idx = pix_idx[14:3];
    wire [7:0] frame_byte = frame_mem[byte_idx];
    wire [7:0] frame_shift = frame_byte >> (7 - pix_idx[2:0]);
    wire       frame_bit = frame_shift[0];
    wire       pixel_on = frame_bit;

    assign vga_r = (valid && pixel_on) ? 8'hFF : 8'h00;
    assign vga_g = vga_r;
    assign vga_b = vga_r;

    wire wr = in_psel && in_penable && in_pwrite;
    wire [15:0] waddr = in_paddr[15:0];
    wire [13:0] word_idx = waddr[15:2];
    wire [11:0] byte_base = {word_idx[9:0], 2'b00};

    always @(posedge clock) begin
        if (wr && word_idx < 14'd600) begin
            if (in_pstrb[0]) frame_mem[byte_base + 12'd0] <= in_pwdata[7:0];
            if (in_pstrb[1]) frame_mem[byte_base + 12'd1] <= in_pwdata[15:8];
            if (in_pstrb[2]) frame_mem[byte_base + 12'd2] <= in_pwdata[23:16];
            if (in_pstrb[3]) frame_mem[byte_base + 12'd3] <= in_pwdata[31:24];
        end
    end

    assign in_pready = in_psel && in_penable;
    assign in_prdata = 32'b0;
    assign in_pslverr = 1'b0;

endmodule
