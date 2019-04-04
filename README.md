# CPE480-Assignment-3

- [ ] value forwarding notes:

- instructions src from acc: add, sub, xor, and, or, sh, slt, mul, div, a2r, lf, li, st, cvt
- instructions dst into acc: add, sub, xor, and, or, not, sh, slt, mul, div, r2a, cvt

- instructions src from reg: r2a, st, cvt, jr, jz8, jnz8
- instructions dst into reg: a2r, lf, li, cf8, ci8

- instructions src from pre: cf8, ci8, jz8, jnz8, jp8
- instructions dst into pre: pre

- instructions src from mem: lf, li
- instructions dst into mem: st 

- instructions modify pc: jnz8, jp8, jz8, jr

- pre is fetched in stage 1
- pre is set in stage 4 (pre)
- pre is used in stage 4 (cf8, ci8, jz8, jnz8, jp8)

- anything src'ing from acc1 or reg0 needs to know if anything earlier in the pipeline is dst'ing to acc1 or reg0
    - instruction pairs for src:acc1 => dst:reg0:
        - src: add, sub, xor, and, or, sh, slt, mul, div, a2r, lf, li, st, cvt
        - dst: a2r, lf, li, cf8, ci8

    - instruction pairs for src:reg0 => dst:acc1:
        - src: r2a, st, cvt, jr, jz8, jnz8
        - dst: add, sub, xor, and, or, not, sh, slt, mul, div, r2a, cvt

- anything src'ing from acc2 or reg1 needs to know if anything earlier in the pipeline is dst'ing to acc2 or reg1
    - instruction pairs for src:acc2 => dst:reg1:
        - src: add, sub, xor, and, or, sh, slt, mul, div, a2r, lf, li, st, cvt
        - dst: a2r, lf, li, cf8, ci8

    - instruction pairs for src:reg1 => dst:acc2:
        - src: r2a, st, cvt, jr, jz8, jnz8
        - dst: add, sub, xor, and, or, not, sh, slt, mul, div, r2a, cvt
    
- anything src'ing from regN needs to know if anything earlier in the pipeline is dst'ing to regN
    - instruction pairs:
        - src: r2a, st, cvt, jr, jz8, jnz8
        - dst: a2r, lf, li, cf8, ci8

- anything src'ing from pre needs to know if anything earlier in the pipeline is setting pre
    - instruction pairs:
        - src: cf8, ci8, jz8, jnz8, jp8
        - set: pre


- problems:
    - alu operation in stage 1 reading register x needs the value being written to that register at the end of stage 3
    - jr operation in stage 1 reading register x needs the value being written to that register at the end of stage 3
    - memory operation in stage 1 reading register x to write to memory location needs the value being computed to that register at the end of stage 3


at each stage for conflicts and per instruction

- [ ] pc update + pipeline clear we need:
- check if we're jumping (need to figure out which stage)
- if(op == `OPjr) do nothing
- else pc+1
per instruction

- [ ] jump register check:
- don't update the pc until register is written
- if something is writing to a register that we might jump to, wait until that operation is in stage 4 before we jump
- if(op == `OPjr && s1regsrc == s4regsrc) then jump and set pipeline clear

always @(*) ir = mainmem[pc];

## stages
for all:
- check if not halt
- check if pipeline clear set
    - nop and 0

- [ ] 0.) fetch stage
- passes values to next stage, nothing else
- passes reg and values?

- [ ] 1.) read stage
- take the values calculated from the value forwarding and pass them on to the next stage
- how about the prefix?

- [ ] 2.) alu / memory stage
- integer operations
- floating point add
- recip
- memory ops
    - st, lf, li
    - check sys for halt

- [ ] 3.) alu2 stage
- multiply here
- second part of divide

- [ ] 4.) reg write
- s4regsrc <= s3regsrc
- literally just writing values to registers
