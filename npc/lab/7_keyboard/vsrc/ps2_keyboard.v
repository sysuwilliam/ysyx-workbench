// ============================================================================
// ps2_keyboard —— PS/2 键盘接收器
//
// 作用：把键盘送来的两根线（ps2_clk 提供节拍、ps2_data 逐位给出数据）上
//       串行到达的 11 位帧，还原成 8 位扫描码字节，压进一个 8 字节的 FIFO。
//       本模块只负责“收到字节”，不判断这个字节是通码、断码还是前缀，
//       那部分语义交给上层的 key_ctrl。
//
// 一帧 11 位的格式（数据在 ps2_clk 的下降沿有效）：
//   bit0      起始位，固定为 0
//   bit1~bit8 数据位 D0~D7，低位先发
//   bit9      奇校验位，使 D0~D7 和校验位中 1 的总个数为奇数
//   bit10     停止位，固定为 1
//
// 与上层的握手：
//   ready      = 1 表示 FIFO 非空，此时 data 就是队头字节
//   nextdata_n = 0（只保持一拍）表示上层取走了一个字节，读指针前移
// ============================================================================
module ps2_keyboard (
    input        clk,
    input        clrn,
    input        ps2_clk,
    input        ps2_data,
    input        nextdata_n,
    output [7:0] data,
    output reg   ready,
    output reg   overflow
);

    reg [9:0] buffer;
    reg [7:0] fifo[7:0];
    reg [2:0] w_ptr, r_ptr;
    reg [3:0] count;
    reg [2:0] ps2_clk_sync;

    always @(posedge clk) begin
        ps2_clk_sync <= {ps2_clk_sync[1:0], ps2_clk};
    end

    wire sampling = ps2_clk_sync[2] & ~ps2_clk_sync[1];

    always @(posedge clk ) begin
        if (clrn == 0) begin
            count <= 0;
            w_ptr <= 0;
            r_ptr <= 0;
            overflow <= 0;
            ready <= 0;
        end
        else begin
            if (ready) begin
                if (nextdata_n == 1'b0) begin
                    r_ptr <= r_ptr + 3'b1;
                    if (w_ptr == r_ptr + 1'b1) ready <= 1'b0;
                end
            end
            if (sampling) begin
                if (count == 4'd10) begin
                    if ((buffer[0] == 0) && (ps2_data) && (^buffer[9:1])) begin
                        fifo[w_ptr] <= buffer[8:1];
                        w_ptr <= w_ptr + 3'b1;
                        ready <= 1'b1;
                        overflow <= overflow | (r_ptr == (w_ptr + 3'b1));
                    end
                    count <= 0;
                end else begin
                    buffer[count] <= ps2_data;
                    count <= count + 3'b1;
                end
            end
        end
    end

    assign data = fifo[r_ptr];

endmodule
