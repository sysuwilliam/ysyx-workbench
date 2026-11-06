// ============================================================================
// scancode2ascii —— 扫描码到 ASCII 的查找表
//
// 只收字符和数字键：0~9 给 0x30~0x39，A~Z 给 0x61~0x7A（无 Shift，小写）。
// 其余按键 valid=0，由显示模块决定中间两位怎么处理。
// ============================================================================
module scancode2ascii (
    input  [7:0] code,
    output reg [7:0] ascii,
    output reg       valid
);

    always @(*) begin
        valid = 1'b1;
        case (code)
            8'h45: ascii = 8'h30;
            8'h16: ascii = 8'h31;
            8'h1E: ascii = 8'h32;
            8'h26: ascii = 8'h33;
            8'h25: ascii = 8'h34;
            8'h2E: ascii = 8'h35;
            8'h36: ascii = 8'h36;
            8'h3D: ascii = 8'h37;
            8'h3E: ascii = 8'h38;
            8'h46: ascii = 8'h39;
            8'h1C: ascii = 8'h61;
            8'h32: ascii = 8'h62;
            8'h21: ascii = 8'h63;
            8'h23: ascii = 8'h64;
            8'h24: ascii = 8'h65;
            8'h2B: ascii = 8'h66;
            8'h34: ascii = 8'h67;
            8'h33: ascii = 8'h68;
            8'h43: ascii = 8'h69;
            8'h3B: ascii = 8'h6A;
            8'h42: ascii = 8'h6B;
            8'h4B: ascii = 8'h6C;
            8'h3A: ascii = 8'h6D;
            8'h31: ascii = 8'h6E;
            8'h44: ascii = 8'h6F;
            8'h4D: ascii = 8'h70;
            8'h15: ascii = 8'h71;
            8'h2D: ascii = 8'h72;
            8'h1B: ascii = 8'h73;
            8'h2C: ascii = 8'h74;
            8'h3C: ascii = 8'h75;
            8'h2A: ascii = 8'h76;
            8'h1D: ascii = 8'h77;
            8'h22: ascii = 8'h78;
            8'h35: ascii = 8'h79;
            8'h1A: ascii = 8'h7A;
            default: begin ascii = 8'h00; valid = 1'b0; end
        endcase
    end

endmodule
