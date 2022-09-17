module palette(
    input clk,

    input bank,
    
    input [1:0] cpu_we,
    input [10:0] cpu_word_addr,
    input [15:0] word_in,
    output [15:0] word_out,

    input [9:0] color_index,
    output [4:0] red,
    output [4:0] green,
    output [4:0] blue
);

wire [15:0] color;
assign red = color[4:0];
assign green = color[9:5];
assign blue = color[14:10];

dpramv_16 #(.widthad_a(11)) ram(
    .clock_a(clk),
    .address_a({bank, cpu_word_addr[10:1]}),
    .q_a(word_out),
    .wren_a(cpu_we),
    .data_a(word_in),

    .clock_b(clk),
    .address_b(color_index),
    .q_b(color),
    .wren_b(2'b00),
    .data_b()
);

endmodule