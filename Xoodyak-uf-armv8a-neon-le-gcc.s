.text

.equ Xoodyak_Rkin   , 44
.equ Xoodyak_Rkout  , 24
.equ Xoodyak_Rhash  , 16

/* ----------------------------------------------------------------------------*/
.text
.macro    mRound

    /* Theta: Column Parity Mixer */
    eor     v4.16b, v0.16b, v1.16b           
    eor     v4.16b, v4.16b, v2.16b          
    ext     v4.16b, v4.16b, v4.16b, #12       
    shl     v3.4s, v4.4s, #5             
    sri     v3.4s, v4.4s, #32-5           
    shl     v5.4s, v4.4s, #14             
    sri     v5.4s, v4.4s, #32-14          
    eor     v3.16b, v3.16b, v5.16b          
    eor     v0.16b, v0.16b, v3.16b           
    eor     v1.16b, v1.16b, v3.16b           
    eor     v5.16b, v2.16b, v3.16b           

    /* Rho-west: Plane shift Iota: add round constant */        
    shl     v2.4s, v5.4s, #11              
    ext     v1.16b, v1.16b, v1.16b, #12        
    ld1     {v3.2s}, [x1], #8                    
    sri     v2.4s, v5.4s, #32-11 
    ins     v7.d[1], v0.d[1]  
    eor     v0.8b, v0.8b, v3.8b                  
    ins     v0.d[1],v7.d[1]  
                

    /* Chi: non linear step, on colums */ 
    bic     v3.16b, v2.16b, v1.16b          
    bic     v4.16b, v0.16b, v2.16b          
    bic     v5.16b, v1.16b, v0.16b          
    eor     v0.16b, v0.16b, v3.16b          
    eor     v4.16b, v1.16b, v4.16b          
    eor     v2.16b, v2.16b, v5.16b          

    /* Rho-east: Plane shift */
    ext     v5.16b, v2.16b, v2.16b, #8      
    shl     v1.4s, v4.4s, #1             
    shl     v2.4s, v5.4s, #8             
    sri     v1.4s, v4.4s, #32-1          
    sri     v2.4s, v5.4s, #32-8          
    .endm


/* ---------------------------------------------------------------------------- */
/*  Xoodoo_Permute_12roundsAsm: only callable from asm*/
.align 8
.type	Xoodoo_Permute_12roundsAsm, %function;
Xoodoo_Permute_12roundsAsm:
    adr         x1, _rc12                         
    mRound  
    mRound 	
    mRound
    mRound
    mRound
    mRound
    mRound
    mRound
    mRound
    mRound
    mRound
    mRound
    ret                               
    .ltorg
    .align  8
    
_rc12:
    .quad          0x0000000000000058              
    .quad          0x0000000000000038              
    .quad          0x00000000000003C0              
    .quad          0x00000000000000D0              
    .quad          0x0000000000000120
    .quad          0x0000000000000014
    .quad          0x0000000000000060
    .quad          0x000000000000002C
    .quad          0x0000000000000380
    .quad          0x00000000000000F0
    .quad          0x00000000000001A0
    .quad          0x0000000000000012

/* ----------------------------------------------------------------------------
size_t Xoodyak_AbsorbKeyedFullBlocks(void *state, const uint8_t *X, size_t XLen)
*/

