module skew_unit #(
    parameter DATA_WIDTH = 8,
    parameter GRID_SIZE  = 8,

    parameter DELAY_PER_STEP = 2 
)(
    input  logic clk,
    input  logic rst_ni,
    input  logic [GRID_SIZE-1:0][DATA_WIDTH-1:0] in_data,
    output logic [GRID_SIZE-1:0][DATA_WIDTH-1:0] out_data
);

    genvar row;
    generate
        for (row = 0; row < GRID_SIZE; row++) begin : gen_skew_rows
            // increment delay proportionally to the row index
            localparam DELAY = row * DELAY_PER_STEP;
            
            if (DELAY == 0) begin : gen_no_delay
                assign out_data[row] = in_data[row];
            end else begin : gen_delay
                logic [DELAY-1:0][DATA_WIDTH-1:0] pipe;
                // shift register implementation for pipeline delay
                always_ff @(posedge clk or negedge rst_ni) begin
                    if (!rst_ni) begin
                        pipe <= '0;
                    end else begin
                        pipe[0] <= in_data[row];
                        for (int k = 1; k < DELAY; k++) begin
                            pipe[k] <= pipe[k-1];
                        end
                    end
                end
                
                assign out_data[row] = pipe[DELAY-1];
            end
        end
    endgenerate

endmodule