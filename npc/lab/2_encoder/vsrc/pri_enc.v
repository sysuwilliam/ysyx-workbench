`timescale 1ns/1ns

module pri_enc (
    input  wire en,
    input  wire [7:0] x,
    output reg  [2:0] y,
    output wire valid
);

    assign valid = en & (|x);

    always @(*) begin
        if (!en) y = 3'd0;
        else begin
            casez (x)
                8'b1???????: y = 3'd7;
                8'b01??????: y = 3'd6;
                8'b001?????: y = 3'd5;
                8'b0001????: y = 3'd4;
                8'b00001???: y = 3'd3;
                8'b000001??: y = 3'd2;
                8'b0000001?: y = 3'd1;
                8'b00000001: y = 3'd0;
                8'b00000000: y = 3'd0; 
            endcase
        end
    end

endmodule
