module PE #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 19
)(
    input  logic clk,
    input  logic rst_ni, 
    input  logic load_en,
    output logic load_en_out,
    
    input  logic signed [DATA_WIDTH-1:0] activations_in,
    input  logic signed [ACC_WIDTH-1:0] sums_in,
    
    output logic signed [DATA_WIDTH-1:0] activations_out,
    output logic signed [ACC_WIDTH-1:0] sums_out
);
    // combinational pass-through creating synchronous column-wide load signal => allows an entire column of PEs to capture weights at the same time
    assign load_en_out = load_en;
    logic signed [DATA_WIDTH-1:0] weight_reg;
    logic signed [DATA_WIDTH-1:0] act_reg;
    logic signed [ACC_WIDTH-1:0] sum_reg;
    logic signed [ACC_WIDTH-1:0] prod_reg;
    // generating a boolean mask based on activation validity.
    // forces multiplier inputs to zero statically when data is invalid,  eliminating downstream combinational toggling in the MAC logic.
    logic [DATA_WIDTH-1:0] iso_mask;
    assign iso_mask = (activations_in != '0) ? '1 : '0;
    
    logic signed [DATA_WIDTH-1:0] gated_act;
    logic signed [DATA_WIDTH-1:0] gated_wt;
    assign gated_act = activations_in & iso_mask;
    assign gated_wt  = weight_reg & iso_mask;

    always_ff @(posedge clk or negedge rst_ni) begin
        if (!rst_ni) begin
            weight_reg <= '0;
            act_reg <= '0;
            sum_reg <= '0;
            prod_reg <= '0;
            activations_out <= '0;
            sums_out <= '0;
        end else begin
            if (load_en) begin
                weight_reg <= sums_in[DATA_WIDTH-1:0]; 
                sum_reg <= sums_in;                 
                act_reg <= '0;                      
                prod_reg <= '0;
                sums_out <= sums_in; // pipeline reg for vertical synchronization
                activations_out <= '0;
            end else begin
                act_reg <= activations_in;
                sum_reg <= sums_in;                 
                prod_reg <= gated_act * gated_wt; 
                
                sums_out <= prod_reg + sum_reg;
                activations_out <= act_reg;
            end
        end
    end
endmodule