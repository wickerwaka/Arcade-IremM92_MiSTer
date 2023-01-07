module objram(
    input clk,

    input [10:0] addr,
    input we,

    input [15:0] data,

    output [15:0] q,
    output [63:0] q64
);

reg [15:0] mem0[512];
reg [15:0] mem1[512];
reg [15:0] mem2[512];
reg [15:0] mem3[512];

reg [15:0] data1;
reg we1;
reg [10:0] addr1;

wire [1:0] col = addr1[1:0];
wire [8:0] row = addr1[10:2];

assign q64 = { mem3[row], mem2[row], mem1[row], mem0[row] };
assign q = col == 0 ? mem0[row] : col == 1 ? mem1[row] : col == 2 ? mem2[row] : mem3[row];

always_ff @(posedge clk) begin
    data1 <= data;
    addr1 <= addr;
    we1 <= we;

    if (we1) begin
        case(col)
        0: mem0[row] <= data1;
        1: mem1[row] <= data1;
        2: mem2[row] <= data1;
        3: mem3[row] <= data1;
        endcase
    end
end

endmodule