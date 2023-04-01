module eeprom_28xx_paged(
    input clk,

    input reset,

    input ce,
    input wr,
    input rd,

    input [13:0] addr,
    input [7:0] data,
    output reg [7:0] q
);

reg [7:0] mem[16384];

reg [7:0]  write_page;
reg [5:0]  write_addrs[64];
reg [7:0]  write_bytes[64];
reg [6:0]  write_index;
reg [6:0]  store_index;
reg        write_queuing;
reg        store_pending;
reg [31:0] write_timer;
reg [7:0]  last_byte;

always @(posedge clk) begin
    if (reset) begin
        store_pending <= 0;
        write_queuing <= 0;
        write_index <= 7'd0;
        store_index <= 7'd0;

    end else if (ce) begin
        if (store_pending) begin
            if (store_index == write_index) begin
                store_pending <= 0;
            end else begin
                mem[{write_page, write_addrs[store_index]}] <= write_bytes[store_index];
                store_index <= store_index + 7'd1;
            end
        end else if (wr) begin
            write_timer <= 32'd0;
            write_queuing <= 1;
            write_addr[write_index] <= addr[5:0];
            write_bytes[write_index] <= data;
            write_index <= write_index + 7'd1;
            write_page <= addr[13:6];
            last_byte <= data;

            if (write_index == 7'd63) begin
                store_pending <= 1;
                store_index <= 7'd0;
                write_queuing <= 0;
            end
        end else if (write_queuing) begin
            write_timer <= write_timer + 32'd1;
            if (write_timer == 32'd100_000) begin
                store_pending <= 1;
                store_index <= 7'd0;
                write_queuing <= 0;
            end
        end

        if (rd) begin
            if (write_queuing | store_pending) begin
                q <= { ~last_byte[7], last_byte[6:0] };
                last_byte[6] <= ~last_byte[6];
            end else begin
                q <= mem[addr];
            end
        end
    end
end

endmodule

module eeprom_28C64 #(parameter WRITE_CYCLES=0) (
    input clk,

    input ce,
    input wr,
    input rd,

    input  [12:0] addr,
    input  [7:0]  data,
    output [7:0]  q,

    output ready
);

reg [7:0] mem[8192];
reg [7:0] q0;

reg [31:0] write_timer;

assign ready = write_timer == 32'd0;
assign busy = ~ready;
assign q = ready ? q0 : ( ~q0 );

always_ff @(posedge clk) begin
    if (reset) begin
        write_timer <= 32'd0;
    end else if (ce) begin
        if (busy) begin
            write_timer <= write_timer - 32'd1;
        end else if (wr) begin
            write_timer <= WRITE_CYCLES;
            mem[addr] <= data;
            q0 <= data;
        end else if (rd) begin
            q0 <= mem[addr];
        end
    end
end

endmodule