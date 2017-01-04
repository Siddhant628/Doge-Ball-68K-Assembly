;********************************************************************
; A subroutine which takes a number as an input and displays it
; using three 7-segment LEDs at a specific position given by user

PEN_COLOR_TRAP_CODE         EQU     80
PEN_WIDTH_TRAP_CODE         EQU     93
DRAW_LINE_TRAP_CODE         EQU     84

COLOR                       EQU     $00C0C0C0
PEN_WIDTH                   EQU     5           ; Don't change pen width
DISPLACEMENT_BETWEEN_LED    EQU     60

VALUE_FOR_SUBROUTINE        EQU     356
TOP_LEFT_X                  EQU     0
TOP_LEFT_Y                  EQU     400

VALUE_FOR_SUBROUTINE_S      EQU     4
TOP_LEFT_X_S                EQU     8
TOP_LEFT_Y_S                EQU     12

LED_USED_REG                REG     D0/D1/D2/D3/D4/D5/D6/A0/A1

; Subroutine to be called to display the entire number
displayNumberOnLEDs:
; Save the registers which will be used
    movem.l LED_USED_REG, -(sp)
    add.l   #36, sp
; Set the pen color to white
    move.l  #PEN_COLOR_TRAP_CODE, d0
    move.l  #COLOR, d1
    trap    #15
; Set pen width to 5 pixels    
    move.l  #PEN_WIDTH_TRAP_CODE, d0
    move.l  #PEN_WIDTH, d1
    trap    #15
; Save the number to display in memory    
    move.l  VALUE_FOR_SUBROUTINE_S(sp), d0
    move.l  d0, tempData
; Check the number of digits in the number
    cmpi.l  #999, d0
    bgt     scoreNotDisplayed
    cmpi.l  #99, d0
    bgt     tripleDigitScore
    cmpi.l  #9, d0
    bgt     doubleDigitScore
; Save the number of digits in memory
singleDigitScore:
    move.l  #1, lengthOfNumber
    bra     displayNumber
doubleDigitScore:
    move.l  #2, lengthOfNumber
    bra     displayNumber
tripleDigitScore:    
    move.l  #3, lengthOfNumber
    bra     displayNumber
; Conditions for LED displaying loop    
displayNumber:
    clr     d6
    move.l  lengthOfNumber, d7
; A loop which performs displaying of one digit of the number at a time, starting from the
; right most place value    
displayLoop:
    move.l  tempData, d0                    ; Load the number to display into d0
    move.l  d0, d6
    cmpi.l  #1, d7
    beq     dontDivide                      ; Check if the digit to display is in ones place, i.e. right most place value
    divu    #10, d0
    move.l  d0, d6    
    andi.l  #$0000FFFF, d0                  ; d0 = Quotient
    move.l  d0, tempData
    andi.l  #$FFFF0000, d6                  ; Contains remainder term
    ror.l   #8, d6
    ror.l   #8, d6                          ; d6 = Remainder
dontDivide: 
    move.l  #DISPLACEMENT_BETWEEN_LED, d5
    move.l  d7, d4
    sub.l   #1, d4
    mulu    d4, d5                          ; Offset along the X from the top left corner of the LED display (X Offset = Number of digits before the digit (d4) * Pixel width for each digit (d5))
    add.l   TOP_LEFT_X_S(sp), d5            ; Top left corner of where the LED should be displayed
    move.l  TOP_LEFT_Y_S(sp), -(sp)         ; Top left Y position for particular digit
    move.l  d5, -(sp)                       ; Top left X position for particular digit
    move.l  d6, -(sp)                       ; Digit to display pushed on stack
    
    jsr displayValueOnLEDs
    add.l   #12, sp
    sub.l   #1, d7                          ; Number of digits left to display
    bne     displayLoop                     
scoreNotDisplayed:    
    sub.l   #36, sp
    movem.l (sp)+, LED_USED_REG
    rts
    
; SUBROUTINE for display a number
displayValueOnLEDs:
    movem.l LED_USED_REG, -(sp)             ; Save the contents of registers which would be used by subroutine
    add.l   #36, sp                         ; Incrementing sp to access the user input easily
    
    move.l  VALUE_FOR_SUBROUTINE_S(sp), d0  ; Load the value in d0
    move.l  #digitTable, a0
    clr.l   d1
    move.l  #ledDisplayOffsetTable, a1
    move.b  (a0, d0), d1                    ; Acquire the mask byte for the number in d0 
    move.l  d1, d5                          ; d5 will store the original byte and it will be rotated to access mask bits
    move.l  #ledDisplayOffsetTable, d6
    add.l   #28, d6                         ; d6 contains the address for last value of led offset table
        
displayLEDs:
; Check the mask bit
    move.l  d5, d2                          ; Move the shifted byte to d2 
    andi.l  #1, d2
    beq     displayingLEDNotRequired        ; Continue if the mask bit is 1
; Load the (xi, yi) and (xf, yf) for display into d1, d2, d3, d4
    clr     d1
    clr     d2
    clr     d3
    clr     d4

    move.b  (a1)+, d1
    add.l   TOP_LEFT_X_S(sp), d1            ; Estimate the initial position for display from top left X
    move.b  (a1)+, d2
    add.l   TOP_LEFT_Y_S(sp), d2            ; Estimate the initial position for display from top left Y
    move.b  (a1)+, d3
    add.l   TOP_LEFT_X_S(sp), d3            ; Estimate the final position for display from top left Y
    move.b  (a1)+, d4
    add.l   TOP_LEFT_Y_S(sp), d4            ; Estimate the final position for display from top left Y
; Draw the line   
    move.l  #DRAW_LINE_TRAP_CODE, d0
    trap    #15
    bra     skipIncreasingAddress
displayingLEDNotRequired:    
    add.l   #4, a1
skipIncreasingAddress:    
    lsr.l   #1, d5                          ; Shifting the byte to access next mask bit
    cmp.l   d6, a1
    blt     displayLEDs                     ; If the entire offset table hasn't been traversed, continue displaying LEDs
    
    sub.l   #36, sp
    movem.l (sp)+, LED_USED_REG
    rts    

; Mapping for numbers to be displayed. Each number has a 7 bit representation.
; A bit is 1 for corresponding LED to be on, or 0 for corresponding LED to be off.
; A byte is representing the following: x(don't care) | g | f | e | d | c | b | a
digitTable:
    dc.b    $3F, $06, $5B, $4F, $66, $6D, $7D, $07, $7F, $6F
    
; Offsets for displaying LEDs for the seven segment display    
ledDisplayOffsetTable:
    dc.b    13, 08, 46, 08          ; (xi, yi), (xf, yf) for LED A, i.e. the offsets for displaying LED A
    dc.b    52, 13, 52, 34          ; (xi, yi), (xf, yf) for LED B
    dc.b    52, 46, 52, 66          ; (xi, yi), (xf, yf) for LED C
    dc.b    13, 73, 46, 73          ; (xi, yi), (xf, yf) for LED D
    dc.b    07, 46, 07, 66          ; (xi, yi), (xf, yf) for LED E
    dc.b    07, 13, 07, 34          ; (xi, yi), (xf, yf) for LED F
    dc.b    13, 41, 46, 41          ; (xi, yi), (xf, yf) for LED G
; Temporary data used to store quotient from division operations    
tempData:    
    ds.l    1
; Stores the number of digits in a number to be displayed    
lengthOfNumber:
    ds.l    1    
;********************************************************************
























*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
