module systolic_grid #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 19,
    parameter GRID_SIZE = 8
) (
    input  logic clk,
    input  logic rst_ni, 
    input  logic signed [ACC_WIDTH-1:0] in_top [0:GRID_SIZE-1],
    input  logic load_en_in [0:GRID_SIZE-1], 
    input  logic signed [DATA_WIDTH-1:0] in_left [0:GRID_SIZE-1], 
    output logic signed [DATA_WIDTH-1:0] out_right [0:GRID_SIZE-1],
    output logic signed [ACC_WIDTH-1:0] out_bottom [0:GRID_SIZE-1]
);
    logic signed [ACC_WIDTH-1:0] sum_bus [0:GRID_SIZE][0:GRID_SIZE-1];
    logic signed [DATA_WIDTH-1:0] act_bus [0:GRID_SIZE-1][0:GRID_SIZE];
    logic load_en_bus [0:GRID_SIZE][0:GRID_SIZE-1];
    // map external I/O to the routing mesh boundaries
    genvar b;
    generate
        for (b = 0; b < GRID_SIZE; b++) begin : for_boundaries
            assign act_bus[b][0] = in_left[b]; 
            assign sum_bus[0][b] = in_top[b]; 
            assign load_en_bus[0][b] = load_en_in[b];
            
            assign out_bottom[b] = sum_bus[GRID_SIZE][b]; 
            assign out_right[b] = act_bus[b][GRID_SIZE]; 
        end
    endgenerate
    // making the NxN grid of PEs
    genvar i, j;
    generate
        for (i = 0; i < GRID_SIZE; i++) begin : row_loop
            for (j = 0; j < GRID_SIZE; j++) begin : col_loop
                PE #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH(ACC_WIDTH)
                ) pe_inst (
                    .clk(clk),
                    .rst_ni(rst_ni),
                    .load_en(load_en_bus[i][j]),
                    .load_en_out(load_en_bus[i+1][j]),
                    .activations_in(act_bus[i][j]),
                    .sums_in(sum_bus[i][j]),
                    .activations_out(act_bus[i][j+1]),
                    .sums_out(sum_bus[i+1][j])
                );
            end
        end
    endgenerate
endmodule