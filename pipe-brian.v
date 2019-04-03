// basic sizes of things 
`define WORD  [15:0] // Standard word length
`define OP    [4:0] // opcode length
`define REG   [2:0] // reg location length

`define OP1	  [15:11] // Typical opcode field
`define OP2   [7:3] // VLIW 2nd Op location
`define REG1  [10:8] // Typical opcode field 
`define REG2  [2:0] // VLIW 2nd Op location
`define IMM8  [7:0] // Immediate 8 bit value location
`define HWORD [7:0]
`define ACC1 3'b000 // Location for first accumulator
`define ACC2 3'b001 // Location for second accumulator
`define TYPEBIT 16 // Where the register type is defined (float = 1, int = 0)

// TODO: modify for our code
`define REGWORD [16:0]
`define REGSIZE [7:0]
`define MEMSIZE [65535:0]

// 8 bit operators - PHASE 1 DECODING
// opcode values, also state numbers
`define OPa2r	5'b00000
`define OPr2a	5'b00001
`define OPlf	5'b00010
`define OPli	5'b00011
`define OPst	5'b00100
`define OPcvt	5'b00101
`define OPsh	5'b00110
`define OPslt	5'b00111
`define OPadd	5'b01000
`define OPsub	5'b01001
`define OPmul	5'b01010
`define OPdiv	5'b01011
`define OPnot	5'b01100
`define OPxor	5'b01101
`define OPand	5'b01110
`define OPor	5'b01111
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
`define OPnop   5'111111

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

    reg `OP s0op1, s1op1, s2op1, s3op1;
    reg `OP s0op2, s1op2, s2op2, s3op2;

    // referenced register values
    reg `REG s0reg1, s1reg1, s2reg1, s3reg1;
    reg `REG s0reg2, s1reg2, s2reg2, s3reg2;

    // referenced imm values
    reg `HWORD s0im, s1im, s2im, s3im; 

    // actual values from registers
    reg `WORD s1val, s2val, s3val;
    reg `WORD s1pre, s2pre, s3pre;


    // src value forwarding
    always @(*) begin
        //stage 0
        case(s0op) // load immediate values
        `OPcf8, 
        `OPci8: srcval = ir;
        endcase

        case(s0op2) // load immediate values
        `OPcf8, 
        `OPci8: srcval2 = ir;
        endcase

        //stage 1
        if (s1regdst && (s0src == s1regdst)) // stage 1
            srcval = res;
        else if (s3regdst && (s0src == s3regdst)) // stage 2
            srcval = s3val;
        else // stage 3 / other
            srcval = regfile[s0src];
        
        if (s1regdst2 && (s0src2 == s1regdst2)) // stage 1
            srcval2 = res2;
        else if (s3regdst2 && (s0src2 == s3regdst2)) // stage 2
            srcval2 = s3val2;
        else // stage 3 / other
            srcval2 = regfile[s0src2];
    end




endmodule