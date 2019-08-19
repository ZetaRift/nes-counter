; A counter that actually shows something on the screen
; The counter is timed by the PPU's vblank so the loop is run through 60 times per second (On NTSC)
; Assemble with NESASM

;;;;;;;;;;;;;;;;; Variable assignment here
; $0000 Sleep timer, the main program loop won't run if this isn't zero, each PPU vblank zeroes this out

frametimer = $0001 ; Frame timer
hundred = $0002 ; Hundredth counter
ten = $0003 ; Tenth counter
second = $0004 ; Second counter
tenth = $0005
Joy1_buttons = $0010 ; Controller #1 Button state (A(MSB), B, Select, Start, Up, Down, Left, Right(LSB))
movedelta = $0018 ; Sprite movement delta (XY per frame)
movedelay = $0019 ; Move delay per frame
moveframe = $001A ; Move delay frame counter (for comparsion)
sprite1ypos = $0200 ; Sprite 1 Y position 
sprite1index = $0201 ; Sprite 1 index
sprite1attr = $0202 ; Sprite 1 attributes
sprite1xpos = $0203 ; Sprite 1 X position

sprite2ypos = $0204 ; Sprite 2 Y position
sprite2index = $0205 ; Sprite 2 index
sprite2attr = $0206 ; Sprite 2 attributes
sprite2xpos = $0207 ; Sprite 2 X position

sprite3ypos = $0208 ; Sprite 3 Y position
sprite3index = $0209 ; Sprite 3 index
sprite3attr = $020A ; Sprite 3 attributes
sprite3xpos = $020B ; Sprite 3 X position

rstcount = $0701 ; Reset count, reset persistient 

BUTTON_A      = 1 << 7 ; $80
BUTTON_B      = 1 << 6 ; $40
BUTTON_SELECT = 1 << 5 ; $20
BUTTON_START  = 1 << 4 ; $10
BUTTON_UP     = 1 << 3 ; $08
BUTTON_DOWN   = 1 << 2 ; $04
BUTTON_LEFT   = 1 << 1 ; $02
BUTTON_RIGHT  = 1 << 0 ; $01

Joy1 = $4016 ; Joystick #1

  .inesmir 0
  .inesmap 0 ; NROM
  .inesprg 1 ; 16K PRG
  .ineschr 1 ; 8K CHR
  .bank 1
  .org $FFFA
  .dw NMI ; Non maskable interrupt vector
  .dw RESET ; Reset vector
  .dw 0 ; IRQ vector, we don't need an IRQ handler

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

  lda second ; Second number
  sta sprite3index
  
  lda ten ; Tenth number
  sta sprite2index

  lda hundred ; Hundredth number
  sta sprite1index


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
  ldx rstcount ; N of resets, reset persistent
  inx
  stx rstcount
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
  sta second

vblank2:
  bit $2002
  bpl vblank2
  ldx #$00
  
  stx hundred ; Or else the program breaks
  stx ten
  stx second
  
  lda $2002
  lda #$3F
  sta $2006
  lda #$10
  sta $2006 ; Access PPU memory at $3F10
  ldx #$00

loadpalettes:
  lda $2002
  lda #$3F
  sta $2006
  lda #$00
  sta $2006 ; PPU memory #3F00
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
  sta sprite1xpos ; Screen X
  sta sprite1ypos ; Screen Y
  lda #$00 ; Loads sprite referencing variable
  sta sprite1index
  sta sprite1attr
;;;;;;;;;;;;;;;; Sprite 2
  lda #$88 
  sta sprite2xpos ; Screen X
  lda #$80
  sta sprite2ypos ; Screen Y
  lda #$00
  sta sprite2index
  sta sprite2attr

;;;;;;;;;;;;;;;; Sprite 3
  lda #$90
  sta sprite3xpos ; Screen X
  lda #$80
  sta sprite3ypos ; Screen Y
  lda #$00
  sta sprite3index
  sta sprite3attr

  lda #$01
  sta movedelta
;;;;;;;;;;;;;;;; Main program loop
main:
  inc $0000