.global Xoodyak_AbsorbKeyedFullBlocks
.type   Xoodyak_AbsorbKeyedFullBlocks, %function;
Xoodyak_AbsorbKeyedFullBlocks:
    stp          x29, x30, [sp,#-16]!
    ins          v7.d[1], v6.d[0]  
    ins          v7.d[0], v6.d[1]
    movi         v7.2s, #1 
    ins          v6.d[1], v7.d[0]                
    ins          v6.d[0],v7.d[1]  
    mov          x3, x1                                
    mov          x4, x1                               
    ld1          {v0.4s-v2.4s} ,[x0]                   
    subs         x2, x2, #Xoodyak_Rkin
Xoodyak_AbsorbKeyedFullBlocks_Loop:
    bl           Xoodoo_Permute_12roundsAsm
    ld1          {v3.16b,v4.16b}, [x3], #32  
    ins          v7.d[0], v6.d[1]          
    ld1          {v6.2s}, [x3],#8  
    ins          v6.d[1], v7.d[0]    
    ld1          {v6.s}[2], [x3], #4   
    eor          v0.16b, v0.16b, v3.16b                
    eor          v1.16b, v1.16b, v4.16b
    eor          v2.16b, v2.16b, v6.16b                
    subs         x2, x2, #Xoodyak_Rkin
    bcs          Xoodyak_AbsorbKeyedFullBlocks_Loop
    st1          {v0.16b - v2.16b}, [x0]               
    sub          x0, x3, x4
    ldp          x29, x30, [sp],#16              
    ret                                               
    .align  8


/* ----------------------------------------------------------------------------
size_t Xoodyak_AbsorbHashFullBlocks(void *state, const uint8_t *X, size_t XLen)
*/

.global Xoodyak_AbsorbHashFullBlocks
.type   Xoodyak_AbsorbHashFullBlocks, %function;
Xoodyak_AbsorbHashFullBlocks:
    stp          x29, x30, [sp,#-16]!
    mov          x3, x1                              
    movi         v6.2s, #1                             
    ushr         d6, d6, #32                    
    mov          x4, x1                                 
    ld1          {v0.16b - v2.16b}, [x0]                
    subs         x2, x2, #Xoodyak_Rhash
Xoodyak_AbsorbHashFullBlocks_Loop:
    bl           Xoodoo_Permute_12roundsAsm
    ld1          {v3.16b}, [x3], #16 
    ins          v7.d[1], v1.d[1]  
    eor          v1.8b, v1.8b, v6.8b                 
    ins          v1.d[1],v7.d[1]                   
    eor          v0.16b, v0.16b, v3.16b
    subs         x2, x2, #Xoodyak_Rhash
    bcs          Xoodyak_AbsorbHashFullBlocks_Loop
    st1          {v0.16b - v2.16b}, [x0]               
    sub          x0, x3, x4
    ldp          x29, x30, [sp],#16  
    ret                                                
    .align  8




/* ----------------------------------------------------------------------------
size_t Xoodyak_SqueezeKeyedFullBlocks(void *state, uint8_t *Y, size_t YLen)
*/

.global Xoodyak_SqueezeKeyedFullBlocks
.type   Xoodyak_SqueezeKeyedFullBlocks, %function;
Xoodyak_SqueezeKeyedFullBlocks:
    stp          x29, x30, [sp,#-16]! 
    movi         v6.2s, #1
    ushr         d6, d6, #32                    
    mov          x3, x1                                
    mov          x4, x1                                
    ld1          {v0.4s - v2.4s}, [x0]                 
    subs         x2, x2, #Xoodyak_Rkout
Xoodyak_SqueezeKeyedFullBlocks_Loop:
    ins          v7.d[1], v0.d[1]       
    eor          v0.8b, v0.8b, v6.8b                 
    ins          v0.d[1],v7.d[1]                
    bl           Xoodoo_Permute_12roundsAsm
    st1          {v0.16b}, [x3], #16                   
    st1          {v1.2s}, [x3], #8                     
    subs         x2, x2, #Xoodyak_Rkout
    bcs          Xoodyak_SqueezeKeyedFullBlocks_Loop
    st1          {v0.16b - v2.16b}, [x0]               
    sub          x0, x3, x4
    ldp          x29, x30, [sp],#16  
    ret                                               
    .align  8



/* ----------------------------------------------------------------------------
size_t Xoodyak_SqueezeHashFullBlocks(void *state, uint8_t *Y, size_t YLen)
*/

.global Xoodyak_SqueezeHashFullBlocks
.type   Xoodyak_SqueezeHashFullBlocks, %function;
Xoodyak_SqueezeHashFullBlocks:
    stp          x29, x30, [sp,#-16]!
    movi         v6.2s, #1
    ushr         d6, d6, #32
    mov          x3, x1
    mov          x4, x1
    ld1          {v0.4s - v2.4s}, [x0]          
    subs         x2, x2, #Xoodyak_Rhash   //i have changed x2 to r2 but did not compile it.
Xoodyak_SqueezeHashFullBlocks_Loop:
    ins          v7.d[1],v0.d[1]
    eor          v0.8b, v0.8b, v6.8b           
    ins          v0.d[1],v7.d[1]    
    bl           Xoodoo_Permute_12roundsAsm
    st1          {v0.16b}, [x3], #16    
    subs         x2, x2, #Xoodyak_Rkout    //i have changed x2 to r2 but did not compile it.
    bcs          Xoodyak_SqueezeHashFullBlocks_Loop
    st1          {v0.16b - v2.16b}, [x0]
    sub          x0, x3, x4
    ldp          x29, x30, [sp],#16    
    ret                                        
    .align  8
    
    

/* ----------------------------------------------------------------------------
size_t Xoodyak_EncryptFullBlocks(void *state, const uint8_t *I, uint8_t *O,size_t IOLen)
*/

.global Xoodyak_EncryptFullBlocks
.type   Xoodyak_EncryptFullBlocks, %function;
Xoodyak_EncryptFullBlocks:
    stp          x29, x30, [sp,#-16]! 
    mov          x4, x1                 
    ins          v7.d[1], v6.d[0]  
    ins          v7.d[0], v6.d[1]
    movi         v7.2s, #1 
    ushr         d7, d7, #32
    ins          v6.d[1], v7.d[0]                
    ins          v6.d[0],v7.d[1]              
    mov          x5, x1                        
    ld1          {v0.4s - v2.4s}, [x0]         
    subs         x3, x3, #Xoodyak_Rkout
Xoodyak_EncryptFullBlocks_Loop:
    bl           Xoodoo_Permute_12roundsAsm
    ld1          {v3.16b}, [x4], #16 
    ins          v7.d[0], v6.d[1]          
    ld1          {v6.2s}, [x4],#8  
    ins          v6.d[1], v7.d[0]
    eor          v0.16b, v0.16b, v3.16b
    eor          v1.16b, v1.16b, v6.16b
    st1          {v0.16b}, [x2], #16           
    subs         x3, x3, #Xoodyak_Rkout
    st1          {v1.8b}, [x2],#8              
    bcs          Xoodyak_EncryptFullBlocks_Loop
    st1          {v0.16b - v2.16b}, [x0]       
    sub          x0, x4, x5
    ldp          x29, x30, [sp],#16        
    ret                                        
    .align  8

/* ----------------------------------------------------------------------------
size_t Xoodyak_DecryptFullBlocks(void *state, const uint8_t *I, uint8_t *O,size_t IOLen)
*/

.global Xoodyak_DecryptFullBlocks
.type   Xoodyak_DecryptFullBlocks, %function;
Xoodyak_DecryptFullBlocks:
    stp          x29, x30, [sp,#-16]!
    mov          x4, x1      
    ins          v7.d[1], v6.d[0]  
    ins          v7.d[0], v6.d[1]
    movi         v7.2s, #1 
    ushr         d7, d7, #32
    ins          v6.d[1], v7.d[0]                
    ins          v6.d[0],v7.d[1] 
    mov          x5,x1
    subs         x3, x3, #Xoodyak_Rkout
    ld1          {v0.4s - v2.4s}, [x0]         
Xoodyak_DecryptFullBlocks_Loop:
    bl           Xoodoo_Permute_12roundsAsm
    ld1          {v3.16b},[x4],#16                             
    ins          v7.d[0], v6.d[1]          
    ld1          {v6.2s}, [x4],#8  
    ins          v6.d[1], v7.d[0]                   
    eor          v0.16b, v0.16b, v3.16b
    eor          v1.16b, v1.16b, v6.16b
    st1          {v0.16b},[x2],#16        
    st1          {v1.8b},[x2],#8        
    mov          v0.16b, v3.16b
    subs         x3, x3, #Xoodyak_Rkout
    ins          v7.d[1],v1.d[1]
    mov          v1.8b, v6.8b 
    ins          v1.d[1],v7.d[1]
    bcs          Xoodyak_DecryptFullBlocks_Loop
    st1          {v0.4s - v2.4s}, [x0]       
    sub          x0, x4, x5
    ldp          x29, x30, [sp],#16               
    ret           
    .align  8
