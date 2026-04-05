`default_nettype none

module tt_um_factory_test (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
  
  // Instantiating your 4-stage folded FIR design
  dsp_fir m1 (
    .data_in(ui_in),          // Dedicated 8-bit input pins
    .data_out(uo_out),        // Dedicated 8-bit output pins
    .mode(uio_in[0]),         // Using Bi-directional pin 0 as the 'mode' toggle
    .clk(clk),                // System clock
    .rst_n(rst_n)             // Active-low reset
  );

  // Tie off unused inputs to prevent floating logic and suppress linter warnings.
  // We are not using 'ena' or 'uio_in' pins 1 through 7.
  wire _unused_pins = &{ena, uio_in[7:1], 1'b0};
  
  // Set all bi-directional IOs to Input mode (Enable = 0)
  // and drive their output path to 0 to be safe.
  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;

endmodule  // tt_um_factory_test