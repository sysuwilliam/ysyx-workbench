// ============================================================================
// bin2bcd —— 8 位二进制转两位十进制
//
// 用逐位移位加三（double dabble），不用除法器。
// 计数在 key_ctrl 里已经饱和在 99，这里再兜一次底。
// ============================================================================
module bin2bcd (
    input  [7:0] bin,
    output reg [3:0] tens,
    output reg [3:0] ones
);

    integer i;
    reg [7:0] value;
    reg [3:0] t;
    reg [3:0] o;

    always @(*) begin
        value = (bin > 8'd99) ? 8'd99 : bin;
        t = 4'd0;
        o = 4'd0;
        for (i = 7; i >= 0; i = i - 1) begin
            if (t >= 4'd5)
                t = t + 4'd3;
            if (o >= 4'd5)
                o = o + 4'd3;
            t = {t[2:0], o[3]};
            o = {o[2:0], value[i]};
        end
        tens = t;
        ones = o;
    end

endmodule
