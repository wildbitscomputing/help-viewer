    ;
    ; Start-up code for cc65 (Foenix F256 Jr)
    ;
    .export _exit, _event, _args
    .export __STARTUP__ : absolute = 1      ; Mark as start-up
    .exportzp _index0, _index1, _ptr0

    .export _map, _home, _clear, _color, _getc, _newline
    .export _at, _putc, _puts, _puti, _puth8, _puth16
    .export _get_machine_id

    .import initlib, donelib
    .import zerobss
    .import copydata
    .import _main
    .import decompress_start
    .import __STACKSTART__   ; From f256.cfg
    .import __END_LOAD__, __HIMEM__
    .importzp src_ptr, dest_ptr

    HEAP = (__END_LOAD__ + $1fff) & $E000
    .global __heaporg
    .global __heapptr
    .global __heapend
    .global __heapfirst
    .global __heaplast

    .include "zeropage.inc"


.scope kernel
    next_event  = $ff00

    .scope event
        type = _event+0

        .scope key
            ascii       = _event+5

            PRESSED     = $08
            RELEASED    = $0A
        .endscope
    .endscope
.endscope

.scope mmu
    mem_ctrl    = $00
    io_ctrl     = $01
    lut         = $08
.endscope

.scope system
    machineid   = $d6a7         ; Access machine id
.endscope


    .segment "ZEROPAGE" : zeropage
_event:         .res    8
_index0:        .res    1
_index1:        .res    2
_ptr0:          .res    2
text_ptr:       .res    2


    .segment "KERNEL_ARGS" : zeropage
_args:          .res    16

    .segment "INIT"
spsave:         .res    1

    .segment "BSS"
column:         .res    1
row:            .res    1
text_color:     .res    1

    .segment "DATA"
__heaporg:      .word   HEAP
__heapptr:      .word   HEAP
__heapend:      .word   __HIMEM__
__heapfirst:    .word   0
__heaplast:     .word   0


    .segment "END"       ; Defined for heap computation


    .PC02

    .segment "STARTUP"
Start:
    ; Disable interrupts
    sei

    ; Stash the original stack pointer so we can "return"
    ; to DOS (or whatever) from anywhere.
    tsx
    stx spsave

    ; Run the rest of the init code from the ONCE segment;
    ; the ONCE segment may then be merged into the heap.
    jsr initialize

    cli

    ; Push the command-line arguments, and call main().
    jsr _main


_exit:
    stz $1
    stz $D010
    stz $D001               ; restore font selection

    ; Restore the original stack pointer
    ldx spsave
    txs

    ; Run cleanup.
    jsr donelib

    ; Return to the shell
    rts


    .segment "ONCE"


initialize:
    ; Set up the stack.
    lda     #<__STACKSTART__
    ldx     #>__STACKSTART__
    sta     sp
    stx     sp+1            ; Set argument stack ptr

    ; Call the module constructors.
    jsr     initlib

    ; Zero the BSS
    jsr     zerobss

    ; Initialze statically initialized variables.
    jsr     copydata

    ; Initialize the kernel interface.
    lda     #<_event
    sta     _args+0
    stz     _args+1

    ; Initialize display
    stz     $01

    lda     #$01
    sta     $D000                   ; text only display
    lda     #$20
    sta     $D001                   ; 320x240 @60Hz with font set 1
    stz     $D004                   ; no borders
    stz     $D010                   ; no cursor


    ; Setup text color palette
    ldy     #0
@copy_palette:
    lda     text_palette, y
    sta     $D800, y
    sta     $D840, y
    iny
    cpy     #text_palette_len
    bne     @copy_palette

    ; Make sure we are able to edit the active LUT
    lda     mmu::mem_ctrl
    and     #$03
    sta     _index0
    asl
    asl
    asl
    asl
    ora     #$80
    ora     _index0
    sta     mmu::mem_ctrl


    ; Load alternative 8x16 font
    lda     #<font
    sta     src_ptr
    lda     #>font
    sta     src_ptr+1
    stz     dest_ptr
    lda     #$c8
    sta     dest_ptr+1

    lda     #$01
    sta     mmu::io_ctrl
    jsr     decompress_start


    ; Clear screen
    lda     #$92                    ; light grey foreground, dark blue background
    sta     text_color
    jsr     _clear

    rts


    .segment "CODE"

;
; Map a specific slot to address $A000
;
    .proc _map: near
    sta     mmu::lut+5
    rts
    .endproc


;
; Move cursor to top left corner
;
    .proc _home: near

    pha
    stz     text_ptr
    lda     #$C0
    sta     text_ptr+1
    stz     column
    stz     row
    pla
    rts

    .endproc


;
; Clear screen
;
    .proc _clear: near

    pha
    phy
    phx
    jsr     _home

    lda     #$02                    ; fill text area with space
    sta     $01
    lda     #' '
    jsr     fill

    jsr     _home

    inc     $01                     ; fill color area
    lda     text_color
    jsr     fill

    jsr     _home

    plx
    ply
    pla
    rts

    .endproc


fill:
    ldy     #0
@row:
    ldx     #0
@column:
    sta     (text_ptr)
    inc     text_ptr
    bne     @next
    inc     text_ptr+1
@next:
    inx
    cpx     #80
    bne     @column

    iny
    cpy     #60
    bne     @row
    rts


;
; Set text and background color
;
    .proc _color: near

    sta     text_color
    rts

    .endproc



;
; Move text cursor to specified row and column
;
    .proc _at: near

    tay
    sta     row
    lda     (sp)
    sta     column
    inc     sp                          ; pop x argument from stack

    lda     row_start_low, y
    sta     text_ptr
    lda     row_start_high, y
    sta     text_ptr+1

    rts

    .endproc


