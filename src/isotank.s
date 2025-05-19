.include "libSFX.i"
.include "sinlut.i"
.include "idlut.i"
.include "plalut.i"
.include "qubo.i"

;SNESmod audio code
.include "snesmoddoug/snesmod_ca65.asm"

;VRAM destination address
VRAM_MODE7_LOC   = $0000
VRAM_SPR_LOC   = $4000

;Mode 7 center and offset
CENTER_X = 0
CENTER_Y = 0

;camera speed
CAM_SPEED = 1

;initial cam position
INIT_CAM_X = 0 ;((4)<<8)
INIT_CAM_Y = 0 ;((4)<<8)
INIT_CAM_Z = (256 - 48)

;rotation amount per axis
INIT_SX = 0
INIT_SY = 0
INIT_SZ = 0

;hardcoded model properties
VERTEX_COUNT = 8
EDGE_COUNT = 12

;toggle music
USE_AUDIO = 0

COSINE_OFFS = 64

;8-bit by 8-bit hardware multiplication
;uses a8
;a16 output: mult product
.macro mult_s8_s8 cand1, cand2
        RW a8
        
        lda #0
        pha
        lda cand1   ;all i have left is the stack
        sta WRMPYA
        cmp #$80
        bcc :+
          pla
          sbc cand2
          pha
      : lda cand2
        sta WRMPYB
        cmp #$80
        bcc :+
          pla
          sbc cand1
          pha
      : pla
        clc
        adc RDMPYH
        RW a16
        lda RDMPYL ;16-bit result
.endmacro

; 8.8 by 8.8 fixed point multiplication
; 8.8 fixed point result
; uses a8 and a16
; 
; a16 is where the result is stored
; x16 and y16 are free
.macro mult_8p8_8p8 cand1, cand2, freezpad, cand1h, cand2h
        RW a8
        
        lda cand1 ;p1.l by p2.l
        sta WRMPYA
        lda cand2
        sta WRMPYB
        nop
        nop
        nop
        lda RDMPYH
        sta z:ZPAD+freezpad
        bpl :+
        lda #$ff
        bra :++
      : lda #0
      : sta z:ZPAD+freezpad+1
        
        lda #0
        pha
        lda cand1
        sta WRMPYA
        lda cand2h ;p1.l by p2.h
        sta WRMPYB
        cmp #$80
        bcc :+
          pla
          sbc cand1
          pha
      : pla
        add RDMPYH
        sta z:ZPAD+freezpad+3
        lda RDMPYL
        sta z:ZPAD+freezpad+2
        
        lda #0
        pha
        lda cand1h
        sta WRMPYA
        cmp #$80
        bcc :+
          pla
          sbc cand2
          pha
      : lda cand2 ;p1.h by p2.l
        sta WRMPYB
        nop
        nop
        nop
        pla
        add RDMPYH
        sta z:ZPAD+freezpad+5
        lda RDMPYL
        sta z:ZPAD+freezpad+4
        
        lda cand2h ;p1.h by p2.h
        sta WRMPYB
        nop
        nop
        nop
        RW a16
        lda RDMPYL
        xba
        and #$ff00
        add z:ZPAD+freezpad+4
        adc z:ZPAD+freezpad+2
        adc z:ZPAD+freezpad
.endmacro

;bresenham line macro (low part)
;x16 is clobbered
;a8 and a16 are also used
.macro hamline_low x0, y0, x1, y1, col, freezpad
.scope
        RW_forced a8i16
        lda x0 ;x0
        sta z:ZPAD+freezpad
        lda x1 ;x1
        sta z:ZPAD+freezpad+1
        lda y0 ;y0
        sta z:ZPAD+freezpad+2
        lda y1 ;y1
        sta z:ZPAD+freezpad+3
        
        lda z:ZPAD+freezpad+1
        sub z:ZPAD+freezpad
        sta ham_dx ;dx = x1 - x0
      
        lda z:ZPAD+freezpad+3
        sub z:ZPAD+freezpad+2
        sta ham_dy ;dy = y1 - y0
        
        lda #1
        sta ham_yi ;yi = 1
        
        lda ham_dy
        bpl :+ ;if dy < 0
        lda #$ff
        sta ham_yi ;yi = -1
        lda ham_dy 
        neg ;dy = -dy
      : sta ham_dy
      
        asl
        sub ham_dx
        sta ham_dee ;D = (2*dy) - dx
      
        lda z:ZPAD+freezpad+2
        sta ham_y
        lda z:ZPAD+freezpad
        sta ham_x
