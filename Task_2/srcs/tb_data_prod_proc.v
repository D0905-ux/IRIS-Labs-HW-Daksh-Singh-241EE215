`timescale 1ns/1ps

module tb_data_prod_proc;

    reg clk = 0;
    reg sensor_clk = 0;

    // 500MHz
    always #5 clk = ~clk;
    // 200MHz
    always #2.5 sensor_clk = ~sensor_clk;

    reg [1:0] reset_cnt = 0; // Resets after 4 clock cycles (40ns)
    wire resetn = &reset_cnt;
    always @(posedge clk) if (!resetn) reset_cnt <= reset_cnt + 1'b1;

    reg [5:0] sensor_reset_cnt = 0;
    wire sensor_resetn = &sensor_reset_cnt;
    always @(posedge sensor_clk) if (!sensor_resetn) sensor_reset_cnt <= sensor_reset_cnt + 1'b1;

    // Interconnects
    wire [7:0] pixel_stream;     // From Producer
    wire       valid_stream;     // From Producer
    wire [7:0] fifo_data_out;    // From FIFO to Processor
    wire       fifo_full;
    wire       fifo_empty;
    wire       pixel_out_valid;
    wire [7:0] pixel_out;

    // Logic: Read from FIFO whenever it has data
    wire rd_en = !fifo_empty;
    
    // --- Configuration ---
    reg [1:0]  mode; 
    reg signed [71:0] kernel;
    
    initial begin
        mode = 2'b10; 
        kernel = {8'shFF, 8'sh00, 8'sh01, 
              8'shFE, 8'sh00, 8'sh02, 
              8'shFF, 8'sh00, 8'sh01};
    end

    /*---------------------------------------------------*/
    /* MONITOR LOGIC: Print Image to Console             */
    /*---------------------------------------------------*/
    integer x = 0;
    integer y = 0;
    integer total_pixels = 0; 

    always @(posedge clk) begin
        if (pixel_out_valid) begin
            total_pixels <= total_pixels + 1;

            // Coordinate tracking
            if (x == 31) begin
                x <= 0;
                y <= y + 1;
            end else begin
                x <= x + 1;
            end

            // Print the 30x30 valid area
            if (x >= 1 && x <= 30 && y >= 1 && y <= 30) begin
                $write("%h ", pixel_out);
                if (x == 30) $display(""); 
            end
            
            // AUTOMATIC TERMINATION
            if (total_pixels == 1023) begin 
                $display("\n--- 32x32 CONVOLUTION FINISHED ---");
                $finish;
            end
        end
    end
    /*---------------------------------------------------*/
    /* MODULE INSTANTIATIONS                             */
    /*---------------------------------------------------*/
    // 1. DATA PRODUCER (200MHz Domain)
    data_producer #(.IMAGE_SIZE(1024)) producer_inst (
        .sensor_clk(sensor_clk),
        .rst_n(sensor_resetn),
        .ready(!fifo_full),      // Stop if FIFO is full
        .pixel(pixel_stream),
        .valid(valid_stream)
    );

    // 2. ASYNC FIFO (The Bridge)
    // Synchronizes data from 200MHz to 500MHz
    async_fifo #(.WIDTH(8), .DEPTH(128)) bridge_fifo (
        .wr_clk(sensor_clk),
        .wr_rst_n(sensor_resetn),
        .wr_en(valid_stream),
        .wr_data(pixel_stream),
        .full(fifo_full),
        
        .rd_clk(clk),
        .rd_rst_n(resetn),
        .rd_en(rd_en),
        .rd_data(fifo_data_out),
        .empty(fifo_empty)
    );
    
    
    // 3. DATA PROCESSOR (500MHz Domain)
    data_proc #(.IMG_WIDTH(32), .DATA_WIDTH(8)) data_processing (
        .clk(clk),
        .rstn(resetn),
        .pixel_in(fifo_data_out),
        .pixel_valid(rd_en),      // FIFO 'rd_en' acts as 'valid' for processor
        .pixel_out(pixel_out),
        .pixel_out_valid(pixel_out_valid),
        .mode(mode),
        .kernel(kernel),
        .ready()                  // Backpressure handled by FIFO full flag
    );

endmodule
    
