module v35(
    input clk,
    input ce, // 4x internal clock

    input reset,

    output mem_rd,
    output mem_wr,
    output [1:0] mem_be,
    output [19:0] mem_addr,
    output [15:0] mem_dout,
    input [15:0] mem_din
);

wire rd, wr;
wire prefetching;
wire [1:0] be;
wire [19:0] addr;
wire [15:0] dout, din;

reg irq = 0;
reg [7:0] irq_vec;
wire irq_ack;

reg ce_div; // 1/4 ce
always_ff @(posedge clk) begin
    reg [1:0] cnt;

    ce_div <= 0;
    if (ce) begin
        cnt <= cnt + 2'd1;
        ce_div <= &cnt;
    end
end

typedef enum bit [7:0] {
    PMC1 = 8'h0a,

    EXIC0 = 8'h4c,
    EXIC1 = 8'h4d,
    EXIC2 = 8'h4e,

    RFM = 8'he1,
    WTC_LO = 8'he8,
    WTC_HI = 8'he9,
    PRC = 8'heb,
    IDB = 8'hff
} e_sfr;

reg [15:0] internal_din;
reg [7:0] iram[256];
reg [7:0] sfr[256];

wire internal_rq = ~prefetching && ( addr[19:9] == { sfr[IDB], 3'b111 } || addr[19:0] == 20'hfffff );
wire internal_ram_rq = internal_rq & ~addr[8];
wire sfr_area_rq = internal_rq & addr[8];

assign mem_rd = rd & ~internal_rq;
assign mem_wr = wr & ~internal_rq;
assign mem_be = be;
assign mem_addr = addr;
assign mem_dout = dout;
assign din = internal_rq ? internal_din : mem_din;

always_ff @(posedge clk) begin
    if (reset) begin
        sfr[IDB] <= 8'hff;
    end else if (ce) begin
        if (sfr_area_rq) begin
            if (wr) begin
                if (be[0]) sfr[addr[7:0]] <= dout[7:0];
                if (be[1]) sfr[addr[7:0] + 8'd1] <= dout[15:8];
            end else if (rd) begin
                internal_din <= { sfr[addr[7:0] + 8'd1], sfr[addr[7:0]] };
            end
        end else if (internal_ram_rq) begin
            if (wr) begin
                if (be[0]) iram[addr[7:0]] <= dout[7:0];
                if (be[1]) iram[addr[7:0] + 8'd1] <= dout[15:8];
            end else if (rd) begin
                internal_din <= { iram[addr[7:0] + 8'd1], iram[addr[7:0]] };
            end
        end
    end
end

v30_core core(
    .clk(clk),
    .ce(ce_div),
    .ce_4x(ce),
    .reset(reset),
    .turbo(1),
    .SLOWTIMING(),

    .cpu_idle(),
    .cpu_halt(),
    .cpu_irqrequest(),
    .cpu_prefix(),
    .cpu_done(),
         
    .bus_read(rd),
    .bus_write(wr),
    .bus_prefetch(prefetching),
    .bus_be(be),
    .bus_addr(addr),
    .bus_datawrite(dout),
    .bus_dataread(din),
         
    .irqrequest_in(irq),
    .irqvector_in(irq_vec),
    .irqrequest_ack(irq_ack),

    // TODO - m92 doesn't use IO ports, but we want to merge these with data anyway
    .RegBus_Din(),
    .RegBus_Adr(),
    .RegBus_wren(),
    .RegBus_rden(),
    .RegBus_Dout(0)
);

endmodule