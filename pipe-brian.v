// basic sizes of things 
`define WORD  [15:0] // Standard word length
`define OP    [4:0] // opcode length
`define REG   [2:0] // reg location length
`define HWORD [7:0] // half word length
`define STATE [5:0]

`define OP1	  [15:11] // Typical opcode field
`define OP2   [7:3] // VLIW 2nd Op location
`define REG1  [10:8] // Typical opcode field 
`define REG2  [2:0] // VLIW 2nd Op location
`define IMM8  [7:0] // Immediate 8 bit value location

`define HIR1  [15:8] // first half of ir
`define HIR2  [7:0] // second half of ir

`define ACC1 3'b000 // Location for first accumulator
`define ACC2 3'b001 // Location for second accumulator
`define TYPEBIT 16 // Where the register type is defined (float = 1, int = 0)

// TODO: modify for our code
`define REGWORD [16:0]
`define REGSIZE [7:0]
`define MEMSIZE [65535:0]

// 8 bit operators - PHASE 1 DECODING
// opcode values, also state numbers
`define OPadd	5'b00000
`define OPsub	5'b00001
`define OPxor	5'b00010
`define OPand	5'b00011
`define OPor	5'b00100
`define OPnot	5'b00101
`define OPsh	5'b00110
`define OPslt	5'b00111
`define OPmul	5'b01000
`define OPdiv	5'b01001
`define OPa2r	5'b01010
`define OPr2a	5'b01011
`define OPlf	5'b01100
`define OPli	5'b01101
`define OPst	5'b01110
`define OPcvt	5'b01111
`define OPjr	5'b10000

// PHASE 2 DECODING
// 13 bit + 3 bit padding: pre jp8 sys
`define OPpre	5'b10001 // must be 17
`define OPjp8   5'b10010
`define OPsys   5'b10011

// 16 bit	
// cf8 ci8 jnz8 jz8
`define OPcf8	5'b10100
`define OPci8	5'b10101
`define OPjnz8	5'b10110
`define OPjz8	5'b10111

// special 
`define OPnop1   {`OPa2r, `ACC1} 
`define OPnop2   {`OPa2r, `ACC2} 

// state numbers only
`define Fetch	5'b11000 // s0
`define Read    5'b11001 // s1
`define ALU1    5'b11010 // s2
`define ALU2    5'b11011 // s3
`define Write	5'b11100 // s4

// Float Field definitions
`define	INT	signed [15:0]	// integer size
`define FLOAT	[15:0]	// half-precision float size
`define FSIGN	[15]	// sign bit
`define FEXP	[14:7]	// exponent
`define FFRAC	[6:0]	// fractional part (leading 1 implied)

