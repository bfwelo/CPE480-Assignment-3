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

        // does this modify acc or reg?
        s3g1[0] = s3op1 < 9;
        s3g1[1] = s3op1 == `OPnot || s3op1 == `OPr2a || s3op1 == `OPcvt;
        s3g1[2] = s3op1 == `OPlf || s3op1 == `OPli || s3op1 == `OPa2r;
        s3g1[3] = s3op1 == `OPcf8 || s3op1 == `OPci8;

        t[0] = s3g1[0] || s3g1[1]; // modifies acc1
        t[1] = s3g1[2] || s3g1[3]; // modifies reg1

        // 2nd half -----------------

        s3g2[0] = s3op2 < 9;
        s3g2[1] = s3op2 == `OPnot || s3op2 == `OPr2a || s3op2 == `OPcvt;
        s3g2[2] = s3op2 == `OPlf || s3op2 == `OPli || s3op2 == `OPa2r;
        // cf8 and ci8 don't exist in second half

        t[2] = s3g2[0] || s3g2[1]; // modifies acc1
        t[3] = s3g2[2];            // modifies reg2
        
    // does this rely on acc or reg?
        s0g1[4] = s0op1 < 9;
        s0g1[5] = s0op1 == `OPnot || s0op1 == `OPr2a || s0op1 == `OPcvt;
        s0g1[6] = s0op1 == `OPlf || s0op1 == `OPli || s0op1 == `OPa2r;
        s0g1[7] = s0op1 == `OPst;
        s0g1[8] = s0op1 == `OPjr || s0op1 == `OPjnz8 || s0op1 == `OPjz8;

        t[4] = s0g1[4] || s0g1[6] || s0g1[7];            // relies on acc1
        t[5] = s0g1[4] || s0g1[5] || s0g1[7] || s0g1[8]; // relies on reg0

        // 2nd half -----------------

        s0g2[4] = s0op2 < 9;
        s0g2[5] = s0op2 == `OPnot || s0op2 == `OPr2a || s0op2 == `OPcvt;
        s0g2[6] = s0op2 == `OPlf || s0op2 == `OPli || s0op2 == `OPa2r;
        s0g2[7] = s0op2 == `OPst;
        s0g2[8] = s0op2 == `OPjr;

        t[6] = s0g2[4] || s0g2[6] || s0g2[7];            // relies on acc2
        t[7] = s0g2[4] || s0g2[5] || s0g2[7] || s0g2[8]; // relies on reg1

    always @(*) begin
        if(t[0])  
            s0acc1 = (t[2] || t[3] && s3reg1 == `ACC1) ? s3val1 : ((t[7] && s3reg2 == `ACC1) ? s3val2 : regfile[`ACC1]);
        
        if(t[1])
            s0val1 = (t[3] && s0reg1 == s3reg1) ? s3val1 : ((t[7] && s0reg1 == s3reg2) ? s3val2 : regfile[s0reg1]);

        if(t[4])
            s0acc2 = (t[6] || t[7] && s3reg2 == `ACC2) ? s3val2 : ((t[3] && s3reg1 == `ACC2) ? s3val1 : regfile[`ACC2]);
        
        if(t[5])
            s0val2 = (t[3] && s0reg2 == s3reg1) ? s3val1 : ((t[7] && s0reg2 == s3reg2) ? s3val2 : regfile[s0reg2]);
    end 

    always @(*) begin
        if(s0op1 == `OPpre)
            s0pre = ir `IMM8;
        else if(s3op1 == `OPpre)
            s0pre = s3pre;
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
        // add, sub, xor, and, or, not, sh, slt, mul, div, cvt, r2a, a2r, lf, li, st, jr, jz8, jnz8, cf8, ci8, pre, jp8, sys
        // 24, 21 that use reg or acc
        
        
        // rely on acc + reg: add, sub, xor, and, or, sh, slt, mul, div, st
        // rely on just acc: li, lf, a2r
        // rely on just reg: cvt, not, jr, r2a, jz8, jnz8
        // doesn't rely on acc or reg: pre, jp8, sys

        // rely on acc: add, sub, xor, and, or, sh, slt, mul, div, st, li, lf, a2r
        // rely on reg: add, sub, xor, and, or, sh, slt, mul, div, st, cvt, not, jr, r2a, jz8, jnz8

        // modify acc: not, add, sub, xor, and, or, sh, slt, mul, div, r2a, cvt
        // modify reg: cf8, ci8, li, lf, a2r
        
        // add, sub, xor, and, or, sh, slt, mul, div: 1, 2, 3
        // not, r2a, cvt: 2, 3
        // li, lf, a2r: 1, 4
        // st: 1, 2
        // jr, jz8, jnz8: 2
        // cf8, ci8: 4
        
        
        // group1: add, sub, xor, and, or, sh, slt, mul, div: 1, 2, 3
        // group2: not, r2a, cvt: 2, 3 
        // group3: li, lf, a2r: 1, 4
        // group4: st: 1, 2 // exception based
        // group5: jr, jz8, jnz8: 2
        // group6: cf8, ci8: 4

        // group7: pre, jp8, sys: others
        
        // t_vars[0]
       

        // group1 = op < 9
        // group2 = op == not || op == r2a || op == cvt
        // group3 = op == lf || op == li || op == a2r
        // group4 = op == st
        // group5 = op == jr || op == jnz8 || op == jz8
        // group6 = op == cf8 || op == ci8

        // t1 = op < 13 && !group2
        // t2 = op < 16 && !group3 || group5
        // t3 = op < 16 && !group3 && !group4
        // t4 = group3 || group6 


        // double packable
        // ---------- begin group 1
        // add	00000 0
        // sub	00001 1
        // xor	00010 2
        // and	00011 3
        // or	00100 4
        // sh   00101 5
        // slt	00110 6
        // mul	00111 7
        // div	01000 8
        // ---------- begin group 2
        // not	01001 9
        // cvt  01010 10
        // r2a  01011 11
        // ---------- begin group 3
        // a2r	01100 12
        // lf	01101 13
        // li	01110 14
        // ---------- begin group 4
        // st	01111 15
        // ---------- begin group 5
        // jr	10000 16
        // full word
        // jnz8 10100 20
        // jz8	10101 21
        // ---------- begin group 6
        // cf8	10110 22
        // ci8	10111 23
        // ---------- begin group 7
        // full word with padding, check 
        // pre  10001 17
        // jp8  10010 18
        // sys  10011 19


        // add, sub, xor, and, or, sh, slt, mul, div, st, li,  lf,  a2r
        // add, sub, xor, and, or, sh, slt, mul, div, st, r2a, cvt, not, jr, jz8, jnz8
        // add, sub, xor, and, or, sh, slt, mul, div,     r2a, cvt, not
        // cf8, ci8, li, lf, a2r

        // t1: s0op1 in [add, sub, xor, and, or, sh, slt, mul, div, st, li,  lf,  a2r]                // does s0op1 rely on acc1?
        // t2: s0op1 in [add, sub, xor, and, or, sh, slt, mul, div, st, r2a, cvt, not, jr, jz8, jnz8] // does s0op1 rely on reg?

        // t3: s3op1 in [add, sub, xor, and, or, sh, slt, mul, div,     r2a, cvt, not]                // does s3op1 modify acc1?
        // t4: s3op1 in [cf8, ci8, li, lf, a2r]                                                       // does s3op1 modify reg?

        // t5: s0op2 in [add, sub, xor, and, or, sh, slt, mul, div, st, li,  lf,  a2r]                // does s0op2 rely on acc2?
        // t6: s0op2 in [add, sub, xor, and, or, sh, slt, mul, div, st, r2a, cvt, not, jr, jz8, jnz8] // does s0op2 rely on reg?

        // t7: s3op2 in [add, sub, xor, and, or, sh, slt, mul, div,     r2a, cvt, not]                // does s3op2 modify acc2?
        // t8: s3op2 in [cf8, ci8, li, lf, a2r]                                                       // does s3op2 modify reg?

        // t9: s3reg1 == `ACC1   // is the s3 1st half register the 1st acc?
        // t10: s3reg2 == `ACC1   // is the s3 2nd half register the 1st acc?
        // t11: s3reg1 == `ACC2   // is the s3 1st half register the 2nd acc?
        // t12: s3reg2 == `ACC2   // is the s3 2nd half register the 2nd acc?

        // t13: s0reg1 == s3reg1  // is the s0 1st half reg the same as the s3 1st half reg?
        // t14: s0reg2 == s3reg2  // is the s0 2nd half reg the same as the s3 2nd half reg?
        // t15: s0reg1 == s3reg2  // is the s0 1st half reg the same as the s3 2nd half reg?
        // t16: s0reg2 == s3reg1  // is the s0 2nd half reg the same as the s3 1st half reg?


        // assume that we set if (s3reg1 == 0) s3acc1 = s3val1;
        // assume that we set if (s3reg1 == 1) s3acc2 = s3val1;
        // assume that we set if (s3reg2 == 0) s3acc1 = s3val2;
        // assume that we set if (s3reg2 == 1) s3acc2 = s3val2;

        // cases:

        // if(t1 && t3) s0acc1 = s3val1; // later accumulator operation
        // if(t5 && t7) s0acc2 = s3val2; // later accumulator operation

        // if this command doesn't rely on acc or reg, no need to change it
        if(t1)  
            s0acc1 = (t3 || t4 && t9) ? s3val1 : ((t8 && t10) ? s3val2 : regfile[`ACC1]);
        
        if(t5)
            s0acc2 = (t7 || t8 && t12) ? s3val2 : ((t4 && t11) ? s3val1 : regfile[`ACC2]);
        
        if(t2)
            s0val1 = (t4 && t13) ? s3val1 : ((t8 && t15) ? s3val2 : regfile[s0reg1]);

        if(t6)
            s0val2 = (t4 && t16) ? s3val1 : ((t8 && t14) ? s3val2 : regfile[s0reg2]);
        
        if(s0op1 == `OPpre)
            s0pre = ir `IMM8;
        else if(s3op1 == `OPpre)
            s0pre = s3pre;

        // resolve acc1 val
        // if(t1 && t3) s0acc1 = s3val1; // later accumulator operation
        // if(t1 && t4 && t9) s0acc1 = s3val1; // reg operation in this alu that changes r0
        // if(t1 && t8 && t10) s0acc1 = s3val2; // reg operation in other alu that changes r0
        // else s0acc1 = regfile[`ACC1]

        // resolve acc2 val
        // if(t5 && t7) s0acc2 = s3val2; // later accumulator operation
        // if(t5 && t4 && t11) s0acc2 = s3val1; // reg operation in other alu that changes r1
        // if(t5 && t8 && t12) s0acc2 = s3val2; // reg operation in this alu that changes r1
        // else s0acc2 = regfile[`ACC2]

        // resolve reg1 val
        // if(t2 && t4 && t13) s0val1 = s3val1; // reg operation in this alu that changes reg
        // if(t2 && t8 && t15) s0val1 = s3val2; // reg operation in other alu that changes reg
        // else s0val1 = regfile[s0reg1]


        // resolve reg2 val
        // if(t6 && t4 && t16) s0val2 = s3val1; // reg operation in this alu that changes reg
        // if(t6 && t8 && t14) s0val2 = s3val2; // reg operation in other alu that changes reg
        // else s0val2 = regfile[s0reg2]

        //stage 1
        if(s0op1 == )

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
        else if(s1op2 == `OPjr)
            newpc = s1val2;
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
