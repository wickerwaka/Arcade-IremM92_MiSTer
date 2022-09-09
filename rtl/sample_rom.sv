module sample_rom(
    input clk,

    input [15:0] sample_addr_in,
    input [1:0] sample_addr_wr,

    output [7:0] sample_data,
    input sample_inc,
    
    // ioctl
    input clk_bram,
    input bram_wr,
    input [7:0] bram_data,
    input [19:0] bram_addr,
    input bram_cs
);

/// SAMPLE ROM
dpramv #(.widthad_a(18)) sample_rom
(
    .clock_a(clk),
    .address_a(sample_addr),
    .q_a(sample_data),
    .wren_a(1'b0),
    .data_a(),

    .clock_b(clk_bram),
    .address_b(bram_addr[17:0]),
    .data_b(bram_data),
    .wren_b(bram_cs & bram_wr),
    .q_b()
);

reg [17:0] sample_addr = 0;

always_ff @(posedge clk) begin
    if (sample_inc) sample_addr <= sample_addr + 18'd1;

    if (sample_addr_wr[0]) sample_addr[12:0] <= {sample_addr_in[7:0], 5'd0};
    if (sample_addr_wr[1]) sample_addr[17:13] <= sample_addr_in[12:8];
end



endmodule