forloop:
        RW a16i16
        lda ham_y-1
        and #$ff00
        lsr
        ora ham_x
        planarplot freezpad+4
        RW a8
        ; lda col
        ; sta f:pseudobitmap,x ; plot(x0, y0)
        
        lda ham_dee ;if D > 0
        bmi :+
        lda ham_y
        add ham_yi ; Y += yi
        sta ham_y
        lda ham_dy
        sub ham_dx
        asl
        add ham_dee
        sta ham_dee ; D += 2 * (dy - dx)
        bra :++
      : lda ham_dy ; else
        asl
        add ham_dee
        sta ham_dee ; D += 2*dy
      : lda ham_x
        inc
        sta ham_x
        cmp z:ZPAD+freezpad+1
        bne forloop
nomoreloop:
.endscope
.endmacro

;bresenham line macro (high part)
;x16 is clobbered
;a8 and a16 are also used
.macro hamline_high x0, y0, x1, y1, col, freezpad
.scope
        RW_forced a8i16
        lda x0 ;x0
        sta z:ZPAD+freezpad
        lda x1 ;x1
        sta z:ZPAD+freezpad+1
        lda y0 ;y0
        sta z:ZPAD+freezpad+2
        lda y1 ;y1
        sta z:ZPAD+freezpad+3
        
        lda z:ZPAD+freezpad+1
        sub z:ZPAD+freezpad
        sta ham_dx ;dx = x1 - x0
      
        lda z:ZPAD+freezpad+3
        sub z:ZPAD+freezpad+2
        sta ham_dy ;dy = y1 - y0
        
        lda #1
        sta ham_xi ;xi = 1
        
        lda ham_dx
        bpl :+ ;if dx < 0
        lda #$ff
        sta ham_xi ;xi = -1
        lda ham_dx 
        neg ;xy = -dx
      : sta ham_dx
      
        asl
        sub ham_dy
        sta ham_dee ;D = (2*dx) - dy
      
        lda z:ZPAD+freezpad+2
        sta ham_y
        lda z:ZPAD+freezpad
        sta ham_x
forloop:
        RW a16i16
        lda ham_y-1
        and #$ff00
        lsr
        ora ham_x
        planarplot freezpad+4
        RW a8
        ; lda col
        ; sta f:pseudobitmap,x ; plot(x0, y0)
        
        lda ham_dee ;if D > 0
        bmi :+
        lda ham_x
        add ham_xi ; x += xi
        sta ham_x
        lda ham_dx
        sub ham_dy
        asl
        add ham_dee
        sta ham_dee ; D += 2 * (dx - dy)
        bra :++
      : lda ham_dx ; else
        asl
        add ham_dee
        sta ham_dee ; D += 2*dx
      : lda ham_y
        inc
        sta ham_y
        cmp z:ZPAD+freezpad+3
        bne forloop
nomoreloop:
.endscope
.endmacro

;bresenham line macro (general)
;x16 is clobbered
;a8 and a16 are also used
;x0, x1, y0, and y1 must be 8bit
.macro hamline x0, y0, x1, y1, col, freezpad
.scope
        RW_forced a8i16
        
        lda x1
        sub x0
        bpl :+
        neg
      : sta z:ZPAD+freezpad+1 ;abs(x1 - x0)
        
        lda y1
        sub y0
        bpl :+
        neg
      : sta z:ZPAD+freezpad ;abs(y1 - y0)
      
        cmp z:ZPAD+freezpad+1
        bcc :+ ;if abs(y1 - y0) < abs(x1 - x0)
        jmp if_abs_greater
       :
        
        lda x0
        cmp x1
        beq :+
        bcs if_x0_greater
        jmp if_x0_lesser ;if x0 > x1
      : jmp end_if_abs
    if_x0_greater:
        hamline_low {x1}, {y1}, {x0}, {y0}, col, freezpad+2
        jmp end_if_abs
    if_x0_lesser:
        hamline_low {x0}, {y0}, {x1}, {y1}, col, freezpad+2
        jmp end_if_abs
if_abs_greater: ;else
        lda y0
        cmp y1
        beq :+
        bcs if_y0_greater
        jmp if_y0_lesser ;if y0 > y1
      : jmp end_if_abs
    if_y0_greater:
        hamline_high {x1}, {y1}, {x0}, {y0}, col, freezpad+2
        jmp end_if_abs
    if_y0_lesser:
        hamline_high {x0}, {y0}, {x1}, {y1}, col, freezpad+2
