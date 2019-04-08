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

// TACKY data type flag values
`define	TFLOAT	1'b1
`define	TINT	1'b0
`define	TAG	[16] // Where the register type is defined (float = 1, int = 0)

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

module alu2(valid, o, op, a, b);
    output valid;
    output `REGWORD o;
    input `OP op;
    input `REGWORD a, b;
    reg `REGWORD t;
    reg ok;

    wire `FLOAT recipf, mulf;

    fmul myfmul(mulf, a `WORD, ((op == `OPmul) ? b `WORD : recipf));
    
    assign o = t;
    assign valid = ok;

    always @(*) begin
    t = a;
    ok = 1;
    case ({a `TAG, op})

        {`TINT, `OPdiv}:   t = {`TINT, (a `WORD / b `WORD)};
        {`TFLOAT, `OPdiv}: t = {`TFLOAT, mulf};
        {`TINT, `OPmul}:   t = {`TINT, (a `WORD * b `WORD)};
        {`TFLOAT, `OPmul}: t = {`TFLOAT, mulf};
 
        default: ok = 0;
    endcase
    end
endmodule


module alu1(valid, o, op, a, b);
    output valid;
    output `REGWORD o;
    input `OP op;
    input `REGWORD a, b;
    reg `REGWORD t;
    reg ok = 0;
    wire sltf;
    wire `WORD cvi;
    wire `FLOAT addf, cvf, recipf, mulf, shf;
    wire signed `WORD sa, sb;

    fadd myfadd(addf, a `WORD, ((op == `OPsub) ? (b `WORD ^ 16'h8000) : b `WORD));

    i2f myi2f(cvf, b `WORD);

    f2i myf2i(cvi, b `WORD);

    frecip myfrecip(recipf, b `WORD);

    fshift myfshift(shf, a `WORD, b `WORD);
    fslt myfslt(sltf, a `WORD, b `WORD);
    assign sa = a `WORD; // signed version of a
    assign sb = b `WORD; // signed version of b
    assign o = t;
    assign valid = ok;

    always @(*) begin
        t = a;
        ok = 1;
        case ({a `TAG, op})
            {`TINT, `OPadd}:   t = {`TINT, (a `WORD + b `WORD)};
            {`TFLOAT, `OPadd}: t = {`TFLOAT,  addf};
            {`TINT, `OPand},
            {`TFLOAT, `OPand}: t `WORD = a `WORD & b `WORD;
            {`TINT, `OPcvt},
            {`TFLOAT, `OPcvt}: t = ((b `TAG == `TFLOAT) ? {`TINT, cvi} : {`TFLOAT, cvf});
            {`TFLOAT, `OPdiv}: t = {`TFLOAT, recipf};
            {`TINT, `OPmul},
            {`TINT, `OPdiv},
            {`TFLOAT, `OPmul}: t = b;
            {`TINT, `OPnot},
            {`TFLOAT, `OPnot}: t `WORD = ~(b `WORD);
            {`TINT, `OPor},
            {`TFLOAT, `OPor}:  t `WORD = (a `WORD | b `WORD);
            {`TINT, `OPsh}:    t = {`TINT, ((sb < 0) ? (sa >> -sb) : (sa << sb))};
            {`TFLOAT, `OPsh}:  t = {`TFLOAT, shf};
            {`TINT, `OPslt}:   t = {`TINT, (sa < sb)};
            {`TFLOAT, `OPslt}: t = {`TINT, 15'b0, sltf};
            {`TINT, `OPsub}:   t `WORD = sa - sb;
            {`TFLOAT, `OPsub}: t = {`TFLOAT, addf};
            {`TINT, `OPxor},
            {`TFLOAT, `OPxor}: t `WORD = (a `WORD ^ b `WORD);
            default:           ok = 0;
        endcase
    end
endmodule

module processor(halt, reset, clk);
    output reg halt;
    input reset, clk;

	reg `HWORD pre;
	reg `REGWORD regfile `REGSIZE;
	reg `WORD mainmem `MEMSIZE;

	reg `WORD pc = 0;
	reg `WORD ir;

    wire `REGWORD alu1res1, alu2res1;
    wire `REGWORD alu1res2, alu2res2;

    reg `OP s0op1, s1op1, s2op1, s3op1;
    reg `OP s0op2, s1op2, s2op2, s3op2;

    // referenced register locations
    reg `REG s0reg1, s1reg1, s2reg1, s3reg1;
    reg `REG s0reg2, s1reg2, s2reg2, s3reg2;

    // referenced imm values
    reg `HWORD s0im, s1im, s2im, s3im; 

    // actual values from registers
    reg `REGWORD s0val1, s1val1, s2val1, s3val1;
    reg `REGWORD s0val2, s1val2, s2val2, s3val2;

    // accumulator values
    reg `REGWORD s0acc1, s1acc1, s2acc1, s3acc1;
    reg `REGWORD s0acc2, s1acc2, s2acc2, s3acc2;

    reg `HWORD s0pre, s1pre, s2pre, s3pre;

    // intermediate condition values
    reg s3g1[3:0];
    reg s3g2[3:0];
    reg t[3:0];
    
    reg ifsquash; 
    reg `WORD newpc;
    wire valid1_1, valid2_1, valid1_2, valid2_2;

    alu1 my1alu1(valid1_1, alu1res1, s1op1, s1acc1, s1val1);
    alu2 my1alu2(valid1_2, alu2res1, s2op1, s2acc1, s2val1);
    // second half
    alu1 my2alu1(valid2_1, alu1res2, s1op2, s1acc2, s1val2);
    alu2 my2alu2(valid2_2, alu2res2, s2op2, s2acc2, s2val2);


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

    always @(*) ir = mainmem[pc];

    always @(*) ifsquash = (s3op1 == `OPjr) && (s3op1 == `OPjz8) && (s3op1 == `OPjnz8) && (s3op1 == `OPjp8);

    always @(*) newpc = (s2op1 == `OPjr) ? s2val1`WORD : 
                        (
                            (s2op2 == `OPjr) ? s2val2`WORD : 
                            (
                                (s2op1 == `OPjp8 || s2op1 == `OPjz8 && s2val1`WORD == 0 || s2op1 == `OPjnz8 && s2val1`WORD != 0) ? {s2pre, s2im} : pc + 1
                            )
                        );


    // value forwarding for acc, reg, and pre
    // modify acc: not, add, sub, xor, and, or, sh, slt, mul, div, r2a, cvt
    // modify reg: cf8, ci8, li, lf, a2r
    always @(*) begin
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

        t[2] = s3g2[0] || s3g2[1]; // modifies acc2
        t[3] = s3g2[2];            // modifies reg2
        
        // s3op2 <= 16 is for checking if the instruction in stage 3 even has 2 instructions
        // favors reg 1 value in later stage
        s0acc1 = (t[0] || t[1] && s3reg1 == `ACC1) ? s3val1`WORD : ((t[3] && s3reg2 == `ACC1 && s3op2 <= 16) ? s3val2`WORD : regfile[`ACC1]);
        s0val1 = (t[1] && s0reg1 == s3reg1) ? s3val1`WORD : ((t[3] && s0reg1 == s3reg2 && s3op2 <= 16) ? s3val2`WORD : regfile[s0reg1]);

        s0acc2 = (t[2] || t[3] && s3reg2 == `ACC2 && s3op2 <= 16) ? s3val2`WORD : ((t[1] && s3reg1 == `ACC2) ? s3val1`WORD : regfile[`ACC2]);
        s0val2 = (t[1] && s0reg2 == s3reg1) ? s3val1`WORD : ((t[3] && s0reg2 == s3reg2 && s3op2 <= 16) ? s3val2`WORD : regfile[s0reg2]);

        s0pre = (s3op1 == `OPpre || (s3op2 <= 16 && s3op2 == `OPpre)) ? s3pre : (s0op1 == `OPpre)? ir `IMM8 : pre;

    end  

	//STAGE 0: FETCH
	always @(posedge clk) if (!halt) begin
		s0op1 <= ir `OP1;
		s0op2 <= ir `OP2;

        s0reg1 <= ir `REG1;
        s0reg2 <= ir `REG2;
        s0im <= ir `IMM8;

		pc <= newpc;
	end 

	//STAGE 1: Reg Read
	always @(posedge clk) if (!halt) begin
		s1op1 <= (ifsquash ? `OPnop1 : s0op1);
		s1op2 <= (ifsquash ? `OPnop2 : s0op2);

        s1reg1 <= s0reg1;
        s1reg2 <= s0reg2;

        s1acc1 <= s0acc1;
        s1acc2 <= s0acc2;
        
        s1pre  <= s0pre;
        s1im <= s0im;

 		s1val1 <= s0val1;
  		s1val2 <= s0val2;
	end

	// stage 2 ALU / memory
   	always @ (posedge clk) if (!halt) begin
		s2op1 <= s1op1; // squashing happens in this stage
		s2op2 <= s1op2;

        s2reg1 <= s1reg1;
        s2reg2 <= s1reg2;

        s2acc1 <= s1acc1;
        s2acc2 <= s1acc2;

        s2pre <= s1pre;
        s2im <= s1im;

        if(valid1_1)
		    s2val1 <= alu1res1; // div is recip, mul is just s1val1
        else
            case(s1op1)
            `OPci8: begin s2val1 <= {`TINT, pre, s1im}; end
            `OPcf8: begin s2val1 <= {`TFLOAT, pre, s1im}; end
            `OPlf:  begin s2val1 <= {`TFLOAT, mainmem[s1val1`WORD]}; end
            `OPli:  begin s2val1 <= {`TINT, mainmem[s1val1`WORD]}; end
		    `OPa2r: begin s2val1 <= s1acc1; end
            `OPr2a: begin s2val1 <= s1val1; s2reg1 <= `ACC1; end
            `OPst:  begin mainmem[s1val1`WORD] = s1acc1`WORD; end
            endcase

        if(valid2_1)
		    s2val2 <= alu2res1;
        else
            case(s1op2)
            `OPlf:  begin s2val2 <= {`TFLOAT, mainmem[s1val2`WORD]}; end
            `OPli:  begin s2val2 <= {`TINT, mainmem[s1val2`WORD]}; end
		    `OPa2r: begin s2val2 <= s1acc2; end
            `OPr2a: begin s2val2 <= s1val2; s2reg2 <= `ACC2; end
            `OPst:  begin mainmem[s1val2`WORD] = s1acc2`WORD; end
            endcase
	end

    // stage 3 ALU2 / pc changes
    always @ (posedge clk) if (!halt) begin

    	s3op1 <= s2op1; 
		s3op2 <= s2op2;

        s3reg1 <= s2reg1;
        s3reg2 <= s2reg2;

        s3pre  <= s2pre;

        // either compute the second part or pass through
        s3val1 = valid2_1 ? alu1res2 : s2val1; 
        s3val2 = valid2_2 ? alu2res2 : s2val2;

	end

    // stage 4 register write
    always @ (posedge clk) if (!halt) begin 
        if(t[0])
            regfile[`ACC1] <= s3val1;
        
        else if(t[1])
            regfile[s3reg1] <= s3val1;

        else if(t[2])
            regfile[`ACC2] <= s3val1;
        
        else if(t[3])
            regfile[s3reg2] <= s3val1;

        else if(s3op1 == `OPpre)
            pre <= s3pre;

	end

endmodule

// ************************************************ Float ********************************************

// Floating point Verilog modules for CPE480
// Created February 19, 2019 by Henry Dietz, http://aggregate.org/hankd
// Distributed under CC BY 4.0, https://creativecommons.org/licenses/by/4.0/

// Count leading zeros, 16-bit (5-bit result) d=lead0s(s)
module lead0s(d, s);
	output wire [4:0] d;
	input wire `WORD s;
	wire [4:0] t;
	wire [7:0] s8;
	wire [3:0] s4;
	wire [1:0] s2;
	assign t[4] = 0;
	assign {t[3],s8} = ((|s[15:8]) ? {1'b0,s[15:8]} : {1'b1,s[7:0]});
	assign {t[2],s4} = ((|s8[7:4]) ? {1'b0,s8[7:4]} : {1'b1,s8[3:0]});
	assign {t[1],s2} = ((|s4[3:2]) ? {1'b0,s4[3:2]} : {1'b1,s4[1:0]});
	assign t[0] = !s2[1];
	assign d = (s ? t : 16);
endmodule

// Float set-less-than, 16-bit (1-bit result) torf=a<b
module fslt(torf, a, b);
	output wire torf;
	input wire `FLOAT a, b;
	assign torf = (a `FSIGN && !(b `FSIGN)) ||
			  (a `FSIGN && b `FSIGN && (a[14:0] > b[14:0])) ||
			  (!(a `FSIGN) && !(b `FSIGN) && (a[14:0] < b[14:0]));
endmodule

// Floating-point addition, 16-bit r=a+b
module fadd(r, a, b);
	output wire `FLOAT r;
	input wire `FLOAT a, b;
	wire `FLOAT s;
	wire [8:0] sexp, sman, sfrac;
	wire [7:0] texp, taman, tbman;
	wire [4:0] slead;
	wire ssign, aegt, amgt, eqsgn;
	assign r = ((a == 0) ? b : ((b == 0) ? a : s));
	assign aegt = (a `FEXP > b `FEXP);
	assign texp = (aegt ? (a `FEXP) : (b `FEXP));
	assign taman = (aegt ? {1'b1, (a `FFRAC)} : ({1'b1, (a `FFRAC)} >> (texp - a `FEXP)));
	assign tbman = (aegt ? ({1'b1, (b `FFRAC)} >> (texp - b `FEXP)) : {1'b1, (b `FFRAC)});
	assign eqsgn = (a `FSIGN == b `FSIGN);
	assign amgt = (taman > tbman);
	assign sman = (eqsgn ? (taman + tbman) : (amgt ? (taman - tbman) : (tbman - taman)));
	lead0s m0(slead, {sman, 7'b0});
	assign ssign = (amgt ? (a `FSIGN) : (b `FSIGN));
	assign sfrac = sman << slead;
	assign sexp = (texp + 1) - slead;
	assign s = (sman ? (sexp ? {ssign, sexp[7:0], sfrac[7:1]} : 0) : 0);
endmodule

// Floating-point multiply, 16-bit r=a*b
module fmul(r, a, b);
	output wire `FLOAT r;
	input wire `FLOAT a, b;
	wire [15:0] m; // double the bits in a fraction, we need high bits
	wire [7:0] e;
	wire s;
	assign s = (a `FSIGN ^ b `FSIGN);
	assign m = ({1'b1, (a `FFRAC)} * {1'b1, (b `FFRAC)});
	assign e = (((a `FEXP) + (b `FEXP)) -127 + m[15]);
	assign r = (((a == 0) || (b == 0)) ? 0 : (m[15] ? {s, e, m[14:8]} : {s, e, m[13:7]}));
endmodule

// Floating-point reciprocal, 16-bit r=1.0/a
// Note: requires initialized inverse fraction lookup table
module frecip(r, a);
	output wire `FLOAT r;
	input wire `FLOAT a;
	reg [6:0] look[127:0];
	initial $readmemh("vmem0-float.vmem", look);
	assign r `FSIGN = a `FSIGN;
	assign r `FEXP = 253 + (!(a `FFRAC)) - a `FEXP;
	assign r `FFRAC = look[a `FFRAC];
endmodule

// Floating-point shift, 16 bit
// Shift +left,-right by integer
module fshift(r, f, i);
	output wire `FLOAT r;
	input wire `FLOAT f;
	input wire `INT i;
	assign r `FFRAC = f `FFRAC;
	assign r `FSIGN = f `FSIGN;
	assign r `FEXP = (f ? (f `FEXP + i) : 0);
endmodule

// Integer to float conversion, 16 bit
module i2f(f, i);
	output wire `FLOAT f;
	input wire `INT i;
	wire [4:0] lead;
	wire `WORD pos;
	assign pos = (i[15] ? (-i) : i);
	lead0s m0(lead, pos);
	assign f `FFRAC = (i ? ({pos, 8'b0} >> (16 - lead)) : 0);
	assign f `FSIGN = i[15];
	assign f `FEXP = (i ? (128 + (14 - lead)) : 0);
endmodule

// Float to integer conversion, 16 bit
// Note: out-of-range values go to -32768 or 32767
module f2i(i, f);
	output wire `INT i;
	input wire `FLOAT f;
	wire `FLOAT ui;
	wire tiny, big;
	fslt m0(tiny, f, `F32768);
	fslt m1(big, `F32767, f);
	assign ui = {1'b1, f `FFRAC, 16'b0} >> ((128+22) - f `FEXP);
	assign i = (tiny ? 0 : (big ? 32767 : (f `FSIGN ? (-ui) : ui)));
endmodule
