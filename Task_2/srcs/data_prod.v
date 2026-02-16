`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.02.2026 17:12:11
// Design Name: 
// Module Name: data_prod
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


module data_producer #(
    parameter IMAGE_SIZE = 1024
)(
    input sensor_clk,
    input rst_n,
    input ready,
    output reg [7:0] pixel,
    output reg valid
);

    reg [7:0] image_mem [0:IMAGE_SIZE-1];
    reg [$clog2(IMAGE_SIZE):0] pixel_index;
    integer file_handle;

    initial begin
        // 1. Check if file exists before reading
        file_handle = $fopen("C:/Users/daksh/Documents/IRIS_Hardware_Task_2/image.mif", "r");
        if (file_handle == 0) begin
            $error("[FATAL] Could not find image.mif at the specified path!");
            $finish;
        end
        $fclose(file_handle);

        // 2. Load the memory
        $readmemh("C:/Users/daksh/Documents/IRIS_Hardware_Task_2/image.mif", image_mem);
        
        // 3. Optional: Verify data isn't all 'x' (Sanity Check)
        if (image_mem[0] === 8'hxx) begin
            $warning("[WARN] Memory loaded but index 0 is 'x'. Check file formatting.");
        end else begin
            $display("[INFO] image.hex loaded successfully.");
        end
    end

    always @(posedge sensor_clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_index <= 0;
            valid       <= 0;
            pixel       <= 8'h00;
        end else begin
            if (ready) begin
                pixel <= image_mem[pixel_index];
                valid <= 1'b1;

                if (pixel_index < IMAGE_SIZE-1)
                    pixel_index <= pixel_index + 1;
                else
                    pixel_index <= 0;
            end else begin
                // Maintain valid high if we are in the middle of a stream but not ready
                valid <= (pixel_index == 0) ? 1'b0 : 1'b1;
            end
        end
    end

endmodule