end_if_abs: ;end if
.endscope
.endmacro

;planar pixel plotting macro because it's annoying
;a16 input is the position index
;stack IS used here, you need one byte of stack left
;x16 and a16 are clobbered
.macro planarplot freezpad
.scope
        ;we are targetting 2bpp planar
        ;save the position index for later
        sta z:ZPAD+freezpad
        
        ;get the first 3 bits of the x position
        and #%00000111
        tax
        lda plalut,x ;load a byte from the lut 
                      ;with the bit in the right 
                      ;position within the byte
        
        and #$00ff ;we only want the lower 8 bits thank you
        
        ;save the lut byte for later
        pha
        ;put the saved position index into x
        lda z:ZPAD+freezpad
        lsr
        and #$fffc
        tax
        ;pull the lut byte
        pla
        ;and use this to index the planar pseudobitmap
        ora f:planarpb,x
        ;lda #$ff00
        sta f:planarpb,x

.endscope
.endmacro

Main:
        ;libSFX calls Main after CPU/PPU registers, memory and interrupt handlers are initialized.
        ;load a program to the s-apu and run it
        .if ::USE_AUDIO
          RW a8i16
          jsr spcBoot ;copy the spc program
        
          ;a = bank #
          lda #^game_music
          jsr spcSetBank
          
          ;x = module_id
          ldx #0
          jsr spcLoad ; load the module

          ;a = bank #
          lda #^sfx_bank
          jsr spcSetBank
          
          jsr spcProcess

          ;a = starting position (pattern number)
          lda #0
          jsr spcPlay
          
          lda #$7f ;0-255, 7f is half volume 
          jsr spcSetModuleVolume
          
          jsr spcProcess
        .endif

        CGRAM_memcpy 0, m7isopalette, sizeof_m7isopalette
        CGRAM_memcpy 128, tankpalette, sizeof_tankpalette
        WRAM_memset pseudobitmap, 16384, $00

        RW a8i16
        
        lda #$00
        ldx #$0000
        
        RW a8i8
        
        VRAM_memcpy VRAM_MODE7_LOC, m7isotiles, sizeof_m7isotiles, $80, 0, $19       ;Transfer tiles to odd VRAM addresses
        ;VRAM_memcpy VRAM_MODE7_LOC, pseudobitmap, 16384, 0, 0, $18       ;Transfer map to even VRAM addresses
        
        ;Set up screen mode
        lda     #bgmode(BG_MODE_7, BG3_PRIO_NORMAL, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8)
        sta     BGMODE
        lda     #tm(ON, OFF, OFF, OFF, ON)
        sta     TM
        
        ;init mode 7 scroll and scale parameters
        stz BG1HOFS
        stz BG1HOFS
        stz BG1VOFS
        stz BG1VOFS
        
        lda     #<CENTER_X
        sta     M7X
        lda     #>CENTER_X
        sta     M7X
        lda     #<CENTER_Y
        sta     M7Y
        lda     #>CENTER_Y
        sta     M7Y
        
        lda #$01
        stz M7A
        sta M7A
        lda #$01
        stz M7D
        sta M7D
        
        stz M7SEL
        stz M7SEL

        lda #tm(OFF, OFF, OFF, OFF, ON)
        sta TM
        
        RW a8i16
        
        ldx #512 + 32 - 4
        zero_oam:
            stz shadow_oam + 3, x
            dex
            bne zero_oam
        
        ldx #1
        lda #$e0
        
        sweepspritedown:
            sta shadow_oam, x
            inx
            inx
            inx
            inx
            cpx #513
            bne sweepspritedown
            
        ldx #16
        
        tankhardrend:
            lda #%00110000            
            sta shadow_oam-1, x
            dex
            stz shadow_oam-1, x
            dex
            lda #24
            sta shadow_oam-1, x
            dex
            lda #24
            sta shadow_oam-1, x
            dex
            
            lda #%00110000            
            sta shadow_oam-1, x
            dex
            lda #$04
            sta shadow_oam-1, x
            dex
            lda #24
            sta shadow_oam-1, x
            dex
            lda #56
            sta shadow_oam-1, x
            dex
            
            lda #%00110000            
            sta shadow_oam-1, x
            dex
            lda #$40
            sta shadow_oam-1, x
            dex
            lda #56
            sta shadow_oam-1, x
            dex
            lda #24
            sta shadow_oam-1, x
            dex
            
            lda #%00110000            
            sta shadow_oam-1, x
            dex
            lda #$44
            sta shadow_oam-1, x
            dex
            lda #56
            sta shadow_oam-1, x
            dex
            lda #56
            sta shadow_oam-1, x
            dex
            
            ldx #512
            lda #%10101010
            sta shadow_oam, x
        
        lda #%01100010
        sta $2101
        
        ; ldx #$0204
        ; lda #$ff
        ; sta f:planarpb,x
        ; inx
        ; sta f:planarpb,x
        
        ;example of how to use hamline:
        ;hamline #8, #8, #50, #50, #$01, 0
        ;make sure col is #$01
        
        lda #INIT_SX ;initialise rotations
        sta z:matrix_sx
        lda #INIT_SY
        sta z:matrix_sy
        lda #INIT_SZ
        sta z:matrix_sz
        
