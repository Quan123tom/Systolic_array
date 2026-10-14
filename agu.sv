module agu #(
    parameter ADDR_WIDTH = 10,
    parameter COUNT_DOWN = 0,
    parameter MAX_CNT    = 7
)(
    input  logic clk,
    input  logic rst_ni,
    input  logic load_base,
    input  logic en,
    input  logic [ADDR_WIDTH-1:0] base_addr,
    output logic [ADDR_WIDTH-1:0] current_addr
);
    always_ff @(posedge clk or negedge rst_ni) begin
        if (!rst_ni) begin
            current_addr <= '0;
        end else if (load_base) begin
            current_addr <= COUNT_DOWN ? (base_addr + MAX_CNT) : base_addr;
        end else if (en) begin
            current_addr <= COUNT_DOWN ? (current_addr - 1'b1) : (current_addr + 1'b1);
        end
    end
endmodule