vblankend:
  lda $0000
  bne vblankend ; Loop back to vblankend until after a PPU vblank


  lda #$00
  sta Joy1_buttons
  jsr rstattr
  jsr readjoy
  ldx moveframe
  cpx movedelay
  bcs movesprites
  inx
  stx moveframe
spritesdone: ; Just to treat movesprites as if it were a subroutine since doing an rts from a far away section of the program can cause problems
  lda Joy1_buttons
  and #BUTTON_A
  bne resetall
  ldx frametimer
  
  cpx #59 ; Change to 49 if on PAL
  bcs countup
  inx
  stx frametimer
  jmp loopend
loopend:
  jmp main
  
rstattr:
  sta sprite1attr
  sta sprite2attr
  sta sprite3attr
  rts

resetall: ; Resets counters including frame counter
  ldx #$00
  stx frametimer
  stx hundred
  stx ten
  stx second
  lda #$01
  sta sprite1attr
  sta sprite2attr
  sta sprite3attr
  jmp loopend
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Increment counter variables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

countup:
  ldx #00
  stx frametimer

secinc:
  ldx second
  cpx #$09
  bcs teninc
  inx
  stx second
  jmp loopend

movesprites:
  jmp movespritesfar

teninc:
  ldx #$00
  stx second

  ldx ten
  cpx #$09
  bcs hundinc
  inx
  stx ten
  jmp loopend
  
hundinc:
  ldx #00 ; Zero out second and tenth second
  stx second
  stx ten

  ldx hundred
  cpx #09 ; We want to reset back to zero if we get past 9
  beq resetcounter
  inx
  stx hundred

  jmp loopend

resetcounter: ; Resets counters
  ldx #$00
  stx hundred
  stx ten
  stx second
  jmp loopend
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Joystick button check routine, now using a ring counter
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
readjoy:
  lda #$01
  ; While the strobe bit is set, buttons will be continuously reloaded.
 ; This means that reading from JOYPAD1 will only return the state of the
  ; first button: button A.
  sta Joy1
  sta Joy1_buttons
  lsr a        ; now A is 0
  ; By storing 0 into JOYPAD1, the strobe bit is cleared and the reloading stops.
  ; This allows all 8 buttons (newly reloaded) to be read from JOYPAD1.
  sta Joy1
loop:
  lda Joy1
  lsr a	       ; bit 0 -> Carry
  rol Joy1_buttons  ; Carry -> bit 0; bit 7 -> Carry
  bcc loop
  rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Check button states and move sprites as needed
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

movespritesfar:
  ldx #$00
  stx moveframe
  lda Joy1_buttons
  and #BUTTON_UP
  bne spritesup
dnchk:
  lda Joy1_buttons
  and #BUTTON_DOWN
  bne spritesdown
ltchk:
  lda Joy1_buttons
  and #BUTTON_LEFT
  bne spritesleft
rtchk:
  lda Joy1_buttons
  and #BUTTON_RIGHT
  bne spritesright
  jmp spritesdone

spritesup:
  sec
  lda sprite1ypos
  sbc movedelta
  sta sprite1ypos

  sec
  lda sprite2ypos
  sbc movedelta
  sta sprite2ypos

  sec
  lda sprite3ypos
  sbc movedelta
  sta sprite3ypos
  cld
  jmp dnchk

spritesdown:
  clc
  lda sprite1ypos
  adc movedelta
  sta sprite1ypos

  clc
  lda sprite2ypos
  adc movedelta
  sta sprite2ypos

  clc
  lda sprite3ypos
  adc movedelta
  sta sprite3ypos
  jmp ltchk

spritesleft:

  sec
  lda sprite1xpos
  sbc movedelta
  sta sprite1xpos

  sec
  lda sprite2xpos
  sbc movedelta
  sta sprite2xpos

  sec
  lda sprite3xpos
  sbc movedelta
  sta sprite3xpos
  cld
  jmp rtchk

spritesright:
  clc
  lda sprite1xpos
  adc movedelta
  sta sprite1xpos

  clc
  lda sprite2xpos
  adc movedelta
  sta sprite2xpos

  clc
  lda sprite3xpos
  adc movedelta
  sta sprite3xpos
  jmp spritesdone