polyrotation:
polyrotationsetup:
        RW i8
        
        ; x-
        ldx z:matrix_sx ;angle A
        ldy z:matrix_sy ;angle B
        
        mult_s8_s8 {sinlut+COSINE_OFFS,x}, {sinlut+COSINE_OFFS,y}, 6 ;xx = [cos(A)cos(B)]
        sta matrix_xx
      
        mult_s8_s8 {sinlut,x}, {sinlut+COSINE_OFFS,y}, 6 ;xy = [sin(A)cos(B)]
        sta matrix_xy
      
        ;xz = [sin(B)]
        RW a8
        lda sinlut,y
        sta matrix_xz
        stz matrix_xz
        
; y-
        ldy z:matrix_sz ;angle C
        
        mult_s8_s8 {sinlut,x}, {sinlut+COSINE_OFFS,y}, 6 ;yx = [sin(A)cos(C)
        sta z:ZPAD
      
        ldy z:matrix_sy
        mult_s8_s8 {sinlut+COSINE_OFFS,x}, {sinlut,y}, 6     ;+ cos(A)sin(B)sin(C)]
        sta z:ZPAD+2
        
        ldy z:matrix_sz
        mult_s8_s8 z:ZPAD+2, {sinlut,y}, 6
        add z:ZPAD
        sta matrix_yx
        
        mult_s8_s8 {sinlut+COSINE_OFFS,x}, {sinlut+COSINE_OFFS,y}, 6 ;yy = [-cos(A)cos(C)
        sta z:ZPAD
        
        ldy z:matrix_sy                                                                                  ;+ sin(A)sin(B)sin(C)]
        mult_s8_s8 {sinlut,x}, {sinlut,y}, 6
        sta z:ZPAD+2
        
        ldy z:matrix_sz
        mult_s8_s8 z:ZPAD+2, {sinlut,y}, 6
        sub z:ZPAD
        sta matrix_yy
        
        ldx z:matrix_sy
        mult_s8_s8 {sinlut+COSINE_OFFS,x}, {sinlut,y}, 6    ;yz = [-cos(B)sin(C)]
        neg
        sta matrix_yz
        
; z-
        ldx z:matrix_sx
        mult_s8_s8 {sinlut,x}, {sinlut,y}, 6 ;zx = [sin(A)sin(C)
        sta z:ZPAD
      
        ldy z:matrix_sy
        mult_s8_s8 {sinlut+COSINE_OFFS,x}, {sinlut,y}, 6      ;- cos(A)sin(B)cos(C)]
        sta z:ZPAD+2
        
        ldy z:matrix_sz
        mult_s8_s8 z:ZPAD+2, {sinlut+COSINE_OFFS,y}, 6
        sta z:ZPAD+2
        
        lda z:ZPAD
        sub z:ZPAD+2
        sta matrix_zx
      
        mult_s8_s8 {sinlut+COSINE_OFFS,x}, {sinlut,y}, 6    ;zy = [-cos(A)sin(C)
        neg
        sta z:ZPAD
      
        ldy z:matrix_sy
        mult_s8_s8 {sinlut,x}, {sinlut,y}, 6     ;- sin(A)sin(B)cos(C)]
        sta z:ZPAD+2
        
        ldy z:matrix_sz
        mult_s8_s8 z:ZPAD+2, {sinlut+COSINE_OFFS,y}, 6
        neg
        add z:ZPAD
        sta matrix_zy
        
        ldx z:matrix_sy
        mult_s8_s8 {sinlut+COSINE_OFFS,x}, {sinlut+COSINE_OFFS,y}, 6  ;zz = [cos(B)cos(C)]
        sta matrix_zz

