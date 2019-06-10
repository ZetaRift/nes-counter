; A counter that actually shows something on the screen
; The counter is timed by the PPU's vblank so the loop is run through 60 times per second (On NTSC)
; Variable references:
; $0000 Sleep timer
; $0001 Frame timer (Resets after 3C, or 60)
; $0002 Hundredth counter
; $0003 Tenth counter
; $0004 Second counter
; $0011-$0018 Controller button state (A, B, Select, Start, Up, Down, Left, Right)
; $0200-$0203: Sprite 1 (Y pos, sprite index, sprite attribute, X pos)
; $0204-$0207: Sprite 2 (Y pos, sprite index, sprite attribute, X pos)
; $0208-$020B: Sprite 3 (Y pos, sprite index, sprite attribute, X pos)
; $0701 Reset count, reset persistient
; Assemble with NESASM
  .inesmir 0
  .inesmap 0 ; NROM
  .inesprg 1 ; 16K PRG
  .ineschr 1 ; 8K CHR
  .bank 1
  .org $FFFA
  .dw NMI
  .dw RESET
  .dw 0

;;;;;;;;;;;;;;;; Sprite and palette data here

  .bank 2
  .org $0000
  .incbin "numbers.chr" ; 8x8 sprite sheet
  .bank 1
  .org $E000
PaletteData:
  .db $0F,$31,$32,$33,$0F,$35,$36,$37,$0F,$39,$3A,$3B,$0F,$3D,$3E,$0F  ;background palette data
  .db $0F,$26,$10,$30,$0F,$05,$10,$31,$0F,$11,$10,$31,$0F,$11,$10,$31  ;sprite palette data

sprites:
  .db $00, $00, $00

  .bank 0
  .org $C000

;;;;;;;;;;;;;;;; NMI handler

NMI:
  pha
  txa
  pha
  tya
  pha
  ; From here on out until rti, we can do things to the PPU while in its vblank state

updatesprites: ; Update the sprite attributes before DMA transfer
  lda $0004 ; Hundredth number
  sta $0209
  lda $0011
  sta $020A
  
  lda $0003 ; Tenth number
  sta $0205
  lda $0011
  sta $0206

  lda $0002 ; Second number
  sta $0201
  lda $0011
  sta $0202

dmatransfer: ; Copy the sprite attributes from RAM to the PPU OAM (Object Attribute Memory)
  lda #$00
  sta $2003
  lda #$02 ; Transfer data from $0200-$02FF to PPU OAM
  sta $4014

  lda #$0
  sta $0000
  pla
  tay
  pla
  tax
  pla
  rti

;;;;;;;;;;;;;;;; Reset routine

RESET: ; Ensure that PPU is ready first to limit the logic to 60 runs per second
  sei ; Ignore IRQ
  cld ; Decimal mode disable
  lda #$40
  stx $4017; APU frame IRQ disable
  ldx $701 ; N of resets, reset persistent
  inx
  stx $701
  ldx #$FF
  txs ; Stack setup
  inx ; Zeroed out
  stx $2000 ; Disable NMI
  stx $2001 ; Disable render
  stx $4010 ; Disable DMC IRQs

  bit $2002 ; Or else there's a chance vblank1 will see true and skip
vblank1:
  bit $2002
  bpl vblank1
  
  txa ; Some RAM clearing
memclear:
  lda #$00
  sta $0000,x
  sta $0100,x
  sta $0200,x
  sta $0300,x
  sta $0400,x
  sta $0500,x
  sta $0600,x
  lda #$FE
  sta $0200,x
  inx
  bne memclear
  lda #%10000000
  sta $0004

vblank2:
  bit $2002
  bpl vblank2
  ldx #$00
  
  stx $0002 ; Or else the program breaks
  stx $0003
  stx $0004
  
  lda $2002
  lda #$3F
  sta $2006
  lda #$10
  sta $2006
  ldx #$00

loadpalettes:
  lda $2002
  lda #$3F
  sta $2006
  lda #$00
  sta $2006
  ldx #$00
loadpalettesloop:
  lda PaletteData, x
  sta $2007
  inx
  cpx #$20
  bne loadpalettesloop

loadsprites:
  ldx #$00
loadspritesloop:
  lda sprites,x
  sta $0200,x
  inx
  cpx #$03
  bne loadspritesloop

  lda #%00010000
  sta $2001 ; Enable sprites

  lda #%10000000
  sta $2000 ; Allow PPU to call an NMI at vblank


