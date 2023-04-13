module ga20_channel(
    input clk,
    input reset,

    input ce,
    input sample_ce,
    
    input cs,
    input rd,
    input wr,
    input [2:0] addr,
    input [7:0] din,
    output reg [7:0] dout,

    output reg [19:0] sample_addr,
    input sample_valid,
    input [7:0] sample_din,

    output reg [15:0] sample_out
);

reg step;
reg [5:0] volume;
reg [7:0] rate;
reg [19:0] start_addr, end_addr, cur_addr;
reg [1:0] play;
reg [8:0] rate_cnt;

reg [7:0] sample_s8;

reg play_set;

always_ff @(posedge clk) begin
    if (reset) begin
        volume <= 6'd00;
        play <= 2'd0;
        step <= 0;
        play_set <= 0;
        sample_s8 <= 8'h00;
    end else begin
        if (cs & rd) begin
            if (addr == 3'd7) dout <= { 7'd0, play[1] };
        end else if (cs & wr) begin
            case (addr)
            3'd0: start_addr[11:0] <= { din, 4'b0000 };
            3'd1: start_addr[19:12] <= din;
            3'd2: end_addr[11:0] <= { din, 4'b0000 };
            3'd3: end_addr[19:12] <= din;
            3'd4: rate <= din;
            3'd5: volume <= din[5:0];
            3'd6: begin
                play <= din[1:0];
                play_set <= din[1];
            end
            endcase
        end

        if (ce) begin
            step <= ~step;
            
            if (~step) begin
                // first cycle

                if (play_set) begin
                    cur_addr <= start_addr;
                    sample_addr <= start_addr;
                    play_set <= 0;
                    rate_cnt <= rate + 9'd2;
                end else begin
                    sample_addr <= cur_addr;
                    rate_cnt <= rate_cnt + 9'd2;
                end
            end else begin
                // second cycle
                if (~play_set & play[1] & sample_valid) begin
                    if (sample_din == 8'd0) begin
                        play[1] <= 0;
                        sample_s8 <= 8'h00;
                    end else begin
                        sample_s8 <= (sample_din - 8'h80);

                        if (rate_cnt[8]) begin
                            cur_addr <= cur_addr + 20'd1;
                            sample_addr <= cur_addr + 20'd8; // prefetch
                            rate_cnt <= rate_cnt + { 1'b1, rate };

                            if (cur_addr == end_addr) begin
                                if (play[0]) begin
                                    cur_addr <= start_addr;
                                    sample_addr <= start_addr;
                                end else begin
                                    sample_s8 <= 8'h00;
                                    play[1] <= 0;
                                end
                            end
                        end
                    end
                end 
            end
        end
    end
end

// apply attenuation after filtering
always_ff @(posedge clk) begin
    bit [7:0] vol_one;

    vol_one = { 2'd0, volume } + 8'd1; 

    sample_out <= $signed(sample_s8) * $signed(vol_one);
end


endmodule


module ga20(
    input clk,
    input reset,

    input ce,

    input cs,
    input rd,
    input wr,
    input [4:0] addr,
    input [7:0] din,
    output [7:0] dout,


    output reg sample_rd,
    output reg [19:0] sample_addr,
    input sample_valid,
    input [7:0] sample_din,

    output [15:0] sample_out
);

reg [2:0] step;

wire ce0 = step[2:1] == 2'd0;
wire ce1 = step[2:1] == 2'd1;
wire ce2 = step[2:1] == 2'd2;
wire ce3 = step[2:1] == 2'd3;

wire cs0 = cs && addr[4:3] == 2'd0;
wire cs1 = cs && addr[4:3] == 2'd1;
wire cs2 = cs && addr[4:3] == 2'd2;
wire cs3 = cs && addr[4:3] == 2'd3;

wire [7:0] dout0, dout1, dout2, dout3;

assign dout = cs0 ? dout0 : cs1 ? dout1 : cs2 ? dout2 : dout3;

wire [19:0] sample_addr0, sample_addr1, sample_addr2, sample_addr3;
wire [15:0] sample_out0, sample_out1, sample_out2, sample_out3;


ga20_channel ch0( .clk(clk), .reset(reset), .ce(ce & ce0), .sample_ce(ce), .cs(cs0), .rd(rd), .wr(wr), .addr(addr[2:0]), .din(din), .dout(dout0), .sample_addr(sample_addr0), .sample_valid(sample_valid), .sample_din(sample_din), .sample_out(sample_out0));
ga20_channel ch1( .clk(clk), .reset(reset), .ce(ce & ce1), .sample_ce(ce), .cs(cs1), .rd(rd), .wr(wr), .addr(addr[2:0]), .din(din), .dout(dout1), .sample_addr(sample_addr1), .sample_valid(sample_valid), .sample_din(sample_din), .sample_out(sample_out1));
ga20_channel ch2( .clk(clk), .reset(reset), .ce(ce & ce2), .sample_ce(ce), .cs(cs2), .rd(rd), .wr(wr), .addr(addr[2:0]), .din(din), .dout(dout2), .sample_addr(sample_addr2), .sample_valid(sample_valid), .sample_din(sample_din), .sample_out(sample_out2));
ga20_channel ch3( .clk(clk), .reset(reset), .ce(ce & ce3), .sample_ce(ce), .cs(cs3), .rd(rd), .wr(wr), .addr(addr[2:0]), .din(din), .dout(dout3), .sample_addr(sample_addr3), .sample_valid(sample_valid), .sample_din(sample_din), .sample_out(sample_out3));

always_ff @(posedge clk) begin
    if (reset) begin
        step <= 3'd0;
        sample_rd <= 0;
    end else begin
        reg prev_ce = 0;
        sample_rd <= 0;

        prev_ce <= ce;
        if (~ce & prev_ce) begin
            step <= step + 3'd1;
            case (step)
            0, 1: sample_addr <= sample_addr0;
            2, 3: sample_addr <= sample_addr1;
            4, 5: sample_addr <= sample_addr2;
            6, 7: sample_addr <= sample_addr3;
            endcase
            sample_rd <= 1;
        end
    end
end

reg [15:0] sample_combined;

// 9685hz 2nd order 10749hz 1st order
localparam CX = 0.00000741947949554119;
localparam CY0 = -2.95726738834813529522;
localparam CY1 = 2.91526970775390958934;
localparam CY2 = -0.95799698165074131939;

IIR_filter #(
    .use_params(1),
    .stereo(0),
    .coeff_x(CX),
    .coeff_x0(3),
    .coeff_x1(3),
    .coeff_x2(1),
    .coeff_y0(CY0),
    .coeff_y1(CY1),
    .coeff_y2(CY2)) lpf_sample (
	.clk(clk),
	.reset(reset),

	.ce(ce),
	.sample_ce(ce),

	.cx(), .cx0(), .cx1(), .cx2(), .cy0(), .cy1(), .cy2(),

	.input_l(sample_combined),
	.output_l(sample_out),

    .input_r(),
    .output_r()
);

always_ff @(posedge clk) begin
    sample_combined <= sample_out0 + sample_out1 + sample_out2 + sample_out3;
end

endmodule
