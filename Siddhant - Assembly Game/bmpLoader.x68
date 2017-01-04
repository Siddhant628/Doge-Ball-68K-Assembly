;********************************************************************
; A SUBROUTINE to display a chunk of an image at a specific position

PEN_COLOR_TRAP_CODE                     EQU     80
DRAW_PIXEL_TRAP_CODE                    EQU     82
IMAGE_USED_REG                          REG     D0/D1/D2/D4/D5/D6/D7/A1/A2/A6     

SOURCE_IMAGE_LOC_S      EQU     4
; X position of the top left corner of the chunk of image
X_SOURCE_S              EQU     8
; Y position of the top left corner of the chunk of image
Y_SOURCE_S              EQU     12
; The width of chunk to be copied 
WIDTH_S                 EQU     16
; The height of chunk to be copied
HEIGHT_S                EQU     20
; The X position on display where the image should be copied  
X_DESTINATION_S         EQU     24
; The Y position on display where the image should be copied
Y_DESTINATION_S         EQU     28
; Push the pointer to the image address in memory
; Push above on stack in reverse order


loadImage:
; Save the current contents of registers
        movem.l IMAGE_USED_REG, -(sp)
        add.l  #40, sp                                          ; Offset to access the values on the stack which were pushed for the subroutine
; Load the address of the pixel table location in pixelArray
        move.l  SOURCE_IMAGE_LOC_S(sp), a6        
        add.l   #10, a6                                         ; a6 now points to location with pixel array offset     
        move.l  (a6), d0                                        ; Load the value of pixel array offset to register
        jsr     littleToBig                                     ; d0 now contains the offset in big endian format
        move.l  SOURCE_IMAGE_LOC_S(sp), d5
        add.l   d5, d0                                          ; Adding offset to location of the image gives location of pixel table
        move.l  d0, pixelArray                                  ; Save the location of pixel table
; Load the address of the color table location in colorArray
        move.l  SOURCE_IMAGE_LOC_S(sp), a1        
        add.l   #14, a1                                         ; a1 now points to location with color table offset from a1
        move.l  (a1), d0                                        ; Load the value of color table offset(from a1) to register
        jsr     littleToBig                                     ; Convert the offset to the color table to big endian
        add.l   a1, d0                                          ; Calculate the position of the color table in memory
        move.l  d0, colorArray                                  ; Save the location of color table
; Load source image width and height
        move.l  SOURCE_IMAGE_LOC_S(sp), a1
        add.l   #18, a1                                         ; Offset for width in header
        move.l  (a1), d0
        jsr     littleToBig
        move.l  d0, imageWidth                                  ; Save source image width
           
        move.l  SOURCE_IMAGE_LOC_S(sp), a1
        add.l   #22, a1                                         ; Offset for height in header
        move.l  (a1), d0
        jsr     littleToBig
        move.l  d0, imageHeight                                 ; Save source image height 
; Estimate the number of bytes used for padding
        move.l  imageWidth, d0
        divu.w  #4, d0  
        swap.w  d0                                              ; Move the remainder to lower word
        clr.l   d1
        move.w  d0, d1                                          ; Move the remainder to cleared register
        move.l  #4, d0
        sub.l   d1, d0                                          ; Estimate the padding count, i.e the number of extra bytes in each row of the image
        move.l  d0, paddingCount
        
        cmpi.l  #4, paddingCount                                ; In case the remainder is 0, i.e. the factor is 4, there is no padding
        beq     resetPadding                                    ; Set the padding count to 0
afterPadding:
; Print the color on display
        move.l  WIDTH_S(sp) , d6
        move.l  HEIGHT_S(sp), d7
        