// Float Constants
`define	FZERO	16'b0	  // float 0
`define F32767  16'h46ff  // closest approx to 32767, actually 32640
`define F32768  16'hc700  // -32768


module processor(halt, reset, clk);
    output reg halt;
    input reset, clk;

	reg `HWORD pre;
	reg `REGWORD regfile `REGSIZE;
	reg `WORD mainmem `MEMSIZE;

	reg `WORD pc = 0;
	reg `WORD ir;

    wire `WORD alu1res, alu2res;

    reg `OP s0op1, s1op1, s2op1, s3op1;
    reg `OP s0op2, s1op2, s2op2, s3op2;

    // referenced register locations
    reg `REG s0reg1, s1reg1, s2reg1, s3reg1;
    reg `REG s0reg2, s1reg2, s2reg2, s3reg2;

    // referenced imm values
    reg `HWORD s0im, s1im, s2im, s3im; 

    // actual values from registers
    reg `WORD s0val1, s1val1, s2val1, s3val1;
    reg `WORD s0val2, s1val2, s2val2, s3val2;
    reg `WORD s1pre, s2pre, s3pre;
    
    reg ifsquash, rrsquash; 
    reg `WORD srcval2, newpc;
    wire `OP op1;
    wire `OP op2;
    wire `STATE regdst1;
    reg `REG s0src, s0src2, s0regdst, s1regdst2, s3regdst2;
	
	always @(*) ir = mainmen[pc];
	
	always @(*) ifsquash = (s1op == `OPjr) &&(s1op == `OPjz8) && (s1op == `OPjnz8) &&(s1op == `OPjp8 );

	always @(*) rrsquash =  (s1op == `OPjr);

	always @(reset) begin
		pc = 0;
		halt = 0;

		s0op1 = `OPnop1;
		s1op1 = `OPnop1;
		s2op1 = `OPnop1;
		s3op1 = `OPnop1;

		s0op2 = `OPnop2;
		s1op2 = `OPnop2;
		s2op2 = `OPnop2;
		s3op2 = `OPnop2;
		$readmemh0(regfile);
		$readmemh1(mainmem);
	end

    
    // TODO: src value forwarding
    always @(*) begin
        //stage 0
        case(s0op1) // load immediate values
        `OPcf8, 
        `OPci8: s0val1 = {s1pre, ir `Imm8};
        `OPadd, 
        `OPsub, 
        `OPxor, 
        `OPand, 
        `OPor, 
        `OPsh, 
        `OPslt, 
        `OPmul, 
        `OPdiv, 
        `OPa2r, 
        `OPlf, 
        `OPli, 
        `OPst, 
        `OPcvt
        endcase
        
        // src relies on the value of dst
        // s0val1 is the value "read in" for the register during stage 1
        // s3val1 is the computed value written to the register after processing, before being written to regfile

        // case 1: src:acc1 => dst:reg0
        // - s0op1: add, sub, xor, and, or, sh, slt, mul, div, a2r, lf, li, st, cvt
        // - s3reg1 == `ACC1 && s3op1: a2r, lf, li, cf8, ci8
        // - s0val1 = s3val1

        // case 2: src:reg0 => dst:acc1
        // - s0reg1 == `ACC1 && s0op1: r2a, st, cvt, jr, jz8, jnz8
        // - s3op1: add, sub, xor, and, or, not, sh, slt, mul, div, r2a, cvt
        // - s0val1 = s3val1

        // case 3: src:acc2 => dst:reg1
        // - s0op2: add, sub, xor, and, or, sh, slt, mul, div, a2r, lf, li, st, cvt
        // - s3reg2 == `ACC2 && s3op2: a2r, lf, li
        // - s0val2 = s3val2

        // case 4: src:reg1 => dst:acc2
        // - s0reg2 == `ACC2 && s0op2: r2a, st, cvt, jr
        // - s3op2: add, sub, xor, and, or, not, sh, slt, mul, div, r2a, cvt
        // - s0val2 = s3val2

        // case 5: src:reg1 => dst:acc1
        // - s0reg1 == `ACC2 && s0op1: r2a, st, cvt, jr, jz8, jnz8
        // - s3reg1 == `ACC1 && s3op1: add, sub, xor, and, or, not, sh, slt, mul, div, r2a, cvt
        // - s0val1 = s3val1

        // example:
        // pre 0, nop
        // ci8 $0, 0
        // ci8 $1, 0

        // pre 4, nop  
        // ci8 $2, 4 // 16'b0000 0100 0000 0100
        // r2a $2, add $2 // acc1 = 16'b0000 0100 0000 0100, acc2 = 16'b0000 0100 0000 0100
        // li $2, add $2  // acc2 = 16'b0000 1000 0000 1000, reg2 = something else
        // add $3, nop

        // case 3: src:regN => dst:regN
        // - s0op1: r2a, st, cvt, jr, jz8, jnz8
        // - s3op1: a2r, lf, li, cf8, ci8
        // - s0val1 = s3val1

        // if (ir `HIR1 == `OPnop1) // skip if nop1

        // if (ir `HIR2 == `OPnop2) // skip if nop2

        //stage 1
        if (s0reg1 == s2reg1) // get the result computed that will be saved in stage 3 
            s0val1 = alu1res;
        else if (s0src == s3regdst) // stage 2
            s0val1 = s3val;
        else // stage 3 / other
            s0val1 = regfile[s0src];
        
        if (s1regdst2 && (s0src2 == s1regdst2)) // stage 1
            srcval2 = alu2res;
        else if (s3regdst2 && (s0src2 == s3regdst2)) // stage 2
            srcval2 = s3val2;
        else // stage 3 / other
            srcval2 = regfile[s0src2];
    end


    // DONE: new pc value
    always @(*) begin
        if(s1op1 == `OPjp8) // only 1
            newpc = {s1pre, ir `Imm8};
        else if(s1op1 == `OPjr)
            newpc = s1val1;
        else if(s1op1 == `OPjz8 && s1val1 == 0) // only 1
            newpc = {s1pre, ir `Imm8};
        else if(s1op1 == `OPjnz8 && s1val1 != 0) // only 1
            newpc = {s1pre, ir `Imm8};
        else
            newpc = pc + 1;
    end
 
	
	
	//STAGE 0: FETCH
	always @(posedge clk) if (!halt) begin
		s0op1 <= (ifsquash ? `OPnop1 : op1);
		s0op2 <= (ifsquash ? `OPnop2 : op2);
		s0regdst <= (ifsquash ? 0 : regdst1);
		s0src <= regfile[ir `REG1];
		s0src2 <= regfile[ir `REG2];
		pc <= newpc;
	end 

	//STAGE 1: Reg Read
	always @(posedge clk) if (!halt) begin
		s1op1 <= (rrsquash ? `OPnop1 : s0op1);
		s1op2 <= (rrsquash ? `OPnop2 : s0op2);
		s1regdst2 <= (rrsquash ? 0 : s0regdst);
 		s1val1 <= s0val1;
  		s1val2 <= srcval2;
	end



endmodule
