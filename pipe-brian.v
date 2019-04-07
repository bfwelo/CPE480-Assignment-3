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


`define OPadd  5'b00000 // ---------- begin group 1 // double packable
`define OPsub  5'b00001 
`define OPxor  5'b00010 
`define OPand  5'b00011 
`define OPor   5'b00100 
`define OPsh   5'b00101 
`define OPslt  5'b00110 
`define OPmul  5'b00111 
`define OPdiv  5'b01000 
`define OPnot  5'b01001  // ---------- begin group 2
`define OPcvt  5'b01010 
`define OPr2a  5'b01011 
`define OPa2r  5'b01100  // ---------- begin group 3
`define OPlf   5'b01101 
`define OPli   5'b01110 
`define OPst   5'b01111  // ---------- begin group 4
`define OPjr   5'b10000  // ---------- begin group 5
`define OPjnz8 5'b10100  // full word
`define OPjz8  5'b10101 
`define OPcf8  5'b10110  // ---------- begin group 6
`define OPci8  5'b10111 
`define OPpre  5'b10001  // ---------- begin group 7, 13 bits + 3 padding
`define OPjp8  5'b10010 
`define OPsys  5'b10011 


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

    // accumulator values
    reg `WORD s0acc1, s1acc1, s2acc1, s3acc1;
    reg `WORD s0acc2, s1acc2, s2acc2, s3acc2;

    reg `WORD s1pre, s2pre, s3pre;

    // intermediate condition values
    reg s3g1[3:0];
    reg s3g2[3:0];
    reg t[3:0];
    
    reg ifsquash, rrsquash; 
    reg `WORD newpc;

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

    always @(*) ir = mainmen[pc];
	
	always @(*) ifsquash = (s1op1 == `OPjr) &&(s1op1 == `OPjz8) && (s1op1 == `OPjnz8) &&(s1op1 == `OPjp8 );


    // value forwarding for acc, reg, and pre
    // modify acc: not, add, sub, xor, and, or, sh, slt, mul, div, r2a, cvt
    // modify reg: cf8, ci8, li, lf, a2r
    always @(*) begin
        s3g1[0] = s3op1 < 9;
        s3g1[1] = s3op1 == `OPnot || s3op1 == `OPr2a || s3op1 == `OPcvt;
        s3g1[2] = s3op1 == `OPlf || s3op1 == `OPli || s3op1 == `OPa2r;
        s3g1[3] = s3op1 == `OPcf8 || s3op1 == `OPci8;

        t[0] = s3g1[0] || s3g1[1];
        t[1] = s3g1[2] || s3g1[3];

        // 2nd half -----------------

        s3g2[0] = s3op2 < 9;
        s3g2[1] = s3op2 == `OPnot || s3op2 == `OPr2a || s3op2 == `OPcvt;
        s3g2[2] = s3op2 == `OPlf || s3op2 == `OPli || s3op2 == `OPa2r;
        // cf8 and ci8 don't exist in second half

        t[2] = s3g2[0] || s3g2[1];
        t[3] = s3g2[2];

        // s3op2 <= 16 is for checking if the instruction in stage 3 even has 2 operators
        // favors reg 1 value in later stage
        s0acc1 = (t[0] || t[1] && s3reg1 == `ACC1) ? s3val1 : ((t[3] && s3reg2 == `ACC1 && s3op2 <= 16) ? s3val2 : regfile[`ACC1]);
        s0val1 = (t[1] && s0reg1 == s3reg1) ? s3val1 : ((t[3] && s0reg1 == s3reg2 && s3op2 <= 16) ? s3val2 : regfile[s0reg1]);

        s0acc2 = (t[2] || t[3] && s3reg2 == `ACC2 && s3op2 <= 16) ? s3val2 : ((t[1] && s3reg1 == `ACC2) ? s3val1 : regfile[`ACC2]);
        s0val2 = (t[1] && s0reg2 == s3reg1) ? s3val1 : ((t[3] && s0reg2 == s3reg2 && s3op2 <= 16) ? s3val2 : regfile[s0reg2]);

        s0pre = (s3op1 == `OPpre || (s3op2 <= 16 && s3op2 == `OPpre)) ? s3pre : (s0op1 == `OPpre)? ir `IMM8 : pre;

    end  


    // 0 pre 0
    // 1 add 1, add 0
    // 2 add 1, add 0
    // 3 jnz8 $0 5
    // 4 add 1, add 1
    // 5 sys
    // | fetch     | read      | alu1      | alu2      | write     | reg0 = 0, s3val1 = 0, pc = 0, pre = 0
    // | pre 0     | nop       | nop       | nop       | nop       | reg0 = 0, s3val1 = 0, pc = 0, pre = 0, newpc = 1, flush = false
    // | add 1     | pre 0     | nop       | nop       | nop       | reg0 = 0, s3val1 = 0, pc = 1, pre = 0, newpc = 2, flush = false
    // | add 1     | add 1     | pre 0     | nop       | nop       | reg0 = 0, s3val1 = 0, pc = 2, pre = 0, newpc = 3, flush = false
    // | jnz8 $0 5 | add 1     | add 1     | pre 0     | nop       | reg0 = 0, s3val1 = 0, pc = 3, pre = 0, newpc = 4, flush = false
    // | add 1     | jnz8 $0 5 | add 1     | add 1     | pre 0     | reg0 = 0, s3val1 = 1, pc = 4, pre = 0, newpc = 5, flush = false 
    // | sys       | add 1     | jnz8 $0 5 | add 1     | add 1     | reg0 = 1, s3val1 = 2, pc = 5, pre = 0, newpc = 5, flush = true // soonest we can write to pc
    // | sys       | nop       | nop       | jnz8 $0 5 | add 1     | reg0 = 2, s3val1 = 2, pc = 5, pre = 0, newpc = 6, flush = false
    // | halt      | sys       | nop       | nop       | jnz8 $0 5 | reg0 = 2, s3val1 = 2, pc = 6, pre = 0, newpc = 7, flush = false
    // | halt      | halt      | sys       | nop       | add 1     | reg0 = 2, s3val1 = 2, pc = 7, pre = 0, newpc = 8, flush = false
    // | halt      | halt      | halt      | sys       | nop       | done
             

    // DONE: new pc value
    always @(*) newpc = (s3op1 == `OPjr) ? s3val1 : 
                        (
                            (s3op2 == `OPjr) ? s3val2 : 
                            (
                                (s3op1 == `OPjp8 || s3op1 == `OPjz8 && s3val1 == 0 || s3op1 == `OPjnz8 && s3val1 != 0) ? {s3pre, ir `Imm8} : pc + 1
                            )
                        );
    // begin
    //     if(s1op1 == `OPjp8) // only 1
    //         newpc = {s1pre, ir `Imm8};
    //     else if(s1op1 == `OPjr)
    //         newpc = s1val1;
    //     else if(s1op2 == `OPjr)
    //         newpc = s1val2;
    //     else if(s1op1 == `OPjz8 && s1val1 == 0) // only 1
    //         newpc = {s1pre, ir `Imm8};
    //     else if(s1op1 == `OPjnz8 && s1val1 != 0) // only 1
    //         newpc = {s1pre, ir `Imm8};
    //     else
    //         newpc = pc + 1;
    // end
	
	//STAGE 0: FETCH
	always @(posedge clk) if (!halt) begin
		s0op1 <= (ifsquash ? `OPnop1 : op1);
		s0op2 <= (ifsquash ? `OPnop2 : op2);
		s0regdst <= (ifsquash ? 0 : regdst1); //Maybe we need two regdst?
		s0src <= regfile[ir `REG1];  //Do we need to pass this two src to the next stage?			
		s0src2 <= regfile[ir `REG2]; //
		pc <= newpc;
	end 

	//STAGE 1: Reg Read
	always @(posedge clk) if (!halt) begin
		s1op1 <= (rrsquash ? `OPnop1 : s0op1);
		s1op2 <= (rrsquash ? `OPnop2 : s0op2);
		s1regdst2 <= (rrsquash ? 0 : s0regdst); //Maybe we need two regdst?
 		s1val1 <= s0val1;
  		s1val2 <= srcval2;
	end
	// stage 2 ALU // some varibles will have to change and might miss something
   	always @ (posdge clk) if (!halt) begin
    
		s2op1 <= (( s1op1==)?something : s1op1);// set something to distinguish the two kind of opcode 
		s2op2 <= (( s1op2==)?something : s1op2);// set something to distinguish the two kind of opcode 
		s2regdst2 <= s1regdst2;

		s2val1 <= ALU1out;
		s2val2 <= ALU2out;
	end
    	// stage 3 ALU2
    	always @ (posdge clk) if (!halt) begin 
		s3op1 <= ((s2op1==something)?s2op1 : nops);
		s3val1 <= ((s2op1!==something)?s2val1 : result for floating ALU1)
		s3op2 <= ((s2op2==something)?s2op1 : nops);
		s3val2 <= ((s2op1!==something)?s2val2 : result for floating ALU2)
	end
    	// stage 4 register write
    	always @ (posdge clk if (!halt) begin 
        	if (s3regdst2 != 0) regfile[s3regdst1] <=s3val1;
        	if (s3regdst2 != 0) regfile[s3regdst2] <=s3val2;
	end

endmodule
