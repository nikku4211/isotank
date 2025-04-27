.include "libSFX.i"
.include "sinlut.i"
.include "idlut.i"
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
USE_AUDIO = 1

COSINE_OFFS = 64

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
            
        ldx #4
        lda #%00110000
        
        sta shadow_oam-1, x
        dex
        
        tankhardrend:
            stz shadow_oam-1, x
            dex
            lda #24
            sta shadow_oam-1, x
            dex
            lda #24
            sta shadow_oam-1, x
            dex
            ldx #512
            lda #%00000010
            sta shadow_oam, x
        
        lda #%01100010
        sta $2101
        
        ldx #$0200
        lda #$ff
        sta f:pseudobitmap,x
        inx
        sta f:pseudobitmap,x

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
        lda #.bankbyte(pseudobitmap)
        sta $4314
        ldx #.loword(pseudobitmap)
        stx $4312
        ldx #2048
        stx $4315
        
        lda #%10000000
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
