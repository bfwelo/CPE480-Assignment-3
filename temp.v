if (s0op == `OPli) // stage 0
    srcval = ir; // catch immediate for li
else if (s1regdst && (s0src == s1regdst)) // stage 1
    srcval = res
else if (s2regdst && (s0src == s2regdst)) // stage 2
    srcval = s2val
else // stage 3 / other
    srcval = regfile[s0src]

0 fetch
1 read
2 alu
3 write

0 fetch
1 read
2 alu
3 alu2
4 write

// src value forwarding
always @(*) begin
    //stage 0
    case(s0op) // load immediate values
    `OPcf8, 
    `OPci8: srcval = ir;
    endcase

    case(s0op2) // load immediate values
    `OPcf8, 
    `OPci8: srcval = ir;
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



always @(*) if (s0op == `OPli) srcval = ir; // catch immediate for li
            else srcval = ((s1regdst && (s0src == s1regdst)) ? res :
                           ((s2regdst && (s0src == s2regdst)) ? s2val :
                            regfile[s0src]));