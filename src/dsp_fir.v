`timescale 1ps / 1ps
`default_nettype none

module dsp_fir (
    input  wire [7:0] data_in,    
    output wire [7:0] data_out,   
    input  wire       mode,       
    input  wire       clk,      
    input  wire       rst_n     
);

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
        endcase

    end

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

    assign data_out = result_reg;

endmodule