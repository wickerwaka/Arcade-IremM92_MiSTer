module ga23_layer(
    input clk,
    input ce_pix,

    input NL,

    // io registers
    input [9:0] x_ofs,
    input [9:0] y_ofs,
    input [7:0] control,

    // position
    input [9:0] x_base,
    input [9:0] y,
    input [9:0] rowscroll,

    // vram address for current tile
    output [14:0] vram_addr,

    // 
    input load,
    input [10:0] attrib,
    input [15:0] index,

    output [1:0] prio_out,
    output [10:0] color_out,

    input [31:0] sdr_data,
    output reg [20:0] sdr_addr,
    output reg sdr_req,
    input sdr_rdy
);

wire [14:0] vram_base = { control[1:0], 13'd0 };
wire wide = control[2];
wire enabled = ~control[4];
wire en_rowscroll = control[6];
wire [9:0] x = x_base + ( en_rowscroll ? rowscroll : x_ofs );
assign vram_addr = vram_base + (wide ? {1'b0, y[8:3], x[9:3], 1'b0} : {2'b00, y[8:3], x[8:3], 1'b0});

reg [3:0] cnt;

reg [1:0] prio;
reg [6:0] palette;
reg flip_x;
wire flip_y = attrib[10];
reg [2:0] offset;

always_ff @(posedge clk) begin
    sdr_req <= 0;

    if (ce_pix) begin
        cnt <= cnt + 4'd1;
        if (load) begin
            cnt <= 4'd0;
            sdr_addr <= { index, flip_y ? ~y[2:0] : y[2:0], 2'b00 };
            sdr_req <= 1;
            palette <= attrib[6:0];
            prio <= attrib[8:7];
            flip_x <= attrib[9];
            offset <= x[2:0];
        end
    end
end

wire [1:0] shift_prio_out;
wire [10:0] shift_color_out;

ga23_shifter shifter(
    .clk(clk),
    .ce_pix(ce_pix),

    .offset(offset),

    .load(cnt == 4'd3),
    .reverse(flip_x),
    .row(sdr_data),
    .palette(palette),
    .prio(prio),

    .color_out(shift_color_out),
    .prio_out(shift_prio_out)
);

assign color_out = enabled ? shift_color_out : 11'd0;
assign prio_out = enabled ? shift_prio_out : 2'b00;

endmodule