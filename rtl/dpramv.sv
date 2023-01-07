`timescale 1ns / 1ps

module dualport_ram #(
    parameter width = 8,
    parameter widthad = 10
) (
    // Port A
    input   wire                  clock_a,
    input   wire                  wren_a,
    input   wire    [widthad-1:0] address_a,
    input   wire    [width-1:0]   data_a,
    output  reg     [width-1:0]   q_a,

    // Port B
    input   wire                  clock_b,
    input   wire                  wren_b,
    input   wire    [widthad-1:0] address_b,
    input   wire    [width-1:0]   data_b,
    output  reg     [width-1:0]   q_b
);

// Shared ramory
reg [width-1:0] ram[(2**widthad)-1:0];

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

module singleport_ram #(
    parameter width = 8,
    parameter widthad = 10
) (
    input   wire                   clock,
    input   wire                   wren,
    input   wire    [widthad-1:0]  address,
    input   wire    [width-1:0]    data,
    output  reg     [width-1:0]    q

);

// Shared ramory
reg [width-1:0] ram[(2**widthad)-1:0];

// Port
always @(posedge clock) begin
    if (wren) begin
        ram[address] <= data;
        q <= data;
    end else begin
        q <= ram[address];
    end
end


endmodule

module singleport_unreg_ram #(
    parameter width = 8,
    parameter widthad = 10
) (
    input   wire                   clock,
    input   wire                   wren,
    input   wire    [widthad-1:0]  address,
    input   wire    [width-1:0]    data,
    output  wire    [width-1:0]    q

);

// Shared ramory
reg [width-1:0] ram[(2**widthad)-1:0];

assign q = ram[address];

// Write Port
always @(posedge clock) begin
    if (wren) begin
        ram[address] <= data;
    end
end


endmodule