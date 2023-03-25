module ga20_channel(
    input clk,
    input reset,

    input ce,
    
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
reg [3:0] volume;
reg [7:0] rate;
reg [19:0] start_addr, end_addr, cur_addr;
reg [1:0] play;
reg [8:0] rate_cnt;

reg [15:0] sample_s16;
wire [15:0] sample_flt_a_s16, sample_flt_b_s16;


reg play_set;

always_ff @(posedge clk) begin
    if (reset) begin
        volume <= 4'd00;
        play <= 2'd0;
        step <= 0;
        play_set <= 0;
        sample_s16 <= 16'h0000;
    end else begin
        if (cs & rd) begin
            if (addr == 3'd3) dout <= { 7'd0, play[1] };
        end else if (cs & wr) begin
            case (addr)
            3'd0: start_addr[11:0] <= { din, 4'b0000 };
            3'd1: start_addr[19:12] <= din;
            3'd2: end_addr[11:0] <= { din, 4'b0000 };
            3'd3: end_addr[19:12] <= din;
            3'd4: rate <= din;
            3'd5: volume <= din[3:0];
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
                        sample_s16 <= 16'h0000;
                    end else begin
                        sample_s16 <= { (sample_din - 8'h80), 8'd0 };

                        if (rate_cnt[8]) begin
                            cur_addr <= cur_addr + 20'd1;
                            sample_addr <= cur_addr + 20'd8; // prefetch
                            rate_cnt <= { 1'b0, rate };

                            if (cur_addr == end_addr) begin
                                if (play[0]) begin
                                    cur_addr <= start_addr;
                                    sample_addr <= start_addr;
                                end else begin
                                    sample_s16 <= 16'h0000;
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

// 9865hz 2nd order
IIR_filter #( .use_params(1), .stereo(0), .coeff_x(0.00039693413224479562), .coeff_x0(2), .coeff_x1(1), .coeff_x2(0), .coeff_y0(-1.97595935483028584123), .coeff_y1(0.97624491895420295595), .coeff_y2(0)) lpf_9865 (
	.clk(clk),
	.reset(reset),

	.ce(ce),
	.sample_ce(1),

	.cx(), .cx0(), .cx1(), .cx2(), .cy0(), .cy1(), .cy2(),

	.input_l(sample_s16),
	.output_l(sample_flt_a_s16),

    .input_r(),
    .output_r()
);

// 10749hz 2nd order
IIR_filter #( .use_params(1), .stereo(0), .coeff_x(0.00048829989440320068), .coeff_x0(2), .coeff_x1(1), .coeff_x2(0), .coeff_y0(-1.97331852444034416827), .coeff_y1(0.97366981932840401814), .coeff_y2(0)) lpf_10749 (
	.clk(clk),
	.reset(reset),

	.ce(ce),
	.sample_ce(1),

	.cx(), .cx0(), .cx1(), .cx2(), .cy0(), .cy1(), .cy2(),

	.input_l(sample_flt_a_s16),
	.output_l(sample_flt_b_s16),

    .input_r(),
    .output_r()
);

// apply attenuation after filtering
always_ff @(posedge clk) begin
    reg [21:0] gained;

    gained <= { sample_flt_b_s16[15], sample_flt_b_s16[15], sample_flt_b_s16 } * volume;
    sample_out <= gained[19:4];
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


    output sample_rd,
    output reg [2:0] sample_index,
    output reg [19:0] sample_addr,
    input sample_valid,
    input [7:0] sample_din,

    output reg [15:0] sample_out
);

assign sample_rd = 1;

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


ga20_channel ch0( .clk(clk), .reset(reset), .ce(ce & ce0), .cs(cs0), .rd(rd), .wr(wr), .addr(addr[2:0]), .din(din), .dout(dout0), .sample_addr(sample_addr0), .sample_valid(sample_valid), .sample_din(sample_din), .sample_out(sample_out0));
ga20_channel ch1( .clk(clk), .reset(reset), .ce(ce & ce1), .cs(cs1), .rd(rd), .wr(wr), .addr(addr[2:0]), .din(din), .dout(dout1), .sample_addr(sample_addr1), .sample_valid(sample_valid), .sample_din(sample_din), .sample_out(sample_out1));
ga20_channel ch2( .clk(clk), .reset(reset), .ce(ce & ce2), .cs(cs2), .rd(rd), .wr(wr), .addr(addr[2:0]), .din(din), .dout(dout2), .sample_addr(sample_addr2), .sample_valid(sample_valid), .sample_din(sample_din), .sample_out(sample_out2));
ga20_channel ch3( .clk(clk), .reset(reset), .ce(ce & ce3), .cs(cs3), .rd(rd), .wr(wr), .addr(addr[2:0]), .din(din), .dout(dout3), .sample_addr(sample_addr3), .sample_valid(sample_valid), .sample_din(sample_din), .sample_out(sample_out3));

always_ff @(posedge clk) begin
    if (ce) step <= step + 3'd1;

    sample_index <= step;
    case (step)
    7, 0: sample_addr <= sample_addr3;
    1, 2: sample_addr <= sample_addr0;
    3, 4: sample_addr <= sample_addr1;
    5, 6: sample_addr <= sample_addr2;
    endcase
end

always_ff @(posedge clk) begin
    reg [17:0] combined;
    if (ce) begin
        combined <= { {2{sample_out0[15]}}, sample_out0 } + { {2{sample_out1[15]}}, sample_out1 } + { {2{sample_out2[15]}}, sample_out2 } + { {2{sample_out3[15]}}, sample_out3 };
        sample_out <= combined[17:2];
    end 
end

endmodule