;;;;;;;;;;;;;;;; Put our initial sprites on the screen, this will show up on the next vblank

;;;;;;;;;;;;;;;; Sprite 1
  lda #$80 ; Sprite positioned on center of screen
  sta $0203 ; Screen X
  sta $0200 ; Screen Y
  lda #$00 ; Loads sprite referencing variable
  sta $0201
  sta $0202
;;;;;;;;;;;;;;;; Sprite 2
  lda #$88 
  sta $0207 ; Screen X
  lda #$80
  sta $0204 ; Screen Y
  lda #$00
  sta $0205
  sta $0206

;;;;;;;;;;;;;;;; Sprite 3
  lda #$90
  sta $020B ; Screen X
  lda #$80
  sta $0208 ; Screen Y
  lda #$00
  sta $0209
  sta $020A

;;;;;;;;;;;;;;;; Main program loop
main:
  inc $0000
vblankend:
  lda $0000
  bne vblankend
  lda #$00
  sta $0011
  sta $0012
  sta $0013
  sta $0014
  sta $0015
  sta $0016
  sta $0017
  sta $0018
  jsr contcheck
  lda $0011
  cmp #$01
  beq resetall
  ldx $0001
  
  cpx #59 ; Change to 49 if on PAL
  bcs countup
  
  ldx $0001
  inx
  stx $0001
  jmp loopend
loopend:
  jmp main
  
resetall: ; Resets counters including frame counter
  ldx #$00
  stx $0001
  stx $0002
  stx $0003
  stx $0004
  jmp loopend

countup:
  ldx #00
  stx $0001

secinc:
  ldx $0004
  cpx #$09
  bcs teninc
  inx
  stx $0004
  jmp loopend

teninc:
  ldx #$00
  stx $0004

  ldx $0003
  cpx #$09
  bcs hundinc
  inx
  stx $0003
  jmp loopend
  
hundinc:
  ldx #00 ; Zero out second and tenth second
  stx $0004
  stx $0003

  ldx $0002
  cpx #09 ; We want to reset back to zero if we get past 9
  beq resetcounter
  inx
  stx $0002

  jmp loopend

resetcounter: ; Resets counters
  ldx #$00
  stx $0002
  stx $0003
  stx $0004
  jmp loopend

contcheck: ; Subroutine to check for controller button states sequentially, seems to be the most reliable so far
  lda #$01 ; Strobe the controller so we can poll for pressed/released states
  sta $4016
  lda #$00
  sta $4016 ; Avoiding a jsr + rts chain to save a few cycles

ReadA:
  lda $4016
  and #%00000001 ; A button
  bne apressed

ReadB:
  lda $4016 ; B
  and #%00000001
  bne bpressed

ReadSel:
  lda $4016 ; Select
  and #%00000001
  bne selpressed

ReadSta:
  lda $4016 ; Start
  and #%00000001
  bne stapressed

ReadUp:
  lda $4016 ; Up
  and #%00000001
  bne uppressed

ReadDn
  lda $4016 ; Down
  and #%00000001
  bne dwnpressed

ReadLt:
  lda $4016 ; Left
  and #%00000001
  bne ltpressed

ReadRt:
  lda $4016 ; Right
  and #%00000001
  bne rtpressed

  rts
apressed:
  lda #$01
  sta $0011
  jmp ReadB

bpressed:
  lda #$01
  sta $0012
  jmp ReadSel

selpressed:
  lda #$01
  sta $0013
  jmp ReadSta

stapressed:
  lda #$01
  sta $0014
  jmp ReadUp

uppressed:
  lda #$01
  sta $0015

  ; Move our numbers up
  ldx $0200
  dex
  stx $0200

  ldx $0204
  dex
  stx $0204

  ldx $0208
  dex
  stx $0208

  jmp ReadDn

dwnpressed:
  lda #$01
  sta $0016

  ; Move our numbers down
  ldx $0200
  inx
  stx $0200

  ldx $0204
  inx
  stx $0204

  ldx $0208
  inx
  stx $0208

  jmp ReadLt

ltpressed:
  lda #$01
  sta $0017

  ; Move our numbers left
  ldx $0203
  dex
  stx $0203

  ldx $0207
  dex
  stx $0207

  ldx $020B
  dex
  stx $020B
  jmp ReadRt

rtpressed:
  lda #$01
  sta $0018

    ; Move our numbers right
  ldx $0203
  inx
  stx $0203

  ldx $0207
  inx
  stx $0207

  ldx $020B
  inx
  stx $020B
  rts