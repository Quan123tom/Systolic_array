`timescale 1ns / 1ps

module tb_tpu_wrapper;
    localparam int DATA_WIDTH = 8;
    localparam int ACC_WIDTH = 19;
    localparam int GRID_SIZE = 8;
    localparam int ADDR_WIDTH = 10;
    logic clk = 1'b0;
    logic rst_ni;
    logic start;
    logic [ADDR_WIDTH-1:0] csr_weight_base;
    logic [ADDR_WIDTH-1:0] csr_act_base;
    logic [ADDR_WIDTH-1:0] csr_out_base;
    logic [15:0] csr_act_rows;
    logic busy, done;
    always #5 clk = ~clk;

    tpu_wrapper #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .GRID_SIZE(GRID_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_ni(rst_ni),
        .start(start),
        .csr_weight_base(csr_weight_base),
        .csr_act_base(csr_act_base),
        .csr_out_base(csr_out_base),
        .csr_act_rows(csr_act_rows),
        .busy(busy),
        .done(done)
    );
    logic signed [DATA_WIDTH-1:0] mat_A [0:GRID_SIZE-1][0:GRID_SIZE-1];
    logic signed [DATA_WIDTH-1:0] mat_W [0:GRID_SIZE-1][0:GRID_SIZE-1];
    logic signed [ACC_WIDTH-1:0] golden_C [0:GRID_SIZE-1][0:GRID_SIZE-1];
    initial begin
        int err_cnt = 0;
        rst_ni = 1'b0;
        start  = 1'b0;
        csr_weight_base = '0;
        csr_act_base = '0;
        csr_out_base = '0;
        csr_act_rows = GRID_SIZE;

        // generating signed test matrices 
        for (int i = 0; i < GRID_SIZE; i++) begin
            logic [(GRID_SIZE*DATA_WIDTH)-1:0] w_row = '0;
            logic [(GRID_SIZE*DATA_WIDTH)-1:0] a_row = '0;
            for (int j = 0; j < GRID_SIZE; j++) begin
                mat_W[i][j] = (i == j) ? 8'sd2 : ((i + j) % 3 == 0 ? -8'sd1 : 8'sd0);
                mat_A[i][j] = (i * GRID_SIZE + j) - 16; // ranges from -16 to +47

                w_row[j*DATA_WIDTH +: DATA_WIDTH] = mat_W[i][j];
                a_row[j*DATA_WIDTH +: DATA_WIDTH] = mat_A[i][j];
            end
            dut.bank_a_weights.mem[i] = w_row;
            dut.bank_b_acts.mem[i] = a_row;
            dut.bank_c_outs.mem[i] = '0;
        end

        // compute reference: C = A * W
        for (int i = 0; i < GRID_SIZE; i++) begin
            for (int j = 0; j < GRID_SIZE; j++) begin
                golden_C[i][j] = '0;
                for (int k = 0; k < GRID_SIZE; k++) begin
                    golden_C[i][j] += mat_A[i][k] * mat_W[k][j];
                end
            end
        end

        repeat (3) @(posedge clk);
        rst_ni = 1'b1;
        @(posedge clk);

        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        wait (done);
        @(posedge clk);

        for (int i = 0; i < GRID_SIZE; i++) begin
            logic [(GRID_SIZE*ACC_WIDTH)-1:0] c_row = dut.bank_c_outs.mem[i];
            for (int j = 0; j < GRID_SIZE; j++) begin
                logic signed [ACC_WIDTH-1:0] hw_val = c_row[j*ACC_WIDTH +: ACC_WIDTH];
                if (hw_val !== golden_C[i][j]) begin
                    $display("[MISMATCH] C[%0d][%0d]: got %0d, expected %0d", i, j, hw_val, golden_C[i][j]);
                    err_cnt++;
                end
            end
        end

        if (err_cnt == 0)
            $display("[PASS] All %0dx%0d signed MAC outputs matched golden reference.", GRID_SIZE, GRID_SIZE);
        else
            $display("[FAIL] Found %0d mismatches.", err_cnt);

        $finish;
    end

endmodule
