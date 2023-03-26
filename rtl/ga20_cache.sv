module ga20_cache(
    input clk,
    input reset,

    input rd,
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
    PENDING_RQ,
    PENDING_ACK,
    VALID
} entrystate_e;

typedef struct {
    entrystate_e state;

    bit [16:0] addr64;
    bit [63:0] data;

    int stamp;
} entry_t;

localparam N = 12;

entry_t entry[N];

reg rq;
reg ack;
reg rq_active;
reg read_missed;
reg [16:0] read_addr64;

int rq_index;
int old_index;

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
        for(i = 0; i < N; i++) begin
            entry[i].state <= VALID;
            entry[i].addr64 <= 17'h1ffff;
        end
        rq_active <= 0;
        rq <= 0;
        read_missed <= 0;
    end else begin
        for(i = 0; i < N; i++) begin
            if (entry[i].state == VALID) begin
                if (entry[i].stamp == 0) begin
                    old_index <= i;
                end
            end
        end

        if (rq_active) begin
            if (rq == ack) begin
                rq_active <= 0;
                if (entry[rq_index].state == PENDING_ACK) begin
                    entry[rq_index].state <= VALID;
                    entry[rq_index].data <= sdr_data;
                    entry[rq_index].stamp <= N;
                end
            end
        end else begin
            found_pending = 0;
            for(i = 0; i < N; i++) begin
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
            valid <= 0;
            read_missed <= 1;
            read_addr64 <= addr[19:3];
            for(i = 0; i < N; i++) begin
                if (entry[i].state == VALID && entry[i].stamp != 0) begin
                    entry[i].stamp <= entry[i].stamp - 1;
                    if (addr[19:3] == entry[i].addr64) begin
                        valid <= 1;
                        read_missed <= 0;
                        dout <= entry[i].data[(addr[2:0]*8) +: 8];
                        entry[i].stamp <= N;
                    end
                end
            end
        end else if (read_missed) begin
            entry[old_index].state <= PENDING_RQ;
            entry[old_index].addr64 <= read_addr64;
            read_missed <= 0;
        end
    end
end

endmodule