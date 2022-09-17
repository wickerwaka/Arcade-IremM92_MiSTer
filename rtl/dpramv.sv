`timescale 1ns / 1ps

module dpramv #(
    parameter width_a = 8,
    parameter widthad_a = 10,
    parameter init_file= "",
    parameter prefix= "",
    parameter p= ""
) (
    // Port A
    input   wire                clock_a,
    input   wire                wren_a,
    input   wire    [widthad_a-1:0]  address_a,
    input   wire    [width_a-1:0]  data_a,
    output  reg     [width_a-1:0]  q_a,

    // Port B
    input   wire                clock_b,
    input   wire                wren_b,
    input   wire    [widthad_a-1:0]  address_b,
    input   wire    [width_a-1:0]  data_b,
    output  reg     [width_a-1:0]  q_b
);

    initial begin
        if (init_file>0) begin
            $display("Loading rom.");
            $display(init_file);
            $readmemh(init_file, ram);
        end
    end


// Shared ramory
reg [width_a-1:0] ram[(2**widthad_a)-1:0];

// Port A
always @(posedge clock_a) begin
  if (wren_a) begin
    ram[address_a] <= data_a;
    q_a <= data_a;
  end else begin
      q_a <= ram[address_a];
  end
end

// Port B
always @(posedge clock_b) begin
    if(wren_b) begin
        q_b      <= data_b;
        ram[address_b] <= data_b;
    end else begin
        q_b <= ram[address_b];
    end
end

endmodule

module dpramv_16 #( parameter widthad_a = 10 ) (
    // Port A
    input   wire                clock_a,
    input   wire    [1:0]       wren_a,
    input   wire    [widthad_a-1:0]  address_a,
    input   wire    [15:0]      data_a,
    output  wire    [15:0]      q_a,

    // Port B
    input   wire                clock_b,
    input   wire    [1:0]       wren_b,
    input   wire    [widthad_a-1:0]  address_b,
    input   wire    [15:0]      data_b,
    output  wire    [15:0]      q_b
);

dpramv #(.widthad_a(widthad_a)) low(
    .clock_a(clock_a),
    .address_a(address_a),
    .q_a(q_a[7:0]),
    .wren_a(wren_a[0]),
    .data_a(data_a[7:0]),

    .clock_b(clock_b),
    .address_b(address_b),
    .q_b(q_b[7:0]),
    .wren_b(wren_b[0]),
    .data_b(data_b[7:0])
);

dpramv #(.widthad_a(widthad_a)) high(
    .clock_a(clock_a),
    .address_a(address_a),
    .q_a(q_a[15:8]),
    .wren_a(wren_a[1]),
    .data_a(data_a[15:8]),

    .clock_b(clock_b),
    .address_b(address_b),
    .q_b(q_b[15:8]),
    .wren_b(wren_b[1]),
    .data_b(data_b[15:8])
);

endmodule

module dpramv_cen #(
    parameter width_a = 8,
    parameter widthad_a = 10
) (
    // Port A
    input   wire                clock_a,
    input   wire                cen_a,
    input   wire                wren_a,
    input   wire    [widthad_a-1:0]  address_a,
    input   wire    [width_a-1:0]  data_a,
    output  reg     [width_a-1:0]  q_a,

    // Port B
    input   wire                clock_b,
    input   wire                cen_b,
    input   wire                wren_b,
    input   wire    [widthad_a-1:0]  address_b,
    input   wire    [width_a-1:0]  data_b,
    output  reg     [width_a-1:0]  q_b
);

// Shared ramory
reg [width_a-1:0] ram[(2**widthad_a)-1:0];

// Port A
always @(posedge clock_a) begin
    if (cen_a) begin
        if (wren_a) begin
            ram[address_a] <= data_a;
            q_a <= data_a;
        end else begin
            q_a <= ram[address_a];
        end
    end
end

// Port B
always @(posedge clock_b) begin
    if (cen_b) begin
        if(wren_b) begin
            q_b      <= data_b;
            ram[address_b] <= data_b;
        end else begin
            q_b <= ram[address_b];
        end
    end
end

endmodule