; ?x*?y
        mult_s8_s8 matrix_xx+1, matrix_xy+1, 6
        sta matrix_xx_xy
        
        mult_s8_s8 matrix_yx+1, matrix_yy+1, 6
        sta matrix_yx_yy
        
        mult_s8_s8 matrix_zx+1, matrix_zy+1, 6
        sta matrix_zx_zy
        
        RW i16
        ldy #0
uopolyrotationloop:
        ;rember pemdas:
        ;
        ;parentheses first
        ;multiplication next
        ;then both adding and subtracting together
        ;
        mult_s8_s8 {a:qubo_x,y}, {a:qubo_y,y}, 0 ;but before all that, let's precalc x*y
        sta matrix_x_m_y ;not to be confused with matrix_xy

; x'   
        ;okay, now Please Excuse My Dear Aunt Sally
        ;(xx + y)(xy + x) + z*xz - (xx_xy + x_y)
        RW a8
        lda matrix_xx ;(xx + y)
        add a:qubo_y,y
        sta z:ZPAD
        lda matrix_xy ;(xy + x)
        add a:qubo_x,y
        sta z:ZPAD+2
        lda matrix_xx_xy ;(xx_xy + x_y)
        add matrix_x_m_y
        sta z:ZPAD+4
        
        mult_s8_s8 {a:qubo_z,y}, matrix_xz, 6 ;z*xz
        sta matrix_z_xz
        
        mult_s8_s8 z:ZPAD, z:ZPAD+2, 6 ;(xx + y)(xy + x)
        sta z:ZPAD+12
        
        lda z:ZPAD+12 ;(xx + y)(xy + x) + z*xz - (xx_xy + x_y)
        add matrix_z_xz
        sub z:ZPAD+4
        RW a8
        sta matrix_pointx,y
        
; y'
        ;(yx + y)(yy + x) + z*yz - (yx_yy + x_y)
        RW a8
        lda matrix_yx ;(yx + y)
        add a:qubo_y,y
        sta z:ZPAD
        lda matrix_yy ;(yy + x)
        add a:qubo_x,y
        sta z:ZPAD+2
        lda matrix_yx_yy ;(yx_yy + x_y)
        add matrix_x_m_y
        sta z:ZPAD+4
        
        mult_s8_s8 {a:qubo_z,y}, matrix_yz, 6 ;z*yz
        sta matrix_z_yz
        
        mult_s8_s8 z:ZPAD, z:ZPAD+2, 6 ;(yx + y)(yy + x)
        sta z:ZPAD+12
        
        lda z:ZPAD+12 ;(yx + y)(yy + x) + z*yz - (yx_yy + x_y)
        add matrix_z_yz
        sub z:ZPAD+4
        RW a8
        sta matrix_pointy,y
        
; z'
        ;(zx + y)(zy + x) + z*zz - (zx_zy + x_y)
        RW a8
        lda matrix_zx ;(zx + y)
        add a:qubo_y,y
        sta z:ZPAD
        lda matrix_zy ;(zy + x)
        add a:qubo_x,y
        sta z:ZPAD+2
        lda matrix_zx_zy ;(zx_zy + x_y)
        add matrix_x_m_y
        sta z:ZPAD+4
        
        mult_s8_s8 {a:qubo_z,y}, matrix_zz, 6 ;z*zz
        sta matrix_z_zz
        
        mult_s8_s8 z:ZPAD, z:ZPAD+2, 6 ;(zx + y)(zy + x)
        sta z:ZPAD+12
        
        lda z:ZPAD+12 ;(zx + y)(zy + x) + z*zz - (zx_zy + x_y)
        add matrix_z_zz
        sub z:ZPAD+4
        RW a8
        sta matrix_pointz,y
        
donepolyrotation:
        iny
        cpy #VERTEX_COUNT
        beq polyprojection
        jmp uopolyrotationloop
        
polyprojection:
        RW a8i16
        ldy #0
@poprloop:
        lda a:matrix_pointx,y
        sta a:pointxbyte,y
        
        lda a:matrix_pointy,y
        sta a:pointybyte,y
@nextloop:
        iny
        cpy #VERTEX_COUNT
        beq drawedge
        jmp @poprloop
        
