// arm_multi.v
// David_Harris@hmc.edu, Sarah_Harris@hmc.edu 25 December 2013
// Multi-cycle implementation of a subset of ARMv4

// 16 registros de 32 bits
`timescale 1ns/1ps



// controlador (FSM + lógica condicional)

// controlador (FSM + lógica condicional)
module controller (
	clk,
	reset,
	Instr,
	ALUFlags,
	PCWrite,
	MemWrite,
	RegWrite,
	IRWrite,
	AdrSrc,
	RegSrc,
	ALUSrcA,
	ALUSrcB,
	ResultSrc,
	ImmSrc,
	ALUControl,
	IsMul, 
  MullWb
);
	input  wire        clk, reset;
	input  wire [31:0] Instr;        // ***Cambio: ahora se pasa instrucción completa
	input  wire [3:0]  ALUFlags;
	output wire        PCWrite, MemWrite, RegWrite, IRWrite, AdrSrc, IsMul;
  output wire [1:0]  RegSrc, ALUSrcA, ALUSrcB, ResultSrc, ImmSrc, MullWb;
	output wire [2:0]  ALUControl;

	// ***Cambio: ALUOp es señal local –­no sale del controlador
	wire               ALUOp;
	wire [1:0]         FlagW;
	wire               PCS, NextPC, RegW, MemW;
	

	decode dec(
		.clk       (clk),
		.reset     (reset),
		.Op        (Instr[27:26]),
		.Funct     (Instr[25:20]),
		.Rd        (Instr[15:12]),
		.FlagW     (FlagW),
		.PCS       (PCS),
		.NextPC    (NextPC),
		.RegW      (RegW),
		.MemW      (MemW),
		.IRWrite   (IRWrite),
		.AdrSrc    (AdrSrc),
		.ResultSrc (ResultSrc),
		.ALUSrcA   (ALUSrcA),
		.ALUSrcB   (ALUSrcB),
		.ImmSrc    (ImmSrc),
		.RegSrc    (RegSrc),
		.ALUControl(ALUControl),
		.ALUOp     (ALUOp),      
      .instr     (Instr),
      .IsMul (IsMul), 
      .MullWb(MullWb)
	);

	condlogic cl(
		.clk      (clk),
		.reset    (reset),
		.Cond     (Instr[31:28]),
		.ALUFlags (ALUFlags),
		.FlagW    (FlagW),
		.PCS      (PCS),
		.NextPC   (NextPC),
		.RegW     (RegW),
		.MemW     (MemW),
		.PCWrite  (PCWrite),
		.RegWrite (RegWrite),
		.MemWrite (MemWrite)
	);
endmodule

// lógica condicional y registro de flags
module condlogic (
	clk,
	reset,
	Cond,
	ALUFlags,
	FlagW,
	PCS,
	NextPC,
	RegW,
	MemW,
	PCWrite,
	RegWrite,
	MemWrite
);
	input  wire        clk, reset;
	input  wire [3:0]  Cond;
	input  wire [3:0]  ALUFlags;
	input  wire [1:0]  FlagW;
	input  wire        PCS, NextPC, RegW, MemW;
	output wire        PCWrite, RegWrite, MemWrite;
	wire   [1:0]       FlagWrite;
	wire   [3:0]       Flags;
	wire               CondEx, CurrentCondEx, PCSrc;

	// registro de N/Z y C/V
	flopenr #(2) flagreg1(
		.clk(clk), .reset(reset),
		.en (FlagWrite[1]),
		.d  (ALUFlags[3:2]),
		.q  (Flags[3:2])
	);
	flopenr #(2) flagreg0(
		.clk(clk), .reset(reset),
		.en (FlagWrite[0]),
		.d  (ALUFlags[1:0]),
		.q  (Flags[1:0])
	);
	// chequeo de condición
	condcheck cc0(
		.Cond  (Cond),
		.Flags (Flags),
		.CondEx(CondEx)
	);
	// sincroniza CondEx
	flopr #(1) condexreg(
		.clk(clk), .reset(reset),
		.d  (CondEx),
		.q  (CurrentCondEx)
	);
	// escribe flags solo si S=1 y condición verdadera
	assign FlagWrite = FlagW & {2{CurrentCondEx}};
	// gating de escrituras
	assign RegWrite = RegW  & CurrentCondEx;
	assign MemWrite = MemW  & CurrentCondEx;
	assign PCSrc    = PCS   & CurrentCondEx;
	assign PCWrite  = PCSrc | NextPC;
endmodule


// decodificador de instrucción y ALU
module decode (
	clk,
	reset,
	Op,
	Funct,
	Rd,
	FlagW,
	PCS,
	NextPC,
	RegW,
	MemW,
	IRWrite,
	AdrSrc,
	ResultSrc,
	ALUSrcA,
	ALUSrcB,
	ImmSrc,
	RegSrc,
	ALUControl,
	ALUOp,        // ***Cambio: ahora es salida
	instr,
	IsMul, 
  MullWb
);
	input  wire        clk, reset;
	input  wire [31:0] instr;
	input  wire [1:0]  Op;
	input  wire [5:0]  Funct;
  input  wire [3:0]  Rd;
	output reg  [1:0]  FlagW;
	output wire        PCS, NextPC, RegW, MemW, IRWrite, AdrSrc, IsMul;
  output wire [1:0]  ResultSrc, ALUSrcA, ALUSrcB, ImmSrc, MullWb, RegSrc;
	output reg  [2:0]  ALUControl;
	output wire        ALUOp;  // ***Cambio
	wire               Branch;
	
    always @(*)
    begin
      
    end
	mainfsm fsm0(
		.clk       (clk),
		.reset     (reset),
		.Op        (Op),
		.Funct     (Funct),
		.IRWrite   (IRWrite),
		.AdrSrc    (AdrSrc),
		.ALUSrcA   (ALUSrcA),
		.ALUSrcB   (ALUSrcB),
		.ResultSrc (ResultSrc),
		.NextPC    (NextPC),
		.RegW      (RegW),
		.MemW      (MemW),
		.Branch    (Branch),
		.ALUOp     (ALUOp),   // ***Cambio
      .instr     (instr),
      .IsMul (IsMul), 
      .MullWb (MullWb)
	);

	always @(*) begin
		if (ALUOp) begin
			case (Funct[4:1])
				4'b0100: ALUControl = 3'b000; //ADD
				4'b0010: ALUControl = 3'b001; //SUB
				4'b0000: ALUControl = 3'b010; //AND
				4'b1100: ALUControl = 3'b011; //OR
              	4'b1101: 
                  begin                  // cmd = 1101  (shifts/MOV)
                    if (instr[25] == 1'b0 && instr[11:4] != 8'b00000000) ALUControl = 3'b100;   // LSL
                    else if (instr[25] == 1'b0 && instr[6:5] != 2'b01) ALUControl = 3'b100;   // LSR
                      else  ALUControl = 3'b100; //MOV
        			end
				default: ALUControl = 3'b000;
			endcase
			FlagW[1] = Funct[0];
			FlagW[0] = Funct[0] & ((ALUControl==3'b000) | (ALUControl==3'b010));
		end else begin
			ALUControl = 3'b000;
			FlagW      = 2'b00;
		end
	end

	assign PCS     = ((Rd==4'b1111) & RegW) | Branch;
	assign ImmSrc  = Op;
  	
  assign RegSrc[1] = Op == 2'b01 ;
  assign RegSrc[0] = Op == 2'b10;
endmodule






// máquina de estados principal
module mainfsm (
	clk,
	reset,
	Op,
	Funct,
	IRWrite,
	AdrSrc, //Cheka si hubo branch para ver si uso PC u otra dirección para sacar la siguiente instr
	ALUSrcA,
	ALUSrcB,
	ResultSrc,
	NextPC,
	RegW,
	MemW,
	Branch,
	ALUOp,
  	instr,
  	IsMul, 
  	MullWb
);
	input  wire        clk, reset;
	input  wire [1:0]  Op;
	input  wire [5:0]  Funct;
  	input wire [31:0] instr;
  
	output wire        NextPC, Branch, MemW, RegW, IRWrite, AdrSrc, ALUOp, IsMul;
  output wire [1:0]  ResultSrc, ALUSrcA, ALUSrcB, MullWb;

	reg    [3:0]  state, nextstate;
  reg    [15:0] controls;
	
	localparam FETCH    = 4'd0, //Sacamos la instr de Memory y la colocamos en un flipflop | Actualizamos pc
	           DECODE   = 4'd1, //No hace nada, mantiene casi todo igual, Pero seleccionamos los operandos
	           MEMADR   = 4'd2,
	           MEMRD    = 4'd3,
	           MEMWB    = 4'd4,
	           MEMWR    = 4'd5,
	           EXECUTER = 4'd6, //Ejecuta la operación con Rn Rn
	           EXECUTEI = 4'd7, //Ejecuta la operación con Rn inmediato
	           ALUWB    = 4'd8,
	           BRANCH   = 4'd9,
  			   MUL_DECODE = 4'd10,
  			   MUL_LONG_WB_LO  = 4'd11,  // primera escritura (Lo)
               MUL_LONG_WB_HI  = 4'd12,  // segunda escritura (Hi)
  			   FLOAT_WB = 4'd13, //writeback para operaciones flotantes	
  				
  
               UNKNOWN  = 4'd14;				
	
  // registro de estado
	always @(posedge clk or posedge reset)
		if (reset) state <= FETCH;
		else       state <= nextstate;

	// lógica nextstate
	always @(*) begin
		casex (state)
          
          FETCH: nextstate = DECODE; //DP, MEMORY, BRANCH          		
          DECODE:
            case (Op)
              2'b00:

                if (instr[27:24] == 4'b0000 && instr[7:4] == 4'b1001) 

                  nextstate = MUL_DECODE; // Para el mull

                else if (Funct[5])
                  nextstate = EXECUTEI;
                else
                  nextstate = EXECUTER;


              2'b01: nextstate = MEMADR;

              2'b10: nextstate = BRANCH;

              2'b11: nextstate = FLOAT_WB;

              default: nextstate = UNKNOWN;
            endcase


          // Load/Store
          MEMADR:   nextstate = Funct[0] ? MEMRD : MEMWR;
          MEMRD:    nextstate = MEMWB;
          MEMWB:    nextstate = FETCH;
          MEMWR:    nextstate = FETCH;

          // ALU normal (ADD, SUB, AND, ORR, MUL low32)
          EXECUTER: nextstate = ALUWB;
          EXECUTEI: nextstate = ALUWB;

          MUL_DECODE: nextstate = MUL_LONG_WB_LO;

          MUL_LONG_WB_LO: begin
            case (instr[23:21])
              3'b000, 3'b001:    nextstate = FETCH;           // MUL low-32 o DIV
              3'b100,
              3'b110:    nextstate = MUL_LONG_WB_HI;  // UMULL/SMULL
              default:   nextstate = UNKNOWN;
            endcase
          end

          MUL_LONG_WB_HI: nextstate = FETCH;

          ALUWB: nextstate = FETCH;


          //Para branch
          BRANCH:   nextstate = FETCH;


          //PARA FLOATING POINT

          FLOAT_WB: nextstate = FETCH;


          default:  nextstate = FETCH;
		endcase
	end

	// salidas por estado
	always @(*) begin
		case (state)
			// NextPC, Branch, MemW, RegW, IRWrite, AdrSrc, ResultSrc, ALUSrcA, ALUSrcB, ALUOp
          	
          	// Pone la instr en registro y actualiza el siguiente PC como PC+4
			FETCH:        controls = 16'b1000101001100000; //ALUSRCB es 10 para sumar 4 a PC y ALUsrcA es PC, para preparar a PCnext con la siguiente instrucción
          
			DECODE:       controls = 16'b0000001001100000;
          	
          	MUL_DECODE:   controls = 16'b0000001001100100;
          
			MEMADR:       controls = 16'b0000000000010000; // Rn+off
			MEMRD:        controls = 16'b0000010000000000; // lectura memoria
			MEMWB:        controls = 16'b0001000100000000; // write-back LDR
			MEMWR:        controls = 16'b0010010000000000; // STR
			EXECUTER:     controls = 16'b0000000000001000; // ALU Rn,Rm

          	EXECUTEI:     controls = 16'b0000000000011000; // ALU Rn,imm			

			BRANCH:   controls     = 16'b0100001010010000; // branch
            ALUWB:        controls = 16'b0001000000000000; // write-back ALU
          
          MUL_LONG_WB_LO: controls = 16'b0001000000000101; //WB parte baja
        
          	
       	  MUL_LONG_WB_HI: controls = 16'b0001000000000110; //WB parte alta
          
          FLOAT_WB: controls = 16'b0001000000000011; //WB parte alta
          	
			default:  controls = 16'bx;
		endcase
    end  //1bit   1bit    1bit   1bit  1bit     1bit    2bit       2bit     2bit     1bit   1bit  2bit
  assign {NextPC, Branch, MemW, RegW, IRWrite, AdrSrc, ResultSrc, ALUSrcA, ALUSrcB, ALUOp, IsMul, MullWb} = controls;
  
endmodule

module datapath (
	clk,
	reset,
	Adr,
	Data_escribir_memoria,
	ReadData,
	Instr,
	ALUFlags,
	PCWrite,
	RegWrite,
	IRWrite,
	AdrSrc,
	RegSrc,
	ALUSrcA,
	ALUSrcB,
	ResultSrc,
	ImmSrc,
	ALUControl,
  IsMul,
  MullWb
);
	input  wire        clk, reset;
	output wire [31:0] Adr, Data_escribir_memoria;
	input  wire [31:0] ReadData;
	output wire [31:0] Instr;
	output wire [3:0]  ALUFlags;
	input  wire        PCWrite, RegWrite, IRWrite, AdrSrc, IsMul;
  input  wire [1:0]   ALUSrcA, ALUSrcB, ResultSrc, ImmSrc, MullWb, RegSrc;
	input  wire [2:0]  ALUControl;                    // ***Cambio: ahora 3 bits
	wire [31:0] PC, ExtImm, SrcA, SrcB, Result, Data;
  wire [31:0] RD1, RD2, A, ALUResult, ALUOut, LastALUOut;
	wire [31:0] HIReg;
  wire [3:0]  RA1, RA2, RA1OUT, RA2OUT;
  wire [3:0] WD3;
  
	// --- multiplicador
  wire [31:0] mull_lo, mull_hi, mull_lo_OUT, mull_hi_OUT;
  	//--- FLOAT
  wire [31:0] float_out;
  	//---shift
  wire [31:0] shift_out;
  
  

    //--------------------------REGISTRO PARA PC
  
  	// PC
	flopenr #(32) pcreg(
		.clk(clk), .reset(reset),
		.en (PCWrite),
		.d  (Result),
		.q  (PC)
	);
	
  	mux2 #(32) adrmux(
		.d0 (PC),
      	.d1 (Result),                
		.s  (AdrSrc),
		.y  (Adr)
	);
  
  	//----------------------------REGISTROS QUE SALEN DE MAIN MEMORY
  
  	// MDR
	flopr #(32) mdr(
		.clk(clk), .reset(reset),
		.d (ReadData),
		.q (Data)
	);
  	
  	// instruction register
	flopenr #(32) instrreg(
		.clk(clk), .reset(reset),
		.en (IRWrite),
		.d (ReadData),
		.q (Instr)
	);
  
  //---------------------------MUX DE LAS OPERACIONES PRINCIPALES QUE SACAMOS CON DECODE (MEMORY, DP o BRANCH)
  
	mux2 #(4) ra1mux(
		.d0(Instr[19:16]),
		.d1(4'b1111),
		.s(RegSrc[0]),
		.y(RA1)
	);
	mux2 #(4) ra2mux(
		.d0(Instr[3:0]),
		.d1(Instr[15:12]),
		.s(RegSrc[1]),
		.y(RA2)
	);
  
  
  //---------------------------LOGICA AGREGADA PARA EL MODULO MUL

  
  // PARA SABER SI ES MUL
  mux2 #(4) raOUT1mux(
    .d0(RA1),
    .d1(Instr[3:0]),
    .s(IsMul),
    .y(RA1OUT)
	);

  mux2 #(4) raOUT2mux(
      .d0(RA2),
      .d1(Instr[11:8]),
      .s(IsMul),
      .y(RA2OUT)
	);
  
  mull_unit mul (
		.a   (A),
		.b   (Data_escribir_memoria),
		.cmd (Instr[23:21]),
		.lo  (mull_lo),
		.hi  (mull_hi)
	);
  
    
  flopr2 #(32) regdataregMULL(
		.clk(clk),
		.reset(reset),
		.d0(mull_lo),
		.d1(mull_hi),
      .q0(mull_lo_OUT),
      .q1(mull_hi_OUT)
	);
  
  
   //---------------------------LOGICA AGREGADA PARA EL FLOATING POINT
  floating_operation f_point
  (
    .op(Instr[22:21]),
    .a(A),
    .b(Data_escribir_memoria),
    .y(float_out)
  );
  
  //-----------------------------LOGICA PARA EL SHIFT
  
  

  shift barrel (
      .a_input (Data_escribir_memoria),  
      .shamt   (Instr[11:7]),            
    .direction(Instr[5]),         
      .a_output(shift_out)
  );
  
  
  
  
  	//-----------------------REGISTER FILE
  regfile rf(
		.clk  (clk),
		.we3  (RegWrite),
      	.ra1  (RA1OUT),
		.ra2  (RA2OUT),
        .wa3  (WD3),
		.wd3  (Result),
		.r15  (Result),          
		.rd1  (RD1),
		.rd2  (RD2),
		.reset(reset)
	);
    //Mux de 3 que decide donde se van a escribir los registro
  assign WD3 = (MullWb == 2'b00 || MullWb == 2'b11 ) ? Instr[15:12] :  Instr[19:16];
  

    
  
  //--------------------------CAMINO PARA LAS OPERACIONES NORMALES
  
  	// operand registers
	flopr2 #(32) abreg(
		.clk(clk), .reset(reset),
		.d0(RD1), .d1(RD2),
		.q0(A),   .q1(Data_escribir_memoria)
	);
  
  	
  	extend ext(
		.Instr (Instr[23:0]),          
		.ImmSrc(ImmSrc),
		.ExtImm(ExtImm)
	);

  

	// ALU sources
	mux3 #(32) srcAmux(
		.d0 (A),
		.d1 (PC),
		.d2 (ALUOut),
      .s  (ALUSrcA[0]),
		.y  (SrcA)
	);

	mux3 #(32) srcBmux(
		.d0 (shift_out),
		.d1 (ExtImm),
		.d2 (32'd4),                 // ***Cambio: 32-bit literal
		.s  (ALUSrcB),
		.y  (SrcB)
	);
  
	


	// ALU
  alu alu0 (
      .a(SrcA),
      .b(SrcB),
      .ALUControl(ALUControl),
      .Result(ALUResult),
      .ALUFlags(ALUFlags)
  );

  
  flopr #(32) aluoutreg (
    .clk(clk), .reset(reset),
    .d  (ALUResult),
    .q  (ALUOut)
);
  
  	mux3 #(32) resmux(
		.d0(LastALUOut),
		.d1(Data),
		.d2(ALUResult),
		.s(ResultSrc),
		.y(Result)
	);
	

  //------------------------------MUX final para decidir que writeback se hace
  	// ALU sources
  mux4 #(32) lastWB(
    .d0 (ALUOut),
    .d1 (mull_lo),
    .d2 (mull_hi),
    .d3 (float_out),
    .s  (MullWb[1:0]),
    .y  (LastALUOut)
	);
    
endmodule

//-----------------------------------------------
// MÓDULO PARA FADD, FSUB, FMUL (IEEE-754)
//-----------------------------------------------

module floating_operation (
  input  wire [1:0]  op,        // 00 = ADD, 01 = SUB, 10 = MUL
  input  wire [31:0] a,
  input  wire [31:0] b,
  output wire [31:0] y
);
  wire [31:0] b_eff;
  wire [31:0] y_addsub, y_mul;

  // Cambiar signo de b si es resta
  assign b_eff = (op == 2'b01) ? {~b[31], b[30:0]} : b;

  // Suma / resta: siempre usamos op = 0 (suma)
  fp_add_single_comb u_addsub (
    .op(1'b0),      // siempre suma
    .a  (a),
    .b  (b_eff),
    .y  (y_addsub)
  );

  // Multiplicación (sin cambios)
  wire underflow, overflow;
  fp_multiplier u_mul (
    .in1      (a),
    .in2      (b),
    .product  (y_mul),
    .underflow(underflow),
    .overflow (overflow)
  );

  // Multiplexor de salida
  assign y = (op == 2'b10) ? y_mul : y_addsub;

endmodule



//-----------------------------------------------
//MODULO PARA LA MULTIPLICACION DE FLOATING POINT
//-----------------------------------------------

// fp_mul_single_comb.v ── Multiplicación IEEE-754 (simple, ADD=0x7F)

// Multiplicador IEEE-754 integrado al procesador ARM multiciclo (módulo único)
module fp_multiplier(
  input  wire [31:0] in1,
  input  wire [31:0] in2,
  output wire [31:0] product,
  output wire underflow,
  output wire overflow
);

  wire sign;
  wire [7:0] exp_sum;
  wire [8:0] exp_bias_sub;
  wire [47:0] mantissa_product;
  wire [22:0] normalized_mantissa;
  wire norm_flag;
  wire carry_exp_sum;

  // Bit de signo
  assign sign = in1[31] ^ in2[31];

  // Suma de exponentes
  assign {carry_exp_sum, exp_sum} = in1[30:23] + in2[30:23];

  // Resta de sesgo (127)
  assign exp_bias_sub = {carry_exp_sum, exp_sum} - 9'd127;
  assign underflow = exp_bias_sub[8];
  assign overflow = (exp_bias_sub[7:0] >= 8'd255);

  // Producto de mantisas
  assign mantissa_product = {1'b1, in1[22:0]} * {1'b1, in2[22:0]};

  // Normalización
  assign norm_flag = mantissa_product[47];
  assign normalized_mantissa = norm_flag ? mantissa_product[46:24] : mantissa_product[45:23];

  // Exponente ajustado tras normalización
  wire [7:0] final_exp;
  assign final_exp = exp_bias_sub[7:0] + norm_flag;

  // Producto final
  assign product = {sign, final_exp, normalized_mantissa};

endmodule

//-------------------------------------
// MODULO PARA LA SUMA DE FLOATING POINT
//-------------------------------------

module fp_add_single_comb (
    input  wire        op,          // 0 = add, 1 = sub
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg  [31:0] y
);
    // 1) Campos
    wire sa = a[31], sb = b[31];
    wire [7:0]  ea = a[30:23], eb = b[30:23];
    wire [22:0] fa = a[22:0],  fb = b[22:0];
    wire sb_eff = op ? ~sb : sb;             // signo efectivo de B

    // 2) Casos especiales
    wire a_nan  =  ea==8'hFF && |fa;
    wire b_nan  =  eb==8'hFF && |fb;
    wire a_inf  =  ea==8'hFF &&  fa==0;
    wire b_inf  =  eb==8'hFF &&  fb==0;
    wire a_zero =  ea==0     &&  fa==0;
    wire b_zero =  eb==0     &&  fb==0;

    // 3) Mantisas extendidas (hidden-1 + 23 bits + guard = 25 bits)
    wire [24:0] ma_ext = ea==0 ? {1'b0, fa, 1'b0} : {1'b1, fa, 1'b0};
    wire [24:0] mb_ext = eb==0 ? {1'b0, fb, 1'b0} : {1'b1, fb, 1'b0};

    // Registros intermedios
    reg  [24:0] m_big, m_sml;
    reg  [25:0] sum;                // 25+1 bits
    reg  [24:0] norm;               // después de normalizar
    reg  [7:0]  e_big, e_res;
    reg         s_big, s_sml, s_res;
    integer     sh;

    always @* begin
        // ---------------- Casos especiales ----------------
        if (a_nan || b_nan)                y = {1'b0,8'hFF,1'b1,22'b0};        // NaN
        else if (a_inf && b_inf)  y = (sa^sb_eff) ? {1'b0,8'hFF,1'b1,22'b0}
                                                  : {sa,8'hFF,23'b0};          // ±∞ ±∞
        else if (a_inf)                     y = {sa,8'hFF,23'b0};
        else if (b_inf)                     y = {sb_eff,8'hFF,23'b0};
        else if (a_zero && b_zero)          y = {(sa & sb_eff),31'b0};
        else if (a_zero)                    y = { sb_eff, eb, fb};
        else if (b_zero)                    y = { sa,     ea, fa};
        // ---------------- Camino normal -------------------
        else begin
            // 3) Alinear exponentes
            if (ea >= eb) begin
                sh      = ea - eb;
                m_big   = ma_ext;
                m_sml   = (sh > 24) ? 25'b0 : mb_ext >> sh;
                e_big   = ea;
                s_big   = sa;
                s_sml   = sb_eff;
            end else begin
                sh      = eb - ea;
                m_big   = mb_ext;
                m_sml   = (sh > 24) ? 25'b0 : ma_ext >> sh;
                e_big   = eb;
                s_big   = sb_eff;
                s_sml   = sa;
            end

            // 4) Sumar / restar mantisas
            if (s_big == s_sml) begin
                sum   = {1'b0, m_big} + {1'b0, m_sml};   // mismo signo
                s_res = s_big;
            end else if (m_big >= m_sml) begin
                sum   = {1'b0, m_big} - {1'b0, m_sml};
                s_res = s_big;
            end else begin
                sum   = {1'b0, m_sml} - {1'b0, m_big};
                s_res = s_sml;
            end

            // 5) Normalización  (round-to-zero)
            e_res = e_big;
            if (sum[25]) begin                 // carry en bit-25  (10.xxxx)
                norm  = sum[25:1];             // desplazar der
                e_res = e_res + 1;
            end else begin
                norm  = sum[24:0];
                while (norm[24]==0 && e_res>0) begin
                    norm  = norm << 1;
                    e_res = e_res - 1;
                end
            end

            // 6) Empaquetar  (norm[24]=hidden-1)
            y = { s_res, e_res, norm[23:1] };  // quitamos hidden-1 y guard
        end
    end
endmodule



//------------------
//MODULO PARA EL MUL
//------------------

module mull_unit(
	input  wire [31:0] a,
	input  wire [31:0] b,
	input  wire [2:0]  cmd,
	output reg  [31:0] lo,
	output reg  [31:0] hi
);
	wire [63:0] prod_u = a * b;
  wire [31:0] div_u = a / b; //Acá nomás la división
	wire [63:0] prod_s = $signed(a) * $signed(b);
always @(*) begin
  case (cmd)
    3'b000: begin          // MUL (low-32)
      lo = prod_u[31:0];   hi = 32'b0;
    end
    
    3'b001: begin         // Para la división
      lo = div_u;           hi = 32'b0; 
    end
    
    3'b100: begin          // UMULL  (unsigned)
      lo = prod_u[31:0];   hi = prod_u[63:32];
    end
    3'b110: begin          // SMULL  (signed)
      lo = prod_s[31:0];   hi = prod_s[63:32];
    end
    default: begin
      lo = 32'bx;          hi = 32'bx;
    end
  endcase
end
endmodule


//---------------------------------------------------------------------
// ALU de 4 operaciones básicas y el mov y generación de flags {N,Z,C,V} (NO TOCAR)
//---------------------------------------------------------------------

module alu(input  [31:0] a, b,
           input  [2:0]  ALUControl,
           output reg [31:0] Result,
           output wire [3:0]  ALUFlags);
    
	wire        neg, zero, carry, overflow;
    wire [31:0] condinvb;
    wire [32:0] sum;

    assign condinvb = ALUControl[0] ? ~b : b;
    assign sum = a + condinvb + ALUControl[0];

    always @(*)
    begin
      casex (ALUControl[2:0])
        3'b000: Result = sum;
        3'b001: Result = sum;
        3'b010: Result = a & b;
        3'b011: Result = a | b;
        3'b100: Result = b;
        endcase
    end
    assign neg      = Result[31];
    assign zero     = (Result == 32'b0);
    assign carry    = (ALUControl[1] == 1'b0) & sum[32];
    assign overflow = (ALUControl[1] == 1'b0) & ~(a[31] ^ b[31] ^ ALUControl[0]) & (a[31] ^ sum[31]);
    assign ALUFlags = {neg, zero, carry, overflow};
endmodule




//-----------------------------------------
// MUX genéricos, flip-flops y el extensor (NO TOCAR)
//-----------------------------------------

module mux3 #(
    parameter WIDTH = 8
)(
    input  wire [WIDTH-1:0] d0,   // entrada 0
    input  wire [WIDTH-1:0] d1,   // entrada 1
    input  wire [WIDTH-1:0] d2,   // entrada 2
    input  wire [1:0]       s,    // selector
    output reg  [WIDTH-1:0] y     // salida
);

    always @(*) begin
        case (s)
            2'b00:   y = d0;              // selecciona d0
            2'b01:   y = d1;              // selecciona d1
            2'b10:   y = d2;              // selecciona d2
            default: y = {WIDTH{1'bx}};   // 2'b11 → indefinido
        endcase
    end

endmodule


module mux4 (
	d0, d1, d2, d3, s, y
);
	parameter WIDTH = 8;
  input  wire [WIDTH-1:0] d0, d1, d2, d3;
	input  wire [1:0]       s;
	output wire [WIDTH-1:0] y;
  assign y = s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0);
endmodule

module mux2 (
	d0, d1, s, y
);
	parameter WIDTH = 8;
	input  wire [WIDTH-1:0] d0, d1;
	input  wire             s;
	output wire [WIDTH-1:0] y;
	assign y = s ? d1 : d0;
endmodule

module flopenr (
	clk, reset, en, d, q
);
	parameter WIDTH = 8;
	input  wire             clk, reset, en;
	input  wire [WIDTH-1:0] d;
	output reg  [WIDTH-1:0] q;
	always @(posedge clk or posedge reset)
		if (reset)    q <= 0;
		else if (en)  q <= d;
endmodule

module flopr (
	clk, reset, d, q
);
	parameter WIDTH = 8;
	input  wire             clk, reset;
	input  wire [WIDTH-1:0] d;
	output reg  [WIDTH-1:0] q;
	always @(posedge clk or posedge reset)
		if (reset)    q <= 0;
		else          q <= d;
endmodule

module flopr2 (
	clk, reset, d0, d1, q0, q1
);
	parameter WIDTH = 8;
	input  wire             clk, reset;
	input  wire [WIDTH-1:0] d0, d1;
	output reg  [WIDTH-1:0] q0, q1;
	always @(posedge clk or posedge reset) begin
		if (reset) begin
			q0 <= 0; q1 <= 0;
		end else begin
			q0 <= d0;
			q1 <= d1;
		end
	end
endmodule


// banco de registros (NO ALMACENA R15, SOLO QUE SIEMPRE HAY UN CABLE QUE LO PASA A REGFILE)
//(NO TOCAR)
module regfile (
	clk, we3, ra1, ra2, wa3, wd3, r15, rd1, rd2, reset
);
	input  wire        clk, we3;
	input  wire [3:0]  ra1, ra2, wa3;
	input  wire [31:0] wd3, r15;
	output wire [31:0] rd1, rd2;
  input wire reset;
  reg    [31:0]      rf [0:15];
	integer            i;
  always @(posedge clk or posedge reset) begin
    if (reset)
			for (i=0; i<15; i=i+1) rf[i] <= 0;
  
        if (we3) rf[wa3] <= wd3;
  end
		
 
	assign rd1 = (ra1 == 4'b1111 ? r15 : rf[ra1]);
	assign rd2 = (ra2 == 4'b1111 ? r15 : rf[ra2]);
  
endmodule

// extensor de inmediato (NO TOCAR)
module extend (
	Instr,
	ImmSrc,
	ExtImm
);
	input wire [23:0] Instr;
	input wire [1:0] ImmSrc;
	output reg [31:0] ExtImm;
	always @(*)
		case (ImmSrc)
			2'b00: ExtImm = {24'b000000000000000000000000, Instr[7:0]};
			2'b01: ExtImm = {20'b00000000000000000000, Instr[11:0]};
			2'b10: ExtImm = {{6 {Instr[23]}}, Instr[23:0], 2'b00};
			default: ExtImm = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
		endcase
endmodule



//-----------
// Memoria   (NO TOCAR)
//-----------

module mem (
	clk,
	we,      // 1 = STR
	a,       // dirección
	DatoAEscribir,      // dato a escribir
	DatoLeido       // dato leído
);
  input  wire        clk, we;
	input  wire [31:0] a, DatoAEscribir;
	output wire [31:0] DatoLeido;
	reg    [31:0]      RAM [63:0];
	initial $readmemh("memfile.dat", RAM);
	assign DatoLeido = RAM[a[31:2]];
  	

  
	always @(posedge clk)
		if (we)
          // se guarda el dato de WD
          RAM[a[31:0]] <= DatoAEscribir; //Esto solo funciona si es que se activa el WE
endmodule

//-------------------------------------------------------------
// Barrel shifter lógico de 32 bits (NO TOCAR)
//-------------------------------------------------------------
module shift (
    input  wire [31:0] a_input,   // dato
    input  wire [4:0]  shamt,     // cantidad de desplazamiento (0-31)
    input  wire        direction, // 0 = LSL, 1 = LSR
    output reg  [31:0] a_output
);
    always @(*) begin
        case (direction)
            1'b0: a_output = a_input <<  shamt; // LSL
            1'b1: a_output = a_input >>  shamt; // LSR (lógico)
        endcase
    end
endmodule



//--------------------------------------------
// módulo que evalúa las 16 condiciones de ARM (NO TOCAR)
//--------------------------------------------

module condcheck (
	Cond,
	Flags,
	CondEx
);
	input  wire [3:0] Cond;
	input  wire [3:0] Flags; // {N,Z,C,V}
	output reg        CondEx;
	
	wire N       = Flags[3];
	wire Z       = Flags[2];
	wire C       = Flags[1];
	wire V       = Flags[0];
	wire ge      = (N == V);  
	
	always @(*)
		case (Cond)
			4'b0000: CondEx = Z;               // EQ
			4'b0001: CondEx = ~Z;              // NE
			4'b0010: CondEx = C;               // CS/HS
			4'b0011: CondEx = ~C;              // CC/LO
			4'b0100: CondEx = N;               // MI
			4'b0101: CondEx = ~N;              // PL
			4'b0110: CondEx = V;               // VS
			4'b0111: CondEx = ~V;              // VC
			4'b1000: CondEx = C & ~Z;          // HI
			4'b1001: CondEx = ~(C & ~Z);       // LS
			4'b1010: CondEx = ge;              // GE
			4'b1011: CondEx = ~ge;             // LT
			4'b1100: CondEx = ge & ~Z;         // GT
			4'b1101: CondEx = ~(ge & ~Z);      // LE
			4'b1110: CondEx = 1'b1;            // AL
			default: CondEx = 1'bx;
		endcase
endmodule


//TOP Y ARM (NO TOCAR, POR LO MAS SAGRADO DEL MUNDO)


module top (
	clk,
	reset,
	Data_escribir_memoria,
	Adr,
	MemWrite
);
	input  wire        clk;
	input  wire        reset;
	output wire [31:0] Data_escribir_memoria;
	output wire [31:0] Adr;
	output wire        MemWrite;
	wire   [31:0]      PC;
	wire   [31:0]      Instr;
	wire   [31:0]      ReadData;

	// instancia procesador y memoria unificada
	arm arm(
		.clk      (clk),
		.reset    (reset),
		.MemWrite (MemWrite),
		.Adr      (Adr),
		.Data_escribir_memoria(Data_escribir_memoria),
		.ReadData (ReadData)
	);
  
	mem mem(
		.clk(clk),
      	.we (MemWrite), //Hay escritura o solo lectura?
		.a  (Adr),
		.DatoAEscribir (Data_escribir_memoria),
      .DatoLeido (ReadData) //Dato que sale de ReadData
	);
endmodule





// módulo top-level del procesador
module arm (
	clk,
	reset,
	MemWrite,
	Adr,
	Data_escribir_memoria,
	ReadData
);
	input  wire        clk, reset;
	output wire        MemWrite;
	output wire [31:0] Adr;
	output wire [31:0] Data_escribir_memoria;
	input  wire [31:0] ReadData;
	wire   [31:0]      Instr;
	wire   [3:0]       ALUFlags;
	wire               PCWrite, RegWrite, IRWrite, AdrSrc, IsMul;
  wire   [1:0]       RegSrc, ALUSrcA, ALUSrcB, ImmSrc,  ResultSrc, MullWb;
    wire   [2:0] ALUControl;

	controller ctrl(
		.clk      (clk),
		.reset    (reset),
		.Instr    (Instr),
		.ALUFlags (ALUFlags),
		.PCWrite  (PCWrite),
		.MemWrite (MemWrite),
		.RegWrite (RegWrite),
		.IRWrite  (IRWrite),
		.AdrSrc   (AdrSrc),
		.RegSrc   (RegSrc),
		.ALUSrcA  (ALUSrcA),
		.ALUSrcB  (ALUSrcB),
		.ResultSrc(ResultSrc),
		.ImmSrc   (ImmSrc),
      .ALUControl(ALUControl),
      .IsMul (IsMul), 
      .MullWb (MullWb)
	);

	datapath dp(
		.clk       (clk),
		.reset     (reset),
		.Adr       (Adr),
		.Data_escribir_memoria (Data_escribir_memoria),
		.ReadData  (ReadData),
		.Instr     (Instr),
		.ALUFlags  (ALUFlags),
		.PCWrite   (PCWrite),
		.RegWrite  (RegWrite),
		.IRWrite   (IRWrite),
		.AdrSrc    (AdrSrc),
		.RegSrc    (RegSrc),
		.ALUSrcA   (ALUSrcA),
		.ALUSrcB   (ALUSrcB),
		.ResultSrc (ResultSrc),
		.ImmSrc    (ImmSrc),
      	.ALUControl(ALUControl),
      	.IsMul(IsMul), 
      	.MullWb(MullWb)
	);
endmodule
