module palram(
    input clk,

    input ce_pix,

    input [15:0] vid_ctrl,
    input dma_busy,

    input [9:0] cpu_addr,

    input [12:0] ga21_addr,
    input        ga21_we,
    input        ga21_req,
    
    input [10:0] obj_color,
    input        obj_prio,
    input        obj_active,

    input [10:0] pf_color,
    input        pf_prio,

    input [15:0] din,
    output [15:0] dout,

    output reg [15:0] rgb_out
);

wire obj_pal_bank = ~vid_ctrl[13] & obj_prio;
wire obj_avail = ~vid_ctrl[7] & obj_active;

wire n_sela = ~dma_busy & (
    ( vid_ctrl[13] & obj_prio & obj_avail ) |
    ( ~obj_prio & pf_prio & obj_avail ) |
    ( ~vid_ctrl[13] & obj_prio & pf_prio & obj_avail ) |
    ( vid_ctrl[12] ) |
    ga21_req
);

wire selb = ~dma_busy & ~ga21_req & ~vid_ctrl[12];

wire [1:0] sel = { selb, ~n_sela };

wire [12:0] full_cpu_addr = { vid_ctrl[10:8], cpu_addr[9:0] };
wire [12:0] obj_addr = { vid_ctrl[15], obj_pal_bank, obj_color };
wire [12:0] pf_addr = { vid_ctrl[15], vid_ctrl[14], pf_color };

wire we = sel == 0 ? ga21_we : sel == 1 ? ga21_we : 0;
wire [12:0] selected_addr = sel == 0 ? full_cpu_addr :
                            sel == 1 ? ga21_addr :
                            sel == 2 ? obj_addr :
                            pf_addr;

singleport_unreg_ram #(.widthad(13), .width(16), .name("PALRAM")) ram
(
    .clock(clk),
    .address(selected_addr),
    .q(dout),
    .wren(we),
    .data(din)
);

always_ff @(posedge clk) begin
    if (ce_pix) rgb_out <= dout;
end

endmodule