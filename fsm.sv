module tpu_fsm #(
    parameter GRID_SIZE = 8
)(
    input  logic clk,
    input  logic rst_ni,
    input  logic start,
    input  logic [15:0] act_rows,
    input  logic valid_pipe_empty,
    
    output logic fsm_load_agus,
    output logic fsm_loading_weights,
    output logic fsm_en_weight_agu,
    output logic fsm_pushing_acts,
    output logic fsm_en_act_agu,
    output logic busy,
    output logic done
);

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_LOAD_WEIGHTS,
        ST_COMPUTE,
        ST_DRAIN,
        ST_DONE
    } state_t;
    
    state_t state, next_state;

    logic [3:0]  weight_cnt;
    logic [15:0] act_cnt;

    always_ff @(posedge clk or negedge rst_ni) begin
        if (!rst_ni) begin
            state <= ST_IDLE;
            weight_cnt <= '0;
            act_cnt <= '0;
        end else begin
            state <= next_state;
            if (state == ST_IDLE) begin
                weight_cnt <= '0;
                act_cnt <= '0;
            end else if (state == ST_LOAD_WEIGHTS) begin
                weight_cnt <= weight_cnt + 1'b1;
            end else if (state == ST_COMPUTE) begin
                act_cnt <= act_cnt + 1'b1;
            end
        end
    end

    always_comb begin
        next_state = state;
        busy = 1'b1;
        done = 1'b0;
        fsm_load_agus = 1'b0;
        fsm_loading_weights = 1'b0;
        fsm_en_weight_agu = 1'b0;
        fsm_pushing_acts = 1'b0;
        fsm_en_act_agu = 1'b0;

        case (state)
            ST_IDLE: begin
                busy = 1'b0;
                fsm_load_agus = 1'b1; 
                if (start) next_state = ST_LOAD_WEIGHTS;
            end

            ST_LOAD_WEIGHTS: begin
                fsm_loading_weights = 1'b1;
                fsm_en_weight_agu = 1'b1;
                if (weight_cnt == GRID_SIZE - 1) next_state = ST_COMPUTE;
            end

            ST_COMPUTE: begin
                fsm_pushing_acts = 1'b1;
                fsm_en_act_agu = 1'b1;
                if (act_cnt == act_rows - 1) next_state = ST_DRAIN;
            end

            ST_DRAIN: begin
                if (valid_pipe_empty) next_state = ST_DONE;
            end

            ST_DONE: begin
                done = 1'b1;
                if (!start) next_state = ST_IDLE;
            end
            
            default: next_state = ST_IDLE;
        endcase
    end
endmodule