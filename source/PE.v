module PE #(
    parameter integer DATA_WIDTH = 24,
    parameter integer BUFFER_DATA_WIDTH = 8,
    parameter integer MAC_SIZE = 512
)(
    input clk,
    input signed [BUFFER_DATA_WIDTH-1:0] up,
    input signed [BUFFER_DATA_WIDTH-1:0] left,
    input enable_b,
    input comp_enb,
    input reset_b,
    output reg signed [BUFFER_DATA_WIDTH-1:0] right,
    output reg signed [BUFFER_DATA_WIDTH-1:0] down,
    output reg signed [DATA_WIDTH-1:0] out_data
);

always @(posedge clk) begin
    if (comp_enb) begin
        out_data <= 0;
        down <= 0;
        right <= 0;
    end else begin
        if(~enable_b) begin
            out_data <= out_data + up * left;
            down <= up;
            right <= left;
        end
        if(reset_b) begin   //这个只能持续一个周期
            out_data <= 0;
            down <= 0;
            right <= 0;
        end
    end
end

endmodule

