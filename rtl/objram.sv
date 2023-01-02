module objram(
    input clk,

    input [10:0] addr,
    input we,

    input [15:0] data,

    output reg [15:0] q,
    output reg [63:0] q64
);

reg [63:0] mem[512];

always_ff @(posedge clk) begin
    if (we) begin
        case(addr[1:0])
        0: mem[addr[10:2]][15:0] <= data;
        1: mem[addr[10:2]][31:16] <= data;
        2: mem[addr[10:2]][47:32] <= data;
        3: mem[addr[10:2]][63:48] <= data;
        endcase
    end

    q64 <= mem[addr[10:2]];
    case(addr[1:0])
    0: q <= mem[addr[10:2]][15:0];
    1: q <= mem[addr[10:2]][31:16];
    2: q <= mem[addr[10:2]][47:32];
    3: q <= mem[addr[10:2]][63:48];
    endcase
end

endmodule