module deskew_unit #(
    parameter ACC_WIDTH = 19,
    parameter GRID_SIZE = 8,
    parameter DELAY_PER_STEP = 2    
)(
    input logic clk,
    input logic rst_ni,
    input logic [GRID_SIZE-1:0][ACC_WIDTH-1:0] in_data,
    output logic [GRID_SIZE-1:0][ACC_WIDTH-1:0] out_data
);
     genvar col;
    generate
     for (col = 0; col < GRID_SIZE; col++) begin : gen_deskew_cols
        // invert the delay logic: Leftmost columns experience maximum delay,rightmost pass right away
         localparam DELAY = (GRID_SIZE - 1 - col) * DELAY_PER_STEP;
             if (DELAY == 0) begin : gen_no_delay
                 assign out_data[col] = in_data[col];
        end else begin : gen_delay
                logic [DELAY-1:0][ACC_WIDTH-1:0] pipe;
                always_ff @(posedge clk or negedge rst_ni) begin
                 if (!rst_ni) pipe <= '0;
                 else begin
                    pipe[0] <= in_data[col];
                     for (int k = 1; k < DELAY; k++) pipe[k] <= pipe[k-1];
                     end
                end
                assign out_data[col] = pipe[DELAY-1];
             end
         end
     endgenerate
endmodule
