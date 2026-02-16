`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.02.2026 18:53:53
// Design Name: 
// Module Name: async_fifo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module async_fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 16
)(
    input  wire             wr_clk,
    input  wire             wr_rst_n,
    input  wire             wr_en,
    input  wire [WIDTH-1:0] wr_data,
    
    input  wire             rd_clk,
    input  wire             rd_rst_n,
    input  wire             rd_en,
    output wire [WIDTH-1:0] rd_data,
    
    output wire             full,
    output wire             empty
);
    localparam ADDR_WM = $clog2(DEPTH);

    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WM:0] wr_ptr, rd_ptr;
    reg [ADDR_WM:0] wr_ptr_gray_sync1, wr_ptr_gray_sync2;
    reg [ADDR_WM:0] rd_ptr_gray_sync1, rd_ptr_gray_sync2;

    wire [ADDR_WM:0] wr_ptr_gray, rd_ptr_gray;

    // --- Write Domain ---
    assign wr_ptr_gray = wr_ptr ^ (wr_ptr >> 1);

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr <= 0;
        end else if (wr_en && !full) begin
            mem[wr_ptr[ADDR_WM-1:0]] <= wr_data;
            wr_ptr <= wr_ptr + 1;
        end
    end

    // --- Read Domain ---
    assign rd_ptr_gray = rd_ptr ^ (rd_ptr >> 1);

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr <= 0;
        end else if (rd_en && !empty) begin
            rd_ptr <= rd_ptr + 1;
        end
    end
    assign rd_data = mem[rd_ptr[ADDR_WM-1:0]];

    // --- Clock Domain Crossing (2FF Synchronizers) ---
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) {wr_ptr_gray_sync2, wr_ptr_gray_sync1} <= 0;
        else {wr_ptr_gray_sync2, wr_ptr_gray_sync1} <= {wr_ptr_gray_sync1, wr_ptr_gray};
    end

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) {rd_ptr_gray_sync2, rd_ptr_gray_sync1} <= 0;
        else {rd_ptr_gray_sync2, rd_ptr_gray_sync1} <= {rd_ptr_gray_sync1, rd_ptr_gray};
    end

    // --- Status Flags ---
    assign empty = (rd_ptr_gray == wr_ptr_gray_sync2);
    assign full  = (wr_ptr_gray == {~rd_ptr_gray_sync2[ADDR_WM:ADDR_WM-1], rd_ptr_gray_sync2[ADDR_WM-2:0]});

endmodule
