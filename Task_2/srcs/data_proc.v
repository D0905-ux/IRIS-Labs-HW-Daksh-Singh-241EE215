`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.02.2026 17:12:11
// Design Name: 
// Module Name: data_proc
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



module data_proc #(
    parameter IMG_WIDTH  = 32,      // Width of one image row
    parameter DATA_WIDTH = 8       // Bit-width of one pixel
)(
    input  wire                    clk,
    input  wire                    rstn,

    // Input Stream
    input  wire [DATA_WIDTH-1:0]   pixel_in,
    input  wire                    pixel_valid,
    
    // Output Stream
    output reg  [DATA_WIDTH-1:0]   pixel_out,
    output reg                     pixel_out_valid,

    // Configuration
    input  wire [1:0]  mode,       // 00:Pass, 01:Invert, 10:Conv
    input  wire signed [DATA_WIDTH*9-1:0] kernel,
    output reg                     ready
);
    integer idx, row, col;
    
    // =========================================================================
    // 1. LINE BUFFERS & INPUT SYNCHRONIZATION
    // =========================================================================
    reg [DATA_WIDTH-1:0] lb0 [0:IMG_WIDTH-1];
    reg [DATA_WIDTH-1:0] lb1 [0:IMG_WIDTH-1];
    reg [$clog2(IMG_WIDTH)-1:0] col_ptr;
    
    reg [DATA_WIDTH-1:0] r_lb0, r_lb1, r_pixel_in;
    reg pixel_valid_d1;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            col_ptr <= 0;
            r_lb0 <= 0; r_lb1 <= 0; r_pixel_in <= 0;
            pixel_valid_d1 <= 0;
            ready <= 0;
            for (idx = 0; idx < IMG_WIDTH; idx = idx + 1) begin
                lb0[idx] <= 0; lb1[idx] <= 0;
            end
        end else begin
            ready <= 1'b1;
            pixel_valid_d1 <= pixel_valid; // Create a delayed valid signal
            
            if (pixel_valid) begin
                // Buffer reading (sync with registers)
                r_lb0 <= lb0[col_ptr];
                r_lb1 <= lb1[col_ptr];
                r_pixel_in <= pixel_in; // Align live pixel with buffer outputs
                
                // Buffer writing
                lb0[col_ptr] <= lb1[col_ptr];
                lb1[col_ptr] <= pixel_in;
                
                col_ptr <= (col_ptr == IMG_WIDTH-1) ? 0 : col_ptr + 1;
            end
        end
    end

    // =========================================================================
    // 2. TAPS (3x3 Window Shift Register)
    // =========================================================================
    reg [DATA_WIDTH-1:0] taps [0:2][0:2]; 

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            for (row = 0; row < 3; row = row + 1)
                for (col = 0; col < 3; col = col + 1) taps[row][col] <= 0;
        end else if (pixel_valid_d1) begin
            // Shift into taps using synchronized row data
            taps[0][0] <= taps[0][1]; taps[0][1] <= taps[0][2]; taps[0][2] <= r_lb0; 
            taps[1][0] <= taps[1][1]; taps[1][1] <= taps[1][2]; taps[1][2] <= r_lb1;
            taps[2][0] <= taps[2][1]; taps[2][1] <= taps[2][2]; taps[2][2] <= r_pixel_in;
        end
    end

    // =========================================================================
    // 3. PIPELINE STAGE 1: MULTIPLY
    // =========================================================================
    wire signed [DATA_WIDTH-1:0] k[0:8];
    genvar i;
    generate
        for(i=0; i<9; i=i+1) begin : unpack
            assign k[i] = kernel[(8-i)*DATA_WIDTH +: DATA_WIDTH];
        end
    endgenerate

    reg signed [19:0] mult [0:8]; 
    reg               mult_valid;
    reg [DATA_WIDTH-1:0] center_pixel_d1; 

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            mult_valid <= 0;
        end else begin
            // mult_valid triggers when taps are updated (1 cycle after pixel_valid_d1)
            mult_valid <= pixel_valid_d1; 
            if (pixel_valid_d1) begin
                mult[0] <= $signed({1'b0, taps[0][0]}) * k[0]; 
                mult[1] <= $signed({1'b0, taps[0][1]}) * k[1];
                mult[2] <= $signed({1'b0, taps[0][2]}) * k[2];
                mult[3] <= $signed({1'b0, taps[1][0]}) * k[3];
                mult[4] <= $signed({1'b0, taps[1][1]}) * k[4];
                mult[5] <= $signed({1'b0, taps[1][2]}) * k[5];
                mult[6] <= $signed({1'b0, taps[2][0]}) * k[6];
                mult[7] <= $signed({1'b0, taps[2][1]}) * k[7];
                mult[8] <= $signed({1'b0, taps[2][2]}) * k[8];
                center_pixel_d1 <= taps[1][1];
            end
        end
    end

    // =========================================================================
    // 4. PIPELINE STAGE 2: ACCUMULATE
    // =========================================================================
    reg signed [19:0] sum;
    reg               sum_valid;
    reg [DATA_WIDTH-1:0] center_pixel_d2; 

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            sum_valid <= 0;
            sum <= 0;
        end else begin
            sum_valid <= mult_valid;
            if (mult_valid) begin
                sum <= mult[0]+mult[1]+mult[2]+mult[3]+mult[4]+mult[5]+mult[6]+mult[7]+mult[8];
                center_pixel_d2 <= center_pixel_d1;
            end
        end
    end

    // =========================================================================
    // 5. OUTPUT STAGE (CLIPPING & MUX)
    // =========================================================================
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            pixel_out_valid <= 0;
            pixel_out <= 0;
        end else begin
            pixel_out_valid <= sum_valid;
            if (sum_valid) begin
                case (mode)
                    2'b00: pixel_out <= center_pixel_d2;
                    2'b01: pixel_out <= ~center_pixel_d2;
                    2'b10: begin
                        if (sum[19]) pixel_out <= 0;
                        else if (sum > 255) pixel_out <= 255;
                        else pixel_out <= sum[7:0];
                    end
                    default: pixel_out <= 0;
                endcase
            end
        end
    end
endmodule