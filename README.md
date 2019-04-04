# CPE480-Assignment-3

- [ ] value forwarding we need:
- value check
    - check if instruction uses a register
    - if it does, check if any others in the pipeline do
    - if the src and dest for one later in the pipeline match, act accordingly

- pre - check
    - check if any later instruction uses value in pre
    - if pre is changed again before use, ignore
    - checking in stage 2

- instructions src from acc: add, sub, xor, and, or, sh, slt, mul, div, a2r, lf, li, st
- instructions dst into acc: add, sub, xor, and, or, not, sh, slt, mul, div, r2a, cvt 
- instructions src from reg: add, sub, xor, and, or, not, sh, slt, mul, div, r2a, cvt, st, jr, jz8, jnz8
- instructions dst into reg: cf8, ci8, a2r, lf, li
- instructions src from pre: cf8, ci8, jnz8, jp8, jz8
- instructions dst into pre: pre
- instructions src from mem: lf, li
- instructions dst into mem: st 


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
