`timescale 1ns/1ps

module testbench;
  // Señales de prueba
  reg         clk;
  reg         reset;
  wire [31:0] Adr;
  wire [31:0] WriteData;
  wire        MemWrite;

  // Instancia de tu top-level (módulo design)
  top uut (
    .clk      (clk),
    .reset    (reset),
    .Adr      (Adr),
    .Data_escribir_memoria(WriteData),
    .MemWrite (MemWrite)
  );

  // Reloj de 10 ns per.
  initial clk = 0; 
  always #5 clk = ~clk;

  // Scenario principal
  initial begin
    // Dump para GTKWave
    $dumpfile("multiciclo.vcd");
    $dumpvars(0, testbench);

    // Reset activo
    reset = 1;
    #20;
    reset = 0;

    // Deja correr varias instrucciones
    #800;

    // Lee directamente el banco de registros
    // (ajusta la jerarquía si tu rf está en otra ruta)
    $display("R0 = %h", uut.arm.dp.rf.rf[0]);
    $display("R1 = %h", uut.arm.dp.rf.rf[1]);
    $display("R2 = %h", uut.arm.dp.rf.rf[2]);
    $display("R3 = %h", uut.arm.dp.rf.rf[3]);
    $display("R4 = %h", uut.arm.dp.rf.rf[4]);
    $display("R5 = %h", uut.arm.dp.rf.rf[5]);
    $display("R6 = %h", uut.arm.dp.rf.rf[6]);
    $display("R7 = %h", uut.arm.dp.rf.rf[7]);
    $display("R8 = %h", uut.arm.dp.rf.rf[8]);
    $display("R9 = %h", uut.arm.dp.rf.rf[9]);
    $display("R10 = %h", uut.arm.dp.rf.rf[10]);
    $display("R11 = %h", uut.arm.dp.rf.rf[11]);
    $display("R12 = %h", uut.arm.dp.rf.rf[12]);
    $display("R13 = %h", uut.arm.dp.rf.rf[13]);
    $display("R14 = %h", uut.arm.dp.rf.rf[14]);
    $display("R15 = %h", uut.arm.dp.rf.rf[15]);

    $finish;
  end

  // Monitor de stores
  always @(posedge clk) begin
    if (MemWrite)
      $display("STORE @%h <= %h", Adr, WriteData);
  end

endmodule