drawedge:
        ldy #0
edgeloop:
@newline:
        RW a16
        lda a:qubo_edge1,y ;point 1 - x and y
        and #$00ff
        tax
        RW a8
        lda a:pointxbyte,x
        sta z:ZPAD
        lda a:pointybyte,x
        sta z:ZPAD+1
        
        RW a16
        lda a:qubo_edge2,y ;point 2 - x and y
        and #$00ff
        tax
        RW a8
        hamline z:ZPAD, z:ZPAD+1, {a:pointxbyte,x}, {a:pointybyte,x}, #$01, 2
@nextloop:
        iny
        cpy #EDGE_COUNT
        beq threeddone
        jmp edgeloop
        
threeddone:

        ;Set VBlank handler
        VBL_set VBlanc

        ;Turn on screen
        ;The vblank interrupt handler will copy the value in SFX_inidisp to INIDISP ($2100)
        lda     #inidisp(ON, DISP_BRIGHTNESS_MAX)
        sta     SFX_inidisp

        ;Turn on vblank interrupt
        VBL_on

:       wai
        bra :-

VBlanc: 
        RW a8i16
        
        lda #%00000010 ;Dear B Bus, 2 bytes to 1 address, increment, From, CPU
        sta $4300
        lda #$04 ;OAM Data Write
        sta $4301
        lda #.bankbyte(shadow_oam)
        sta $4304
        ldx #shadow_oam
        stx $4302
        ldx #544 ;bytes
        stx $4305
        
        lda #%00000001
        sta $4310
        lda #$18
        sta $4311
        lda #.bankbyte(planarpb)
        sta $4314
        ldx #.loword(planarpb)
        stx $4312
        ldx #4096
        stx $4315
        
        lda #%10000100
        sta $2115
        
        ldx #$4000
        stx $2116 
        
        lda #%00000011 ;channel 0+1
        sta $420B
        
        rtl
        
.segment "RODATA"
incbin tankpalette,        "data/tankpale.png.palette"
incbin m7isotiles,          "data/m7iso.png.tiles"
incbin m7isopalette,          "data/m7iso.png.palette"

;.segment "ROM1"
;incbin m7testpbm, "data/chunktest.png.pbm"

.segment "ROM2"
.align $100
incbin game_music, "data/game_music.bank", $0, 32768

.segment "ROM3"
incbin game_musicp2, "data/game_music.bank", $8000
incbin sfx_bank, "data/sfxbank.bank"
SNESMOD_SPC:
incbin snesmod_spc, "snesmoddoug/snesmod_driver.bin"
SNESMOD_SPC_END:

        
.segment "HIRAM"
pseudobitmap:
.align $100
.res 8192 ;formerly 16384

planarpb:
.align $100
.res 8192

.segment "ZEROPAGE"
threeddoneflag: .res 1
vramsplit: .res 1
vrampage: .res 1
camx: .res 1
camy: .res 1
camz: .res 1
invertpointx: .res 1
invertpointy: .res 1
invertpointz: .res 1
nopoint: .res 1
oldnopoint: .res 1
matrix_sx: .res 1
matrix_sy: .res 1
matrix_sz: .res 1

.segment "LORAM"
shadow_oam: .res 512+32

pointxbyte: .res (VERTEX_COUNT)
pointybyte: .res (VERTEX_COUNT)
oldpointxbyte: .res (VERTEX_COUNT)
oldpointybyte: .res (VERTEX_COUNT)

matrix_xx: .res 2
matrix_xy: .res 2
matrix_xz: .res 2

matrix_yx: .res 2
matrix_yy: .res 2
matrix_yz: .res 2

matrix_zx: .res 2
matrix_zy: .res 2
matrix_zz: .res 2

matrix_xx_xy: .res 2
matrix_yx_yy: .res 2
matrix_zx_zy: .res 2

matrix_x_m_y: .res 2
matrix_z_xz: .res 2
matrix_z_yz: .res 2
matrix_z_zz: .res 2

matrix_pointx: .res (VERTEX_COUNT * 2)
matrix_pointy: .res (VERTEX_COUNT * 2)
matrix_pointz: .res (VERTEX_COUNT * 2)

ham_dee: .res 1
ham_dx: .res 1
ham_dy: .res 1
ham_y: .res 2
ham_x: .res 2
ham_yi: .res 1
ham_xi: .res 1

matrix_edge: .res EDGE_COUNT
