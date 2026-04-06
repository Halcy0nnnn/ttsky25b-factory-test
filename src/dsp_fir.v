module dsp_fir(
    input  wire [7:0] data_in,    // Dedicated inputs
    output wire [7:0] data_out,   // Dedicated outputs
    input  wire       mode,       // 0: filter run mode, 1: coefficient load mode
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

<<<<<<< Updated upstream
    localparam M1 = 1'd0;  // Reset state
    localparam M2 = 1'd1;  // First coeffcient
    // localparam L  = 4'd2;  // Loading stage

    reg state_q, state_d;

    // FILTER COEFFICIENTS
    // Register for 8 x 8 bit filter coefficients 
    reg signed [7:0] fir_coeff [0:7];
    reg signed [7:0] data_pipeline[0:7]; //input data shift register

    reg signed [7:0] data_pipeline_split [0:3];
    reg signed [7:0] fir_coefficient_split [0:3];
    reg [18:0] carry_over;
    reg [18:0] result_adder_q; 
    wire [18:0] result_adder_d;

    reg output_valid;

    wire [15:0] result_partial [0:3];
    
    // MSB bit flip = -128
    // Convert uint8 to int8
    // Example 0-255 -> -128-127
    wire signed [7:0] data_in_signed;
    assign data_in_signed = {~data_in[7], data_in[6:0]};

    integer  i;

    always @(posedge clk) begin
        if (!rst_n) begin

            state_q <= M1; // Reset state back to M1
            result_adder_q <= 19'b0;
            for(i=0; i<8; i=i+1) begin
                fir_coeff[i] <= 8'b0;
                data_pipeline[i] <= 8'd0;
            end
        end
        else begin
            if (mode == 1'b1) begin // Load the coefficients when mode = 1
                fir_coeff[0] <= data_in;
                fir_coeff[1] <= fir_coeff[0];
                fir_coeff[2] <= fir_coeff[1];
                fir_coeff[3] <= fir_coeff[2];
                fir_coeff[4] <= fir_coeff[3];
                fir_coeff[5] <= fir_coeff[4];
                fir_coeff[6] <= fir_coeff[5];
                fir_coeff[7] <= fir_coeff[6];
                
                // Let the filter start fresh from mode switch
                state_q <= M1;
                result_adder_q <= 19'b0;

            end 
            else begin  // Shift data when mode = 0
                if (state_q == M2) begin
                    data_pipeline[0] <= data_in_signed;
                    // data_pipeline[0] <= data_in;
                    data_pipeline[1] <= data_pipeline[0];
                    data_pipeline[2] <= data_pipeline[1];
                    data_pipeline[3] <= data_pipeline[2];
                    data_pipeline[4] <= data_pipeline[3];
                    data_pipeline[5] <= data_pipeline[4];
                    data_pipeline[6] <= data_pipeline[5];
                    data_pipeline[7] <= data_pipeline[6];

                end
                result_adder_q <= result_adder_d;
                state_q <= state_d;
            end
        end 
    end

    // Combinational logics
    always @(*) begin
        case (state_q)
            M1 : begin
                state_d = M2;

                output_valid = 1'b0;

                data_pipeline_split[0] = data_pipeline[0];
                data_pipeline_split[1] = data_pipeline[1];
                data_pipeline_split[2] = data_pipeline[2];
                data_pipeline_split[3] = data_pipeline[3];

                fir_coefficient_split[0] = fir_coeff[0];
                fir_coefficient_split[1] = fir_coeff[1];
                fir_coefficient_split[2] = fir_coeff[2];
                fir_coefficient_split[3] = fir_coeff[3];

                carry_over = 19'b0;
            end
            M2 : begin
                state_d = M1;

                output_valid = 1'b1;
                
                data_pipeline_split[0] = data_pipeline[4];
                data_pipeline_split[1] = data_pipeline[5];
                data_pipeline_split[2] = data_pipeline[6];
                data_pipeline_split[3] = data_pipeline[7];

                fir_coefficient_split[0] = fir_coeff[4];
                fir_coefficient_split[1] = fir_coeff[5];
                fir_coefficient_split[2] = fir_coeff[6];
                fir_coefficient_split[3] = fir_coeff[7];

                carry_over = result_adder_q;
            end 
=======
    reg [2:0] phase;
    
    // 1. REDUCED MEMORY DEPTH (Now 14 elements instead of 16)
    reg signed [7:0]  fir_coeff [0:15];
    reg signed [7:0]  data_pipe [0:15];
    
    // Accumulator stays at 20 bits to safely hold 14 summed products
    reg signed [19:0] acc; 
    reg [7:0] result_reg; 
    
    integer i;
    wire signed [7:0] data_in_s = {~data_in[7], data_in[6:0]};
    
    // 2. MUX ARRAY
    reg signed [7:0] mux_d [0:3], mux_c [0:3];
    always @(*) begin

        case (phase)
            3'b000: begin mux_d[0] = data_in_s;     mux_c[0] = fir_coeff[0]; 
                          mux_d[1] = data_pipe[0];  mux_c[1] = fir_coeff[1]; end
                          
            3'b001: begin mux_d[0] = data_pipe[1];  mux_c[0] = fir_coeff[2]; 
                          mux_d[1] = data_pipe[2];  mux_c[1] = fir_coeff[3]; end
                          
            3'b010: begin mux_d[0] = data_pipe[3];  mux_c[0] = fir_coeff[4]; 
                          mux_d[1] = data_pipe[4];  mux_c[1] = fir_coeff[5]; end
                          
            3'b011: begin mux_d[0] = data_pipe[5];  mux_c[0] = fir_coeff[6]; 
                          mux_d[1] = data_pipe[6];  mux_c[1] = fir_coeff[7]; end
                          
            3'b100: begin mux_d[0] = data_pipe[7];  mux_c[0] = fir_coeff[8]; 
                          mux_d[1] = data_pipe[8];  mux_c[1] = fir_coeff[9]; end
                          
            3'b101: begin mux_d[0] = data_pipe[9];  mux_c[0] = fir_coeff[10]; 
                          mux_d[1] = data_pipe[10]; mux_c[1] = fir_coeff[11]; end
                          
            3'b110: begin mux_d[0] = data_pipe[11]; mux_c[0] = fir_coeff[12]; 
                          mux_d[1] = data_pipe[12]; mux_c[1] = fir_coeff[13]; end
                          
            3'b111: begin mux_d[0] = data_pipe[13]; mux_c[0] = fir_coeff[14]; 
                          mux_d[1] = data_pipe[14]; mux_c[1] = fir_coeff[15]; end
>>>>>>> Stashed changes
        endcase

    end

<<<<<<< Updated upstream
    wire [7:0] data_out_signed;

    // Q8.7 format, discard 7 bits = 8 bit signed num
    // 8 bit signed + 128 scale back to unsigned
    // Use bit flip as +128 operation, dont care about overflow
    assign data_out_signed = {~result_adder_d[14], result_adder_d[13:7]};
    assign data_out = output_valid ? data_out_signed : 8'b0;
    // assign data_out = output_valid ? result_adder_d[14:7] : 8'b0;
=======
    // Math engine must still have 4 multipliers to handle 14 taps in 4 cycles
    wire signed [15:0] p0 = mux_d[0] * mux_c[0];
    wire signed [15:0] p1 = mux_d[1] * mux_c[1];
    
    wire signed [16:0] math_out = $signed(p0) + $signed(p1);
    wire signed [19:0] next_acc = acc + math_out;

    // --- State Machine ---
    always @(posedge clk) begin
        if (!rst_n) begin
            phase <= 3'd0;
            acc   <= 20'sd0;
            result_reg <= 8'h80; 
            // 4. LOOP BOUNDARIES CAPPED AT 14
            for (i=0; i<16; i=i+1) begin
                fir_coeff[i] <= 8'sd0;
                data_pipe[i] <= 8'sd0;
            end
        end 
        else if (mode) begin
            fir_coeff[0] <= $signed(data_in);
            // 4. LOOP BOUNDARIES CAPPED AT 13
            for (i=1; i<16; i=i+1) fir_coeff[i] <= fir_coeff[i-1];
            phase <= 3'd0;
            acc   <= 20'sd0;
        end 
        else begin
            phase <= phase + 1'b1;
            
            if (phase == 3'b000) 
                acc <= math_out;
            else 
                acc <= next_acc;
            
            // 5. TRIGGER ON FINAL PHASE (Phase 7)
            if (phase == 3'b111) begin
                result_reg <= {~next_acc[14], next_acc[13:7]};
                
                for (i=15; i>0; i=i-1) data_pipe[i] <= data_pipe[i-1];
                data_pipe[0] <= data_in_s;
            end
        end
    end
>>>>>>> Stashed changes


    multiplier_x4 m1 (
        .a0(data_pipeline_split[0]),
        .a1(data_pipeline_split[1]),
        .a2(data_pipeline_split[2]),
        .a3(data_pipeline_split[3]),
        .b0(fir_coefficient_split[0]),
        .b1(fir_coefficient_split[1]),
        .b2(fir_coefficient_split[2]),
        .b3(fir_coefficient_split[3]),
        .out0(result_partial[0]),
        .out1(result_partial[1]),
        .out2(result_partial[2]),
        .out3(result_partial[3])
    );

    adder_x5 m2 (
        .in0(result_partial[0]),
        .in1(result_partial[1]),
        .in2(result_partial[2]),
        .in3(result_partial[3]),
        .carry_over(carry_over),
        .out(result_adder_d)
    );

    // TEMPORARY
    // Prevent registers from be optimized out
    // assign data_out = fir_coeff[data_in[2:0]];

endmodule

module multiplier_x4(
    input  wire signed [7:0] a0,
    input  wire signed [7:0] a1,
    input  wire signed [7:0] a2,
    input  wire signed [7:0] a3,
    input  wire signed [7:0] b0,
    input  wire signed [7:0] b1,
    input  wire signed [7:0] b2,
    input  wire signed [7:0] b3,
    output wire signed [15:0] out0,
    output wire signed [15:0] out1,
    output wire signed [15:0] out2,
    output wire signed [15:0] out3
);
    assign out0 = a0*b0;
    assign out1 = a1*b1;
    assign out2 = a2*b2;
    assign out3 = a3*b3;
endmodule

module adder_x5 (
    input  wire signed [15:0] in0,
    input  wire signed [15:0] in1,
    input  wire signed [15:0] in2,
    input  wire signed [15:0] in3,
    input  wire signed [18:0] carry_over,
    output wire signed [18:0] out
);
    assign out = in0 + in1 + in2 + in3 + carry_over;
endmodule