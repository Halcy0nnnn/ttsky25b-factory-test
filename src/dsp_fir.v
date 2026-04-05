`timescale 1ps / 1ps
`default_nettype none

module dsp_fir (
    input  wire [7:0] data_in,    
    output wire [7:0] data_out,   
    input  wire       mode,       
    input  wire       clk,      
    input  wire       rst_n     
);

    reg [1:0] phase;
    
    // 1. REDUCED MEMORY DEPTH (Now 14 elements instead of 16)
    reg signed [7:0]  fir_coeff [0:11];
    reg signed [7:0]  data_pipe [0:11];
    
    // Accumulator stays at 20 bits to safely hold 14 summed products
    reg signed [19:0] acc; 
    reg [7:0] result_reg; 
    
    integer i;
    wire signed [7:0] data_in_s = {~data_in[7], data_in[6:0]};
    
    // 2. MUX ARRAY
    reg signed [7:0] mux_d [0:2], mux_c [0:2];
    always @(*) begin
        case (phase)
            2'b00: begin mux_d[0] = data_in_s;     mux_c[0] = fir_coeff[0]; 
                         mux_d[1] = data_pipe[0];  mux_c[1] = fir_coeff[1]; 
                         mux_d[2] = data_pipe[1];  mux_c[2] = fir_coeff[2]; end
                         
            2'b01: begin mux_d[0] = data_pipe[2];  mux_c[0] = fir_coeff[3]; 
                         mux_d[1] = data_pipe[3];  mux_c[1] = fir_coeff[4]; 
                         mux_d[2] = data_pipe[4];  mux_c[2] = fir_coeff[5]; end
                         
            2'b10: begin mux_d[0] = data_pipe[5];  mux_c[0] = fir_coeff[6]; 
                         mux_d[1] = data_pipe[6];  mux_c[1] = fir_coeff[7]; 
                         mux_d[2] = data_pipe[7];  mux_c[2] = fir_coeff[8]; end
                         
            2'b11: begin mux_d[0] = data_pipe[8];  mux_c[0] = fir_coeff[9]; 
                         mux_d[1] = data_pipe[9];  mux_c[1] = fir_coeff[10]; 
                         mux_d[2] = data_pipe[10]; mux_c[2] = fir_coeff[11]; end
        endcase
    end

    // Math engine must still have 4 multipliers to handle 14 taps in 4 cycles
    wire signed [15:0] p0 = mux_d[0] * mux_c[0];
    wire signed [15:0] p1 = mux_d[1] * mux_c[1];
    wire signed [15:0] p2 = mux_d[2] * mux_c[2];
    
    wire signed [17:0] math_out = $signed(p0) + $signed(p1) + $signed(p2);
    wire signed [19:0] next_acc = acc + math_out;

    // --- State Machine ---
    always @(posedge clk) begin
        if (!rst_n) begin
            phase <= 2'd0;
            acc   <= 20'sd0;
            result_reg <= 8'h80; 
            // 4. LOOP BOUNDARIES CAPPED AT 14
            for (i=0; i<12; i=i+1) begin
                fir_coeff[i] <= 8'sd0;
                data_pipe[i] <= 8'sd0;
            end
        end 
        else if (mode) begin
            fir_coeff[0] <= $signed(data_in);
            // 4. LOOP BOUNDARIES CAPPED AT 13
            for (i=1; i<12; i=i+1) fir_coeff[i] <= fir_coeff[i-1];
            phase <= 2'd0;
            acc   <= 20'sd0;
        end 
        else begin
            phase <= phase + 1'b1;
            
            if (phase == 2'b00) 
                acc <= math_out;
            else 
                acc <= next_acc;
            
            if (phase == 2'b11) begin
                result_reg <= {~next_acc[14], next_acc[13:7]};
                
                // 4. LOOP BOUNDARIES CAPPED AT 11
                for (i=11; i>0; i=i-1) data_pipe[i] <= data_pipe[i-1];
                data_pipe[0] <= data_in_s;
            end
        end
    end

    assign data_out = result_reg;

endmodule