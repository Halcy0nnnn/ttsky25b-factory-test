`timescale 1ps / 1ps
`default_nettype none

module fir_3 (
    input  wire [7:0] data_in,    
    output wire [7:0] data_out,   
    input  wire       mode,       
    input  wire       clk,      
    input  wire       rst_n     
);

    reg [1:0] phase;
    reg signed [7:0]  fir_coeff [0:7];
    reg signed [7:0]  data_pipe [0:7];
    reg signed [18:0] acc; 
    reg [7:0] result_reg; 
    
    integer i;
    wire signed [7:0] data_in_s = {~data_in[7], data_in[6:0]};
    
    // --- Folding Muxes ---
    reg signed [7:0] mux_d [0:1], mux_c [0:1];
    always @(*) begin
        case (phase)
            2'b00: begin mux_d[0] = data_in_s;    mux_c[0] = fir_coeff[0]; 
                         mux_d[1] = data_pipe[0]; mux_c[1] = fir_coeff[1]; end
            2'b01: begin mux_d[0] = data_pipe[1]; mux_c[0] = fir_coeff[2]; 
                         mux_d[1] = data_pipe[2]; mux_c[1] = fir_coeff[3]; end
            2'b10: begin mux_d[0] = data_pipe[3]; mux_c[0] = fir_coeff[4]; 
                         mux_d[1] = data_pipe[4]; mux_c[1] = fir_coeff[5]; end
            2'b11: begin mux_d[0] = data_pipe[5]; mux_c[0] = fir_coeff[6]; 
                         mux_d[1] = data_pipe[6]; mux_c[1] = fir_coeff[7]; end
        endcase
    end

    // --- Math Engine ---
    wire signed [15:0] p0 = mux_d[0] * mux_c[0];
    wire signed [15:0] p1 = mux_d[1] * mux_c[1];
    // Explicit sizing prevents any wrap-around errors
    wire signed [17:0] math_out = $signed(p0) + $signed(p1);
    wire signed [18:0] next_acc = acc + math_out;

    // --- State Machine ---
    always @(posedge clk) begin
        if (!rst_n) begin
            phase <= 2'd0;
            acc   <= 19'sd0;
            result_reg <= 8'h80; // 128 Unsigned
            for (i=0; i<8; i=i+1) begin
                fir_coeff[i] <= 8'sd0;
                data_pipe[i] <= 8'sd0;
            end
        end 
        else if (mode) begin
            fir_coeff[0] <= $signed(data_in);
            for (i=1; i<8; i=i+1) fir_coeff[i] <= fir_coeff[i-1];
            phase <= 2'd0;
            acc   <= 19'sd0;
        end 
        else begin
            phase <= phase + 1'b1;
            
            if (phase == 2'b00) 
                acc <= math_out;
            else 
                acc <= next_acc;
            
            if (phase == 2'b11) begin
                result_reg <= {~next_acc[14], next_acc[13:7]};
                for (i=7; i>0; i=i-1) data_pipe[i] <= data_pipe[i-1];
                data_pipe[0] <= data_in_s;
            end
        end
    end

    assign data_out = result_reg;

endmodule