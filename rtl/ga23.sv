module GA23(
    input clk,
    input clk_ram,

    input ce,

    input reset,

    input mem_cs,
    input mem_wr,
    input mem_rd,
    input io_wr,

    output reg busy,

    input [15:0] addr,
    input [15:0] cpu_din,
    output reg [15:0] cpu_dout,
    
    output reg [14:0] vram_addr,
    input [15:0] vram_din,
    output reg [15:0] vram_dout,
    output reg vram_we,

    input [63:0] sdr_data,
    output [24:0] sdr_addr,
    output sdr_req,
    input sdr_rdy,

    output vblank,
    output vsync,
    output hblank,
    output hsync,

    output hpulse,
    output vpulse,

    output hint,

    output reg [10:0] color_out,
    output reg [1:0] prio_out
);

wire [20:0] rom_addr[3];
wire [31:0] rom_data[3];
wire        rom_req[3];
wire        rom_rdy[3];

ga23_sdram sdram(
    .clk(clk),
    .clk_ram(clk_ram),

    .addr_a(rom_addr[0]),
    .data_a(rom_data[0]),
    .req_a(rom_req[0]),
    .rdy_a(rom_rdy[0]),

    .addr_b(rom_addr[1]),
    .data_b(rom_data[1]),
    .req_b(rom_req[1]),
    .rdy_b(rom_rdy[1]),

    .addr_c(rom_addr[2]),
    .data_c(rom_data[2]),
    .req_c(rom_req[2]),
    .rdy_c(rom_rdy[2]),

    .sdr_addr(sdr_addr),
    .sdr_data(sdr_data),
    .sdr_req(sdr_req),
    .sdr_rdy(sdr_rdy)
);

//// MEMORY ACCESS
reg [2:0] mem_cyc;
reg busy_we;

reg [9:0] x_ofs[3], y_ofs[3];
reg [7:0] control[3];
reg [9:0] hint_line;

wire [14:0] layer_vram_addr[3];
reg layer_load[3];
wire [1:0] layer_prio[3];
wire [10:0] layer_color[3];
reg [15:0] vram_latch;

always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        mem_cyc <= 0;
        busy <= 0;
        vram_we <= 0;
        
        // layer regs
        x_ofs[0] <= 10'd0; x_ofs[1] <= 10'd0; x_ofs[2] <= 10'd0;
        y_ofs[0] <= 10'd0; y_ofs[1] <= 10'd0; y_ofs[2] <= 10'd0;
        control[0] <= 8'd0; control[1] <= 8'd0; control[2] <= 8'd0;
        hint_line <= 10'd0;

    end else begin

        if (mem_cs & (mem_rd | mem_wr)) begin
            busy <= 1;
            busy_we <= mem_wr;
        end
        vram_we <= 0;
        if (ce) begin
            layer_load[0] <= 0; layer_load[1] <= 0; layer_load[2] <= 0;

            mem_cyc <= mem_cyc + 3'd1;
            case(mem_cyc)
            3'd0: begin
                vram_addr <= layer_vram_addr[0];
            end
            3'd1: begin
                vram_addr[0] <= 1;
                vram_latch <= vram_din;
                layer_load[0] <= 1;
            end
            3'd2: begin
                vram_addr <= layer_vram_addr[1];
            end
            3'd3: begin
                vram_addr[0] <= 1;
                vram_latch <= vram_din;
                layer_load[1] <= 1;
            end
            3'd4: begin
                vram_addr <= layer_vram_addr[2];
            end
            3'd5: begin
                vram_addr[0] <= 1;
                vram_latch <= vram_din;
                layer_load[2] <= 1;
            end
            3'd6: begin
                vram_addr <= addr[15:1];
                vram_we <= busy_we;
                vram_dout <= cpu_din;
            end
            3'd7: begin
                if (busy) begin
                    busy <= 0;
                    busy_we <= 0;
                    cpu_dout <= vram_din;
                end
            end
            endcase

            if (|layer_color[0][3:0]) begin
                color_out <= layer_color[0];
                prio_out <= layer_prio[0];
            end else if (|layer_color[1][3:0]) begin
                color_out <= layer_color[1];
                prio_out <= layer_prio[1];
            end else begin
                color_out <= layer_color[2];
                prio_out <= layer_prio[2];
            end
        end

        if (io_wr) begin
            case(addr[7:0])
            'h80: y_ofs[0][7:0] <= cpu_din[7:0];
            'h81: y_ofs[0][9:8] <= cpu_din[1:0];
            'h84: x_ofs[0][7:0] <= cpu_din[7:0];
            'h85: x_ofs[0][9:8] <= cpu_din[1:0];
            
            'h88: y_ofs[1][7:0] <= cpu_din[7:0];
            'h89: y_ofs[1][9:8] <= cpu_din[1:0];
            'h8c: x_ofs[1][7:0] <= cpu_din[7:0];
            'h8d: x_ofs[1][9:8] <= cpu_din[1:0];
            
            'h90: y_ofs[2][7:0] <= cpu_din[7:0];
            'h91: y_ofs[2][9:8] <= cpu_din[1:0];
            'h94: x_ofs[2][7:0] <= cpu_din[7:0];
            'h95: x_ofs[2][9:8] <= cpu_din[1:0];

            'h98: control[0] <= cpu_din[7:0];
            'h9a: control[1] <= cpu_din[7:0];
            'h9c: control[2] <= cpu_din[7:0];

            'h9e: hint_line[7:0] <= cpu_din[7:0];
            'h9f: hint_line[9:8] <= cpu_din[1:0];
            endcase
        end
    end
end

//// VIDEO TIMING
reg [9:0] hcnt, vcnt;

assign hsync = hcnt < 10'd60 || hcnt > 10'd443;
assign hblank = hcnt < 10'd93 || hcnt > 10'd412;
assign vblank = vcnt > 10'd126 && vcnt < 10'd148;
assign vsync = vcnt > 10'd131 && vcnt < 10'd137;
assign hpulse = hcnt != 10'd40;
assign vpulse = (vcnt == 10'd136 && hcnt > 10'd252) || (vcnt == 10'd137 && hcnt < 10'd252);
assign hint = vcnt == hint_line;

always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        hcnt <= 10'd40;
        vcnt <= 10'd126;
    end else if (ce) begin
        hcnt <= hcnt + 10'd1;
        if (hcnt == 10'd463) begin
            hcnt <= 10'd40;
            vcnt <= vcnt + 10'd1;
            if (vcnt == 10'd387) begin
                vcnt <= 10'd126;
            end
        end
    end
end

//// LAYERS
generate
	genvar i;
    for(i = 0; i < 3; i = i + 1 ) begin : generate_layer
        ga23_layer layer(
            .clk(clk),
            .ce_pix(ce),

            .NL(0),

            .x_ofs(x_ofs[i]),
            .y_ofs(y_ofs[i]),
            .control(control[i]),

            .x_base({hcnt[9:3], 3'd0}),
            .y(y_ofs[i] + vcnt),
            .rowscroll(0),

            .vram_addr(layer_vram_addr[i]),

            .load(layer_load[i]),
            .attrib(vram_din),
            .index(vram_latch),

            .color_out(layer_color[i]),
            .prio_out(layer_prio[i]),

            .sdr_addr(rom_addr[i]),
            .sdr_data(rom_data[i]),
            .sdr_req(rom_req[i]),
            .sdr_rdy(rom_rdy[i])
        );
    end
endgenerate
endmodule