; Accout for pixels to skip before printing
        move.l  pixelArray, a1                                  ; a1 will be used to refer to pixel table in display loop
        move.l  imageHeight, d0
        sub.l   HEIGHT_S(sp), d0
        sub.l   Y_SOURCE_S(sp), d0                              ; d0 contains the number of rows to be skipped from the bottom of the image while displaying
        move.l  imageWidth, d1
        add.l   paddingCount, d1                                ; d1 contains the number of pixels to be skipped for each row of pixels 
        mulu.w  d1, d0                                          ; d0 contains all the pixels skipped in rows below the chunk
        
        add.l   X_SOURCE_S(sp), d0                              ; Account for the skipped pixels along the first row which will be printed 
        add.l  d0, a1                                           ; a1 contains the effective location of the first pixel to print        
        
        move.l  colorArray, a2                                  ; a2 will be used to refer to color table in display loop       
; Load postions from where drawing will start
        move.l  X_DESTINATION_S(sp), d1         
        move.l  Y_DESTINATION_S(sp), d2         
        add.l  HEIGHT_S(sp), d2                                 ; Since pixel table is has bottom most row first, we print from bottom row, left to right

printingOnDisplay:
; Change pen color
        move.l  d1, d4                                          ; Save the x position for next pixel to display at d4
        clr     d1
        move.b  (a1)+, d1                                       ; Move the value in pixel table to d0
        mulu    #4, d1                                          ; Each value in pixel table takes 4 bytes, so calcuate the relative position using the index value 
        add.l   colorArray, d1                                  ; d1 contains the location with color information
        move.l  d1, a2          
        move.l  (a2), d1                                        ; Load color value for pixel into d1
        ror.l   #8, d1                                          ; Rotate the contents of color to get it in the 0x00BBGGRR format
; Check for pixel that should be skipped       
        cmpi.l   #$00FFFFFF, d1
        beq     pixelSkipped                                    ; If pixel is white, skip drawing of pixel
        
        move.l  #PEN_COLOR_TRAP_CODE, d0
        trap    #15                                             ; Set pen color
        
; Print on display
        move.l  d4, d1                                          ; Retrieve x postion to display pixel
        move.l  #DRAW_PIXEL_TRAP_CODE, d0
        trap    #15                                             ; Draw a pixel
pixelSkipped:
        move.l  d4, d1       
        addi.l  #1, d1                                          ; Increment the position along the width to display pixels
        
        
        move.l  WIDTH_S(sp), d6
        add.l   X_DESTINATION_S(sp), d6                         ; End of the displayed row is at X_DESTINATION + WIDTH
 
        
        cmp.l   d1, d6                                          ; Check if the entire row has been displayed
        bne     printingOnDisplay                               
         
        add.l   imageWidth, a1                                  
        sub.l   WIDTH_S(sp), a1                                 ; Skip pixels as much as the difference between source image width and the width of the chunk
        add.l   paddingCount, a1                                ; Account for padding in current row and skip those padding bytes

        move.l  X_DESTINATION_S(sp), d1                         ; Reset the row for displaying at the left most position
        subi.l  #1, d2                                          ; Decrement the position along the vertical to display 
        cmp.l   Y_DESTINATION_S(sp), d2                         ; Check if all the rows have been printed
        bne     printingOnDisplay
        
        sub.l  #40, sp
        movem.l (sp)+, IMAGE_USED_REG
               
        rts   
; Used to reset the padding count in case the reaminder from division is 0
resetPadding:
        move.l  #0, paddingCount
        bra     afterPadding
     
; A subroutine to convert the long word at d0 from little endian to big endian
littleToBig:
        ror.w   #8, d0                                          ; Swap the upper two bytes
        swap.w  d0                                              ; Swap the upper and lower words
        ror.w   #8, d0                                          ; Swap the lower two bytes
        rts


; Stores the address from where the pixel table starts   
pixelArray:
        ds.l    1
; Stores the address from where the color table starts        
colorArray:
        ds.l    1
; Stores the width of the source image being rendered
imageWidth:
        ds.l    1
; Stores the height of the source image being rendered        
imageHeight:
        ds.l    1
; Stores the number of bytes used for padding the pixel array        
paddingCount:
        ds.l    1

;*********************************************************************




*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~8~
