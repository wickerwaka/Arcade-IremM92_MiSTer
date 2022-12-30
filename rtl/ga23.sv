module GA23(
    input clk,
    input ce,

    input reset,

    output vblank,
    output vsync,
    output hblank,
    output hsync,

    output hpulse,
    output vpulse
);

reg [9:0] hcnt, vcnt;

assign hsync = hcnt < 10'd20 || hcnt > 10'd403;
assign hblank = hcnt < 10'd53 || hcnt > 10'd372;
assign vblank = vcnt < 10'd22;
assign vsync = vcnt > 10'd5 && vcnt < 10'd11;
assign hpulse = hcnt != 10'd0;
assign vpulse = (vcnt == 10'd10 && hcnt > 10'd212) || (vcnt == 10'd11 && hcnt < 10'd212);

always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        hcnt <= 10'd0;
        vcnt <= 10'd0;
    end else if (ce) begin
        hcnt <= hcnt + 10'd1;
        if (hcnt == 10'd423) begin
            hcnt <= 10'd0;
            vcnt <= vcnt + 10'd1;
            if (vcnt == 10'd261) begin
                vcnt <= 10'd0;
            end
        end
    end
end


endmodule

