`timescale 1ns/1ns

module CSR #(
    parameter [31:0] MARCHID = 32'd22040000
) (
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] csr_addr,
    input  wire        csr_we,
    input  wire [31:0] csr_wdata,
    output wire [31:0] csr_rdata
);

    localparam [11:0] CSR_MVENDORID = 12'hF11;
    localparam [11:0] CSR_MARCHID   = 12'hF12;
    localparam [11:0] CSR_MCYCLE    = 12'hB00;
    localparam [11:0] CSR_MCYCLEH   = 12'hB80;

    reg [63:0] mcycle;

    always @(posedge clk) begin
        if (rst)
            mcycle <= 64'd0;
        else if (csr_we && (csr_addr == CSR_MCYCLE))
            mcycle[31:0] <= mcycle[31:0] | csr_wdata;
        else if (csr_we && (csr_addr == CSR_MCYCLEH))
            mcycle[63:32] <= mcycle[63:32] | csr_wdata;
        else
            mcycle <= mcycle + 64'd1;
    end

    reg [31:0] rdata;

    always @(*) begin
        case (csr_addr)
            CSR_MVENDORID: rdata = 32'h79737978;
            CSR_MARCHID:   rdata = MARCHID;
            CSR_MCYCLE:    rdata = mcycle[31:0];
            CSR_MCYCLEH:   rdata = mcycle[63:32];
            default:       rdata = 32'b0;
        endcase
    end

    assign csr_rdata = rdata;

endmodule
