module ga20_cache(
    input clk,
    input reset,

    input rd,
    input [2:0] index,
    input [19:0] addr,
    output reg valid,
    output reg [7:0] dout,

    input clk_ram,
    output reg [24:0] sdr_addr,
    input [63:0] sdr_data,
    output reg sdr_req,
    input sdr_rdy
);

typedef enum bit[1:0] {
    INVALID,
    PENDING_RQ,
    PENDING_ACK,
    VALID
} entrystate_e;

typedef struct {
    entrystate_e state;

    bit [16:0] addr64;
    bit [63:0] data;
} entry_t;

entry_t entry[8];

reg rq;
reg ack;
reg [2:0] rq_index;
reg rq_active;

always_ff @(posedge clk_ram) begin
    if (reset) begin
        ack <= 0;
    end else if (sdr_rdy) begin
        ack <= rq;
    end
end

always_ff @(posedge clk) begin
    int i;
    reg found_pending;
    
    sdr_req <= 0;

    if (reset) begin
        for(i = 0; i < 8; i++) begin
            entry[i].state <= INVALID;
        end
        rq_active <= 0;
        rq <= 0;
    end else begin

        if (rq_active) begin
            if (rq == ack) begin
                rq_active <= 0;
                if (entry[rq_index].state == PENDING_ACK) begin
                    entry[rq_index].state <= VALID;
                    entry[rq_index].data <= sdr_data;
                end
            end
        end else begin
            found_pending = 0;
            for(i = 0; i < 8; i++) begin
                if (found_pending == 0 && entry[i].state == PENDING_RQ) begin
                    found_pending = 1;
                    rq_index <= i;
                    rq_active <= 1;
                    sdr_req <= 1;
                    sdr_addr <= REGION_GA20.base_addr[24:0] + { entry[i].addr64, 3'b000 };
                    rq <= ~rq;
                    entry[i].state <= PENDING_ACK;
                end
            end
        end

        if (rd) begin
            if (addr[19:3] == entry[index].addr64) begin
                case (entry[index].state)
                INVALID: begin
                    entry[index].state <= PENDING_RQ;
                    valid <= 0;
                end
                PENDING_RQ: valid <= 0;
                PENDING_ACK: valid <= 0;
                VALID: begin
                    valid <= 1;
                    dout <= entry[index].data[(addr[2:0]*8) +: 8];
                end
                endcase
            end else begin
                entry[index].state <= PENDING_RQ;
                entry[index].addr64 <= addr[19:3];
            end
        end
    end
end

endmodule