;
; Print character in A
;
    .proc _putc: near

    pha
    phy
    jsr     output_char
    ply
    pla
    rts

    .endproc


output_char:
    ; Write top half of character
    ldy     #$02
    sty     mmu::io_ctrl
    ldy     column
    sta     (text_ptr),y
    clc
    adc     #128
    pha

    inc     mmu::io_ctrl
    lda     text_color
    sta     (text_ptr),y

    ; Write bottom half of character
    tya
    clc
    adc     #80
    tay

    dec     mmu::io_ctrl
    pla
    sta     (text_ptr),y

    inc     mmu::io_ctrl
    lda     text_color
    sta     (text_ptr),y


    ldy     column
    iny
    cpy     #80
    beq     _newline
    sty     column
    rts


;
; Move cursor to the next line
;
    .proc _newline: near

    stz     column
    inc     row
    lda     row
    cmp     #30
    beq     @at_bottom

    ldy     row
    lda     row_start_low, y
    sta     text_ptr
    lda     row_start_high, y
    sta     text_ptr+1

    rts

@at_bottom:
    lda     #29
    sta     row
    rts

    .endproc


;
; Print the null terminated string in A/X
;
    .proc _puts: near

    ; Save _ptr0 so we don't break any user code
    ldy     _ptr0
    phy
    ldy     _ptr0+1
    phy

    sta     _ptr0
    stx     _ptr0+1

    ldy     #0
    clc
@loop:
    lda     (_ptr0),y
    beq     @done
    jsr     _putc
    iny
    bne     @loop
@done:

    ; Restore _ptr0 value
    pla
    sta     _ptr0+1
    pla
    sta     _ptr0

    rts

    .endproc



    .proc _puth8: near
    pha
    lsr
    lsr
    lsr
    lsr
    jsr     @put_nibble
    pla

@put_nibble:
    and     #$0f
    cmp     #10
    bcc     @output_digit
    adc     #6                          ; convert a : to A
@output_digit:
    adc     #'0'
    jsr     _putc
    rts
    .endproc


    .proc _puth16: near
    pha
    txa
    jsr     _puth8
    pla
    jmp     _puth8
    .endproc


;
; Print number in A/X
;
; Taken from the page: https://beebwiki.mdfs.net/Number_output_in_6502_machine_code
;
    .proc _puti: near

    ; Save _index1 value
    ldy     _index1
    phy
    ldy     _index1+1
    phy

    ; Store value to print in _index1
    sta     _index1
    stx     _index1+1

    ldy     #8
@loop1:
    ldx     #$ff
    sec
@loop2:
    lda     _index1
    sbc     @tens, y
    sta     _index1

    lda     _index1+1
    sbc     @tens+1, y
    sta     _index1+1

    inx
    bcs     @loop2                        ; loop until <0

    lda     _index1
    adc     @tens, y
    sta     _index1
    lda     _index1+1
    adc     @tens+1, y
    sta     _index1+1

    txa
    bne     @print_digit
    bra     @next
@print_digit:
    ora     #'0'
    jsr     output_char
@next:
    dey
    dey
    bpl     @loop1

@done:
    ; Store _index1 value
    pla
    sta     _index1+1
    pla
    sta     _index1

    rts

@tens:
    .word   1
    .word   10
    .word   100
    .word   1000
    .word   10000
    .endproc



;
; Return the machine id
;
    .proc _get_machine_id: near

    stz     $01
    ldx     #$00
    lda     system::machineid
    rts

    .endproc

;
; Wait for keypress, and return ascii code in A
;
    .proc _getc: near

    ldx     #$00

    jsr     kernel::next_event
    bcs     _getc

    lda     kernel::event::type
    cmp     #kernel::event::key::PRESSED
    bne     _getc

    lda     kernel::event::key::ascii
    beq     _getc

    rts

    .endproc


    .segment "RODATA"

text_palette:
    ; standard SuperBASIC text palette, in BGRA byte order
    .byte   $00, $00, $00, $00     ;  0 black
    .byte   $66, $66, $66, $00     ;  1 grey
    .byte   $aa, $00, $00, $00     ;  2 dark blue
    .byte   $00, $aa, $00, $00     ;  3 green
    .byte   $ea, $41, $c0, $00     ;  4 purple
    .byte   $00, $48, $87, $00     ;  5 brown
    .byte   $00, $9c, $ff, $00     ;  6 orange
    .byte   $ff, $db, $57, $00     ;  7 light blue
    .byte   $28, $3f, $3f, $00     ;  8 dark grey
    .byte   $8a, $aa, $aa, $00     ;  9 light grey
    .byte   $ff, $55, $55, $00     ; 10 blue
    .byte   $55, $ff, $55, $00     ; 11 light green
    .byte   $ed, $8d, $ff, $00     ; 12 light purple
    .byte   $00, $00, $ff, $00     ; 13 red
    .byte   $55, $ff, $ff, $00     ; 14 yellow
    .byte   $ff, $ff, $ff, $00     ; 15 white
text_palette_len    = *-text_palette

row_start_low:
    .byte $00, $a0, $40 ,$e0, $80, $20, $c0, $60, $00, $a0
    .byte $40, $e0, $80, $20, $c0, $60, $00, $a0, $40, $e0
    .byte $80, $20, $c0, $60, $00, $a0, $40, $e0, $80, $20
row_start_high:
    .byte $c0, $c0, $c1, $c1, $c2, $c3, $c3, $c4, $c5, $c5
    .byte $c6, $c6, $c7, $c8, $c8, $c9, $ca, $ca, $cb, $cb
    .byte $cc, $cd, $cd, $ce, $cf, $cf, $d0, $d0, $d1, $d2

font:
    .incbin "../resources/font_compressed.bin"
