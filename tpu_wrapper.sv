module tpu_wrapper #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 19,
    parameter GRID_SIZE  = 8,
    parameter ADDR_WIDTH = 10 
)(
    input logic clk,
    input logic rst_ni,
    // control and config signals
    input logic start,
    input logic [ADDR_WIDTH-1:0] csr_weight_base,
    input logic [ADDR_WIDTH-1:0] csr_act_base,
    input logic [ADDR_WIDTH-1:0] csr_out_base,
    input logic [15:0] csr_act_rows,
    
    // 
    output logic busy,
    output logic done
);

    logic fsm_load_agus, fsm_loading_weights, fsm_pushing_acts;
    logic fsm_en_weight_agu, fsm_en_act_agu;
    
    // sram
    logic [ADDR_WIDTH-1:0] bank_a_addr, bank_b_addr, bank_c_addr;
    logic [(GRID_SIZE*DATA_WIDTH)-1:0] bank_a_rdata;
    logic [(GRID_SIZE*DATA_WIDTH)-1:0] bank_b_rdata;
    logic [(GRID_SIZE*ACC_WIDTH)-1:0]  bank_c_wdata;
    
    // datapath 
    logic [GRID_SIZE-1:0][DATA_WIDTH-1:0] skew_in;
    logic [GRID_SIZE-1:0][DATA_WIDTH-1:0] skew_out;
    logic signed [DATA_WIDTH-1:0] grid_in_left [0:GRID_SIZE-1];
    logic signed [ACC_WIDTH-1:0]  grid_in_top [0:GRID_SIZE-1];
    logic grid_load_en [0:GRID_SIZE-1];
    logic signed [ACC_WIDTH-1:0]  grid_out_bottom [0:GRID_SIZE-1];
    logic [GRID_SIZE-1:0][ACC_WIDTH-1:0] deskew_in;
    logic [GRID_SIZE-1:0][ACC_WIDTH-1:0] deskew_out;
    logic valid_out; 

    sync_sram #(.DATA_WIDTH(GRID_SIZE*DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) bank_a_weights (
        .clk(clk), .en(fsm_en_weight_agu), .we(1'b0),
        .addr(bank_a_addr), .wdata('0), .rdata(bank_a_rdata)
    );

    sync_sram #(.DATA_WIDTH(GRID_SIZE*DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) bank_b_acts (
        .clk(clk), .en(fsm_en_act_agu), .we(1'b0),
        .addr(bank_b_addr), .wdata('0), .rdata(bank_b_rdata)
    );

    sync_sram #(.DATA_WIDTH(GRID_SIZE*ACC_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) bank_c_outs (
        .clk(clk), .en(valid_out), .we(valid_out), 
        .addr(bank_c_addr), .wdata(bank_c_wdata), .rdata() 
    );

    agu #(.ADDR_WIDTH(ADDR_WIDTH), .COUNT_DOWN(1), .MAX_CNT(GRID_SIZE-1)) agu_weights (
        .clk(clk), .rst_ni(rst_ni), .load_base(fsm_load_agus),
        .en(fsm_en_weight_agu), .base_addr(csr_weight_base), .current_addr(bank_a_addr)
    );

    agu #(.ADDR_WIDTH(ADDR_WIDTH)) agu_acts (
        .clk(clk), .rst_ni(rst_ni), .load_base(fsm_load_agus),
        .en(fsm_en_act_agu), .base_addr(csr_act_base), .current_addr(bank_b_addr)
    );

    agu #(.ADDR_WIDTH(ADDR_WIDTH)) agu_outs (
        .clk(clk), .rst_ni(rst_ni), .load_base(fsm_load_agus),
        .en(valid_out), .base_addr(csr_out_base), .current_addr(bank_c_addr)
    );

    logic load_en_aligned;
    always_ff @(posedge clk) load_en_aligned <= fsm_loading_weights;

    genvar i;
    generate
        for (i = 0; i < GRID_SIZE; i++) begin : gen_routing
            assign skew_in[i] = bank_b_rdata[i*DATA_WIDTH +: DATA_WIDTH];
            assign grid_in_left[i] = skew_out[i];
            assign grid_in_top[i] = load_en_aligned ? 
                                    {{(ACC_WIDTH-DATA_WIDTH){1'b0}}, bank_a_rdata[i*DATA_WIDTH +: DATA_WIDTH]} : '0;
            assign grid_load_en[i] = load_en_aligned;
            assign deskew_in[i] = grid_out_bottom[i];
            assign bank_c_wdata[i*ACC_WIDTH +: ACC_WIDTH] = deskew_out[i];
        end
    endgenerate

    skew_unit #(.DATA_WIDTH(DATA_WIDTH), .GRID_SIZE(GRID_SIZE), .DELAY_PER_STEP(2)) u_skew (
        .clk(clk), .rst_ni(rst_ni), .in_data(skew_in), .out_data(skew_out)
    );

    systolic_grid #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH), .GRID_SIZE(GRID_SIZE)) u_grid (
        .clk(clk), .rst_ni(rst_ni), .in_top(grid_in_top), .load_en_in(grid_load_en),
        .in_left(grid_in_left), .out_right(), .out_bottom(grid_out_bottom)
    );

    deskew_unit #(.ACC_WIDTH(ACC_WIDTH), .GRID_SIZE(GRID_SIZE), .DELAY_PER_STEP(2)) u_deskew (
        .clk(clk), .rst_ni(rst_ni), .in_data(deskew_in), .out_data(deskew_out)
    );

    localparam PIPELINE_DEPTH = 1 + ((GRID_SIZE-1)*2) + (GRID_SIZE*2);
    // exact cycle latency = 1 (SRAM Read) + Max Input Skew + Array Traversal
    logic [PIPELINE_DEPTH-1:0] valid_shift_reg;
    always_ff @(posedge clk or negedge rst_ni) begin
        if (!rst_ni) valid_shift_reg <= '0;
        else valid_shift_reg <= {valid_shift_reg[PIPELINE_DEPTH-2:0], fsm_pushing_acts};
    end    
    assign valid_out = valid_shift_reg[PIPELINE_DEPTH-1];

    tpu_fsm #(.GRID_SIZE(GRID_SIZE)) u_fsm (
        .clk(clk), .rst_ni(rst_ni), .start(start), .act_rows(csr_act_rows),
        .valid_pipe_empty(valid_shift_reg == '0),
        .fsm_load_agus(fsm_load_agus), .fsm_loading_weights(fsm_loading_weights),
        .fsm_en_weight_agu(fsm_en_weight_agu), .fsm_pushing_acts(fsm_pushing_acts),
        .fsm_en_act_agu(fsm_en_act_agu), .busy(busy), .done(done)
    );

endmodule