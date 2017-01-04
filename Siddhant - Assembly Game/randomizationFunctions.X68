;********************************************************************
; Subroutines for a random number generator which uses seedRandomNumber
; to seed the random number generator which is getRandomByteIntoD6 below
seedRandomNumber:
        clr.l   d6
        move.b  #TIME_SINCE_MIDNIGHT_TRAP_CODE,d0
        TRAP    #15
        
        move.l  d1,RANDOMVAL
        rts

getRandomByteIntoD6: 
        move.l  RANDOMVAL,d0
       	moveq	#$AF-$100,d1
       	moveq	#18,d2
Ninc0:	
	    add.l	d0,d0
	    bcc	    Ninc1
	    eor.b	d1,d0
Ninc1:
	    dbf	    d2,Ninc0
	    move.l	d0,RANDOMVAL
	    move.l	d0,d6
        rts
    
RANDOMVAL       ds.l    1

;********************************************************************


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
