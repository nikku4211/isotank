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
        
        ldx #$0204
        lda #$ff
        sta f:planarpb,x
        inx
        sta f:planarpb,x
        
        hamline #8, #8, #64, #32, #$01, 0

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

pointxword: .res (VERTEX_COUNT * 2)
pointyword: .res (VERTEX_COUNT * 2)
oldpointxword: .res (VERTEX_COUNT * 2)
oldpointyword: .res (VERTEX_COUNT * 2)

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
