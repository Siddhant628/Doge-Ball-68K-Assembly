*-----------------------------------------------------------
* Title      : Doge Ball
* Written by : Siddhant Grover
* Date       : 10 / 03 / 2016
* Description: A game based on dodging projectiles using arrow keys
*-----------------------------------------------------------
START    ORG    $1000

ARROW_KEYS_INPUT                    EQU     $25262728
SPACE_INPUT                         EQU     $20

GET_PLAYER_INPUT_TRAP_CODE          EQU     19
TIME_SINCE_MIDNIGHT_TRAP_CODE       EQU      8
DRAWING_MODE_TRAP_CODE              EQU     92
REPAINT_SCREEN_TRAP_CODE            EQU     94
PLAY_SOUND_TRAP_CODE                EQU     73
HALT_SIM_TRAP_CODE                  EQU      9

DEVIATION_IN_PATH                   EQU     40      ; The range of deviation a ball can have in it's path after spawnnning is 40(-20 to 20). Correspoinding deviation velocities are -1.25 and 1.25

; EXECUTION STARTS HERE
    jsr     enableDoubleBuffering
; Push the conditions for displaying the start screen onto the stack
    move.l  #0, -(sp)   
    move.l  #0, -(sp)   
    move.l  #480, -(sp)
    move.l  #640, -(sp)
    move.l  #0, -(sp)
    move.l  #0, -(sp)
    move.l  #startScreen, -(sp) 
    jsr loadImage      
    add.l   #28, sp  
; Repaint the display
    move.b  #REPAINT_SCREEN_TRAP_CODE, d0
    trap    #15
; Start the game once player presses space bar    
waitForGameStart:
    move.l  #SPACE_INPUT, d1
    move.l  #GET_PLAYER_INPUT_TRAP_CODE, d0
    trap    #15
    andi.l  #$FFFFFFFF, d1
    beq     waitForGameStart
; Loading game associated data and setting up the game
    jsr     loadBackground
    jsr     initializeVariables
    jsr     loadPlayer
    jsr     seedRandomNumber
    
gameLoop:
; Check if game should continue to run, i.e. lose condition isn't triggered
    move.b  GAME_LOST, d0
    bne     gameLoseCondition   
    jsr     estimateDeltaTime                       ; Estimate change in time since previous frame, i.e. deltaTime
    jsr     getArrowKeysInput                       ; Check for inputs from arrow keys
; Debounce player input    
    move.l  playerInput, d1
    andi.l  #$FFFFFFFF, d1
    beq     noInput                                 ; In case there is no arrow key input at all, i.e. all keys are released    
    move.b  HAVE_HAD_NO_INPUT, d0
    beq     aroundNoInput                            
    move.b  #0, HAVE_HAD_NO_INPUT                   ; Reset the flag since input is being processed
; Process player input
    jsr     setPlayerVelocity                       ; Depending on the input, sets the players velocity appropriately
    bra     aroundNoInput
noInput:
    move.b  #1, HAVE_HAD_NO_INPUT                   ; Set the flag for no inputs
    
aroundNoInput:
; Update gameplay elements which are independent of input
    jsr     updatePlayerOnDisplay                   ; If the player is moving, clear and redraw the player. Also, decelerates the player
    jsr     instantiateBall                         ; If there is no ball in play, instantiate one at a random location
    jsr     updateBallOnDisplay                     ; Clears and redraws the ball after updating it's position
; Now that the positions have been updated, collision are accounted for
    jsr     checkForCollision
; Render display
    move.b  #REPAINT_SCREEN_TRAP_CODE, d0
    trap    #15

    bra     gameLoop                                ; Repeat the game loop once the frame is rendered to display

;-------SUBROUTINE-------
enableDoubleBuffering:
    move.l  #17, d1
    move.l  #DRAWING_MODE_TRAP_CODE, d0
    trap    #15
    rts

;-------SUBROUTINE-------
loadBackground:
; Push the conditions for displaying background onto the stack
    move.l  #0, -(sp)   
    move.l  #0, -(sp)   
    move.l  #480, -(sp)
    move.l  #640, -(sp)
    move.l  #0, -(sp)
    move.l  #0, -(sp)
    move.l  #gameBackground, -(sp) 
    
    jsr loadImage                                   ; Call image rendering subroutine        
    add.l   #28, sp                                 ; Reset the stack pointer    
    rts

;-------SUBROUTINE-------
initializeVariables:
; Player spawns at the center of the display
    move.l  #208, playerPositionY                   ; Top left corner of the player such that the center of the player is at the center of display when the player is spawned
    move.l  #288, playerPositionX 
    move.l  #480, ballPositionY                     ; Moving the ball out of display initially
    move.l  #640, ballPositionX   
; Player's velocity should be 0
    move.l  #0, playerVelocityX
    move.l  #0, playerVelocityY
    move.l  #0, ballVelocityX
    move.l  #0, ballVelocityY    
; All the input booleans should be 0
    move.b  #0, UP_INPUT
    move.b  #0, DOWN_INPUT
    move.b  #0, LEFT_INPUT
    move.b  #0, RIGHT_INPUT
; Initialize time associated variables
    move.w  #0, deltaTime
    move.l  #TIME_SINCE_MIDNIGHT_TRAP_CODE, d0
    trap    #15
    move.l  d1, currentFrameTime     
; Initialize other variables
    move.b  #1, BALL_ISNT_IN_PLAY    
    move.b  #0, GAME_LOST
    move.l  #0, score
    rts    

;-------SUBROUTINE-------
loadPlayer:
    move.l  playerPositionY, -(sp)   
    move.l  playerPositionX, -(sp)   
    move.l  #64, -(sp)
    move.l  #64, -(sp)
    move.l  #0, -(sp)
    move.l  #0, -(sp)
    move.l  #playerSprite, -(sp) 

    jsr loadImage                                   ; Call image loading subroutine        
    add.l   #28, sp                                 ; Reset the stack pointer    
    rts
    
    
; Perform operations for player lose condition
gameLoseCondition:
; Clear sprites from display
    jsr     clearPlayerFromDisplay
    jsr     clearBallFromDisplay
    jsr     loadEndScreen                           ; Loads the end screen sprite
; Display score
    move.l  #13, -(sp)
    move.l  #350, -(sp)
    move.l  score, -(sp)
    jsr     displayNumberOnLEDs
    add.l   #12, sp
; Render display
    move.b  #REPAINT_SCREEN_TRAP_CODE, d0
    trap    #15
; Halt the simulator   
    move.l  #HALT_SIM_TRAP_CODE, d0
    trap    #15
;-------SUBROUTINE-------
loadEndScreen:
; Push the conditions for displaying the end game screen onto the stack
    move.l  #0, -(sp)   
    move.l  #0, -(sp)   
    move.l  #480, -(sp)
    move.l  #640, -(sp)
    move.l  #0, -(sp)
    move.l  #0, -(sp)
    move.l  #endScreen, -(sp) 
; Call the image rendering subroutine    
    jsr loadImage      
    add.l   #28, sp  
    rts
;-------SUBROUTINE-------
estimateDeltaTime:    
    move.l  currentFrameTime, d2
    move.l  #TIME_SINCE_MIDNIGHT_TRAP_CODE, d0
    trap    #15
    move.l  d1, currentFrameTime                    ; Save time for the current frame
    sub.l   d2, d1                                  ; Change in time since last frame
    move.w  d1, deltaTime
    rts

;-------SUBROUTINE-------    
getArrowKeysInput:
    move.l  #ARROW_KEYS_INPUT, d1                   ; Checking arrow keys for input
    move.l  #GET_PLAYER_INPUT_TRAP_CODE, d0
    trap    #15
    
    move.l  d1, playerInput                         ; Save the input by player 
    rts
    
;-------SUBROUTINE------- 
setPlayerVelocity:
; This method sets the players velocity and plays the jump sound (Sound subroutines are at the end of all subroutines)
; Velocities are represented using fixed point arithmetic, such that:
; 1-bit represents the sign
; 27-bits represent the magnitude
; 4-bits represent the fraction
; Speed of player is 4. Thus, 4 * (16) = 64 is the magnitude for this representation

    move.l  playerInput, d0                         ; Access player input
; Conditions for UP movement
    move.l  d0, d1
    andi.l  #$00FF0000, d1
    beq     upKeyNotPressed                         ; If up key isn't pressed, don't add velocity along -ve Y.
    move.b  #1, UP_INPUT                            ; Set the corresponding input flag
    sub.l   #64, playerVelocityY                    ; This method is only called once velocity is 0, so it essentially moving the value.
upKeyNotPressed:    
; Conditions for DOWN movement
    move.l  d0, d1
    andi.l  #$000000FF, d1
    beq     downKeyNotPressed                       ; If down key isn't pressed, don't add velocity along +ve Y.
    move.b  #1, DOWN_INPUT
    add.l  #64, playerVelocityY
downKeyNotPressed:
; Conditions for LEFT movement
    move.l  d0, d1
    andi.l  #$FF000000, d1
    beq     leftKeyNotPressed                       ; If left key isn't pressed, don't add velocity along -ve X.
    move.b  #1, LEFT_INPUT
    sub.l  #64, playerVelocityX
leftKeyNotPressed:    
; Conditions for RIGHT movement
    move.l  d0, d1
    andi.l  #$0000FF00, d1
    beq     rightKeyNotPressed                      ; If right key isn't pressed, don't add velocity along +ve X.
    move.b  #1, RIGHT_INPUT
    add.l  #64, playerVelocityX
rightKeyNotPressed:    
    jsr     playJumpSound                           
    rts
;-------SUBROUTINE-------    
updatePlayerOnDisplay:
; If player has any speed, clear and redraw the player at updated position.
    move.l  playerVelocityX, d0
    or.l    playerVelocityY, d0
    beq     noChangeInPlayerPosition                ; If player isn't moving, skip updating player
    
    jsr     clearPlayerFromDisplay                  ; Removes the previously rendered player position
    jsr     updatePlayerVelocity                    ; Decelerates the player to mimic jumping action
    jsr     updatePlayerPosition                    ; Updates the players position based on current speed of player    
    jsr     loadPlayer                              ; Renders player at the updated position
    
noChangeInPlayerPosition:
    jsr     checkPlayerPosition                     ; Check if the player left the play area, if so, set lose condition boolean
    rts
;-------SUBROUTINE-------    
clearPlayerFromDisplay:
; Clears the player by redrawing a chunk of background over the player
    move.l  playerPositionY, -(sp)                  ; Y-Position on output display
    move.l  playerPositionX, -(sp)                  ; X-Position on output display
    move.l  #64, -(sp)                              ; Height to display
    move.l  #64, -(sp)                              ; Width to display
    move.l  playerPositionY, -(sp)                  ; Y-Position in source image
    move.l  playerPositionX, -(sp)                  ; X-Position in source image
    move.l  #gameBackground, -(sp)                  ; Pointer to game background

    jsr loadImage                                   ; Call image loading subroutine        
    add.l   #28, sp                                 ; Reset the stack pointer    
    rts

;-------SUBROUTINE------- 
updatePlayerVelocity:
; Deceleration is 0.125
; In fixed point arithmetic with 4 fractional bits, deceleration is:
; 0.125 * (16) = 2

; Reduce velocity if the player is moving upwards, i.e, if the initial input for the jump was upwards.    
    move.b  UP_INPUT, d0
    beq     noChangeInUpVelocity                ; If there is no up key input, continue with block
    move.l  playerVelocityY, d0
    beq     noChangeInUpVelocity                ; If velocity along Y is 0, then skip deceleration
    cmpi.l  #$FFFFFFFF, d0
    bgt     resetPlayerVelocityY                ; If velocity along Y is greater than -1, then reset it to 0
    move.l  #2, d1                              ; deceleration is 2 in fixed point arithmetic
    muls.w  deltaTime, d1                       ; deceleration * time = change in velocity
    add.l   d1, playerVelocityY                 ; Final velocity is stored
noChangeInUpVelocity:
; Reduce velocity if the player is moving downwards.    
    move.b  DOWN_INPUT, d0
    beq     noChangeInDownVelocity
    move.l  playerVelocityY, d0
    beq     noChangeInDownVelocity
    cmpi.l  #1, d0
    blt     resetPlayerVelocityY                ; This is done to ensure that the player's direction of motion doesn't change
    move.l  #2, d1
    muls.w  deltaTime, d1
    sub.l   d1, playerVelocityY
noChangeInDownVelocity:    
; Increase velocity if the player is moving leftwards.    
    move.b  LEFT_INPUT, d0
    beq     noChangeInLeftVelocity
    move.l  playerVelocityX, d0
    beq     noChangeInLeftVelocity
    cmpi.l  #$FFFFFFFF, d0
    bgt     resetPlayerVelocityX
    move.l  #2, d1
    muls.w  deltaTime, d1
    add.l   d1, playerVelocityX
noChangeInLeftVelocity:  
; Decrease velocity if the player is moving rightwards.    
    move.b  RIGHT_INPUT, d0
    beq     noChangeInRightVelocity
    move.l  playerVelocityX, d0
    beq     noChangeInRightVelocity
    cmpi.l  #1, d0
    blt     resetPlayerVelocityX                
    move.l  #2, d1
    muls.w  deltaTime, d1
    sub.l   d1, playerVelocityX
noChangeInRightVelocity:    
; Check if speed is 0
    move.l  playerVelocityX, d0                      
    move.l  playerVelocityY, d1
    or.l    d1, d0
    beq     resetInputBooleans                  ; At end of jump, i.e speed is 0, reset input booleans
; This reset is done to ensure that the player can't provide input unless a jump is complete, i.e. the speed is 0
    move.b  #0, HAVE_HAD_NO_INPUT
    rts

resetPlayerVelocityX:
    move.l  #0, playerVelocityX
    bra     updatePlayerVelocity
    
resetPlayerVelocityY:
    move.l  #0, playerVelocityY
    bra     updatePlayerVelocity  
  
;-------SUBROUTINE------- 
updatePlayerPosition:
    move.l  playerVelocityX, d0
    muls.w  deltaTime, d0
    asr.l   #4, d0                                  ; Since the velocity term has 4 fractional bits, we divide by 16
    add.l   d0, playerPositionX
    move.l  playerVelocityY, d0
    muls.w  deltaTime, d0
    asr.l   #4, d0                                  ; Since the velocity term has 4 fractional bits, we divide by 16
    add.l   d0, playerPositionY
    rts
    
;-------SUBROUTINE------- 
checkPlayerPosition:
    cmpi.l  #$FFFFFFFD, playerPositionX         ; Condition for player to touch the left edge -4 (0 - 4)
    blt     playerOutOfDisplay
    cmpi.l  #579, playerPositionX               ; Condition for player to touch the right edge 580 (640 - 60)
    bgt     playerOutOfDisplay
    cmpi.l  #$FFFFFFF9, playerPositionY         ; Condition for player to touch the top edge 8 (0 - 8)
    blt     playerOutOfDisplay
    cmpi.l  #415, playerPositionY               ; Condition for player to touch bottom edge 416(480 - 64)
    bgt     playerOutOfDisplay
    rts

;-------SUBROUTINE-------     
playerOutOfDisplay:
    move.b  #1, GAME_LOST
    rts   

    
;-------SUBROUTINE------- 
instantiateBall:
    move.b  BALL_ISNT_IN_PLAY, d0
    beq     skipInstantiatingBall
    jsr     initializeBallData                         ; Resets the position of the ball to a position randomly at the borders of the display
    jsr     setBallVelocity                            ; Based on instantiation, sets the velocity of the ball so that it enters the display  
    jsr     playBallSound                              ; Subroutine for playing ball sound is near the end of code
skipInstantiatingBall:  
    rts
    
;-------SUBROUTINE-------     
initializeBallData:
; Resetting variables before instantiating the ball
    move.l  #0, ballVelocityX                           ; Reset the ball's velocity            
    move.l  #0, ballVelocityY
    move.b  #0, BALL_ISNT_IN_PLAY                       ; Reset the boolean so that the ball is in play, ensures only one ball is spawned at a time
; Randomly acquire the axis through which the ball must be generated 
    jsr     getRandomByteIntoD6
    andi.l  #$000000FF, d6
    cmpi.l  #64, d6 
    blt     ballSpawnsFromBot
    cmpi.l  #124, d6
    blt     ballSpawnsFromLeft
    cmpi.l  #192, d6
    blt     ballSpawnsFromRight
; Spawn the ball for various directions
ballSpawnsFromTop:
    move.b  #1, ballSpawnDirection
    jsr     getRandomByteIntoD6
    andi.l  #$000000FF, d6                      
    mulu.w  #588, d6                            ; We want the range of display of 588 pixels, so we multiply by 588
    asr.l   #8, d6                              ; Divide by 256 to get a random number ranging from 0-588
    add.l   #10, d6                             
    move.l  d6, ballPositionX                   ; Ball would be displayed along X in between 10 and 630(598+32) pixels
    move.l  #$FFFFFFE0, ballPositionY           ; Setting position along Y to -32, ensures that the ball is out of display
    rts
ballSpawnsFromBot:
    move.b  #2, ballSpawnDirection
    jsr     getRandomByteIntoD6
    andi.l  #$000000FF, d6                      
    mulu.w  #588, d6                            ; We want the range of display of 588 pixels, so we multiply by 588
    asr.l   #8, d6                              ; Divide by 256 to get a random number ranging from 0-588
    add.l   #10, d6                             
    move.l  d6, ballPositionX                   ; Ball would be displayed along X in between 10 and 630(598+32) pixels
    move.l  #480, ballPositionY                 ; Ensures that the ball is out of display initially
    rts
ballSpawnsFromLeft:    
    move.b  #3, ballSpawnDirection
    jsr     getRandomByteIntoD6
    andi.l  #$000000FF, d6                      ; To ensure that the random value ranges upto 255.
    mulu.w  #428, d6                            ; We want the range of display of 428 pixels, so we multiply by 428
    asr.l   #8, d6                              ; Divide by 256 to get a random number ranging from 0-428
    add.l   #10, d6                             ; Get a random number ranging from 10-438
    move.l  d6, ballPositionY                   ; Ball would be displayed along Y in between 10 and 470(438+32) pixels
    move.l  #0, ballPositionX                   
    sub.l   #32, ballPositionX                  ; Ensures that the ball is out of display initially
    rts
ballSpawnsFromRight:
    move.b  #4, ballSpawnDirection
    jsr     getRandomByteIntoD6
    andi.l  #$000000FF, d6                      ; To ensure that the random value ranges upto 255
    mulu.w  #428, d6                            ; We want the range of display of 428 pixels
    asr.l   #8, d6                              
    add.l   #10, d6                             ; Get a random number ranging from 10-438
    move.l  d6, ballPositionY                   ; Ball would be displayed along Y in between 10 and 470(438+32) pixels
    move.l  #672, ballPositionX                 ; 672(640+32) ensures that the ball is out of display initially
    rts
    
;-------SUBROUTINE-------     
setBallVelocity:
; Check the spawn direction of the ball, so that velocity may be set as per the spawn position
    cmpi.b  #1, ballSpawnDirection
    beq     ballVelocityTop    
    cmpi.b  #2, ballSpawnDirection
    beq     ballVelocityBot
    cmpi.b  #3, ballSpawnDirection
    beq     ballVelocityLeft
    cmpi.b  #4, ballSpawnDirection
    beq     ballVelocityRight
    rts
; The balls velocity is 5 if spawnned along vertical, else, it is 5.5. For this we'll use fixed point arithmetic such that
; 1-bit represents the sign
; 27-bits represent the magnitude
; 4-bits represent the fraction
; Thus, speed is 5 * (16) = 80 or  5.5 * (16) = 88
 
ballVelocityTop:    
    add.l   #80, ballVelocityY
    ;jsr     deviateBallPathX
    rts
    
ballVelocityBot:
    sub.l   #80, ballVelocityY
    ;jsr     deviateBallPathX
    rts
    
ballVelocityLeft:
    add.l   #88, ballVelocityX
    ;jsr     deviateBallPathY
    rts    
     
ballVelocityRight:
    sub.l   #88, ballVelocityX
    ;jsr     deviateBallPathY
    rts        
   
deviateBallPathX:
; Load d6 with a random number in the deviation range
    jsr     getRandomByteIntoD6
    andi.l  #$000000FF, d6
    mulu.w  #DEVIATION_IN_PATH, d6                  
    lsr.l   #8, d6
; Subtracting with half to get the deviation along both directions    
    sub.l   #DEVIATION_IN_PATH>>1, d6               
; Add the deviation magnitude along X
    add.l   d6, ballVelocityX
    rts
 
deviateBallPathY:
; Load d6 with a random number in the deviation range
    jsr     getRandomByteIntoD6
    andi.l  #$000000FF, d6
    mulu.w  #DEVIATION_IN_PATH, d6                  
    lsr.l   #8, d6 
; Subtracting with half to get the deviation along both directions                                 
    sub.l   #DEVIATION_IN_PATH>>1, d6               
; Add the deviation magnitude along Y
    add.l   d6, ballVelocityY
    rts

    
;-------SUBROUTINE------- 
updateBallOnDisplay:
    jsr     clearBallFromDisplay                    ; Removes the previously rendered ball from display
    jsr     updateBallPosition                      ; Updates the position of the ball based on its velocity
    jsr     checkIfBallIsInPlay                     ; Sets a boolean if there is no ball in play
    jsr     loadBall                                ; Renders the ball at the updated position
    rts    
   
;-------SUBROUTINE-------     
clearBallFromDisplay:
    move.l  ballPositionY, -(sp)                    ; Y-Position on output display
    move.l  ballPositionX, -(sp)                    ; X-Position on output display
    move.l  #32, -(sp)                              ; Height to display
    move.l  #32, -(sp)                              ; Width to display
    move.l  ballPositionY, -(sp)                    ; T-Position in source image
    move.l  ballPositionX, -(sp)                    ; X-Position in source image
    move.l  #gameBackground, -(sp)                  ; Pointer to game background

    jsr loadImage                                   ; Call image loading subroutine        
    add.l   #28, sp                                 ; Reset the stack pointer    
    rts

;-------SUBROUTINE-------     
updateBallPosition:
    move.l  ballVelocityX, d0
    muls.w  deltaTime, d0                               ; distance = velocity X time
    asr.l   #4, d0                                      ; Since the velocity term has 4 fractional bits, we divide by 16
    add.l   d0, ballPositionX
    move.l  ballVelocityY, d0
    muls.w  deltaTime, d0                               
    asr.l   #4, d0                                      
    add.l   d0, ballPositionY
    rts
    
;-------SUBROUTINE-------     
checkIfBallIsInPlay:    
; Check if updating ball's position took it out of play area
    cmpi.b  #1, ballSpawnDirection
    beq     ballOutForTopSpawn                      ; If ball spawned from top, preform check for ball exiting from bottom
    cmpi.b  #2, ballSpawnDirection
    beq     ballOutForBotSpawn                      ; If ball spawned from bot, preform check for ball exiting from top
    cmpi.b  #3, ballSpawnDirection
    beq     ballOutForLeftSpawn                     ; If ball spawned from left, preform check for ball exiting from right
    cmpi.b  #4, ballSpawnDirection
    beq     ballOutForRightSpawn                    ; If ball spawned from right, preform check for ball exiting from left
     
ballOutForTopSpawn:    
    cmpi.l  #480, ballPositionY
    blt     ContinuePlayWithCurrentBall             ; If y > 480, ball is out of play
    move.b  #1, BALL_ISNT_IN_PLAY                   ; Set boolean for ball out of play
    add.l   #1, score                               ; Increment the score
    rts
ballOutForBotSpawn:
    cmpi.l  #$FFFFFFE0, ballPositionY
    bgt     ContinuePlayWithCurrentBall             ; If y < -32, ball is out of play
    move.b  #1, BALL_ISNT_IN_PLAY                   ; Set boolean for ball out of play
    add.l   #1, score                               ; Increment the score
    rts
ballOutForLeftSpawn:
    cmpi.l  #640, ballPositionX
    blt     ContinuePlayWithCurrentBall             ; If x > 640, ball is out of play
    move.b  #1, BALL_ISNT_IN_PLAY                   ; Set boolean for ball out of play
    add.l   #1, score                               ; Increment the score
    rts
ballOutForRightSpawn:
    cmpi.l  #$FFFFFFE0, ballPositionX               
    bgt     ContinuePlayWithCurrentBall             ; If x < -32, ball is out of play
    move.b  #1, BALL_ISNT_IN_PLAY                   ; Set boolean for ball out of play
    add.l   #1, score                               ; Increment the score
    rts
continuePlayWithCurrentBall:    
    rts  

;-------SUBROUTINE-------   
loadBall:
    move.l  ballPositionY, -(sp)                    ; Y-Position on output display
    move.l  ballPositionX, -(sp)                    ; X-Position on output display
    move.l  #32, -(sp)                              ; Height to display
    move.l  #32, -(sp)                              ; Width to display
    move.l  #0, -(sp)                               ; Y-Position in source image
    move.l  #0, -(sp)                               ; X-Position in source image
    move.l  #ballSprite, -(sp)                      ; Pointer to ball sprite

    jsr loadImage                                   ; Call image loading subroutine        
    add.l   #28, sp                                 ; Reset the stack pointer    
    rts    

;-------SUBROUTINE------- 
checkForCollision:
; Load the coordinates of the top left corners of both the sprites in d0...d4
    move.l  playerPositionX, d0
    move.l  playerPositionY, d1
    move.l  ballPositionX, d2
    move.l  ballPositionY, d3
; Estimate the centers of both the sprites
    add.l   #32, d0                                 ; There are 4 pixels to the left of player and the radius of the player is 28 pixels, thus 32 pixels is the offset along X
    add.l   #36, d1                                 ; There are approximately 8 pixels above the player and the radius of the player is 28 pixels, thus 36 pixels is the offset along Y      
    add.l   #16, d2                                 ; The radius of the ball is 16 pixels, thus the offset along X for ball is 16
    add.l   #16, d3                                 ; The radius of the ball is 16 pixels, thus the offset along Y for ball is 16
; Estimate the realtive positions of the two sprites, i.e. (x1-x2) and (y1-y2)
    sub.l   d0,d2                                   ; d2 = Xball - Xplayer
    sub.l   d1,d3                                   ; d3 = YBall - YPlayer
; Perform a check if collision testing is required
    cmpi.l  #0, d2
    bgt     xDifferenceIsPositive                   ; If the difference isn't positive, negate the number
    neg     d2                                      
xDifferenceIsPositive:
    cmpi.l  #0, d3                                  
    bgt     yDifferenceIsPositive                   ; If the difference isn't positive, negate the number
    neg     d3
yDifferenceIsPositive:
; The sum of the radii is 44 (16 + 28), if the distance along an axis is more than 44, it means that there won't be any collision
    cmpi.l  #44, d2
    bgt     noCollisionCheckRequired
    cmpi.l  #44, d3
    bgt     noCollisionCheckRequired
; Perform check for collision
; The distance between the two for collision must meet the condition [(Xball - Xplayer)^2 + (YBall - YPlayer)^2] < (r1 + r2)^2
    muls.w  d2, d2
    muls.w  d3, d3
    add.l   d2, d3
    move.l  #44, d2
    muls.w  d2, d2
    cmp.l   d2, d3
    bgt     noCollisionCheckRequired                ; If there is no collision, don't set the boolean for lose condition
    move.b  #1, GAME_LOST
noCollisionCheckRequired:   
    rts    
    
;-------SUBROUTINE------- 
; Once players movement for a jump is complelte, new input is enabled by calling this subroutine
resetInputBooleans:
    move.b  #0, UP_INPUT
    move.b  #0, DOWN_INPUT
    move.b  #0, LEFT_INPUT
    move.b  #0, RIGHT_INPUT       
    rts
;-------SUBROUTINE------- 
playBallSound:
    move.l  #ballSound, a1
    move.l  #PLAY_SOUND_TRAP_CODE, d0
    trap    #15
    rts
    
;-------SUBROUTINE-------     
playJumpSound:
    move.l  #jumpSound, a1
    move.l  #PLAY_SOUND_TRAP_CODE, d0
    trap    #15
    rts    
    
    INCLUDE "bmpLoader.x68"                         ; A subroutine for rendering sprites on display
    INCLUDE "randomizationFunctions.x68"            ; A subroutine for random number generation
    INCLUDE "ledDisplaySubroutine.x68"
    
gameBackground:
    INCBIN "grassBackground.bmp"
playerSprite:
    INCBIN  "doge64x64.bmp"    
ballSprite:
    INCBIN  "ball32x32.bmp"  
endScreen:
    INCBIN  "endGameScreen.bmp"  
startScreen:
    INCBIN  "startGameScreen.bmp"
 
; Saves the input from the user for future use
playerInput:
    ds.l    1
; Variables to store the top left corner from where the player is displayed
playerPositionX:
    ds.l    1
playerPositionY:
    ds.l    1    
; Variables to store the velocity of the player
playerVelocityX:
    ds.l    1
playerVelocityY:
    ds.l    1
; Variables to store the top left corner from where the ball is displayed  
ballPositionX:
    ds.l    1
ballPositionY:
    ds.l    1    
; Variables to store the velocity of the ball    
ballVelocityX:
    ds.l    1
ballVelocityY:
    ds.l    1 
; The score of the player for the current game
score:
    ds.l    1     
; Amount of time taken to execute the previous frame
deltaTime:
    ds.w    1
; The time at which the current frame started executing
currentFrameTime:
    ds.l    1
ballSpawnDirection:
    ds.b    1                       ; Indicates direction of ball spawn for values 1 (top), 2 (bot), 3 (left), 4 (right)    
ballSound:
    dc.b    'nebelwerferSound.wav', 0     
jumpSound:
    dc.b    'jump.wav', 0    

HAVE_HAD_NO_INPUT   ds.b    1       ; Boolean to check if there has been an instance where there was no user input
UP_INPUT            ds.b    1       ; Boolean to check if the up arrow key was pressed
DOWN_INPUT          ds.b    1       ; Boolean to check if the down arrow key was pressed
LEFT_INPUT          ds.b    1       ; Boolean to check if the left arrow key was pressed
RIGHT_INPUT         ds.b    1       ; Boolean to check if the right arrow key was pressed
BALL_ISNT_IN_PLAY   ds.b    1       ; Boolean to check if the ball is out of the screen area
GAME_LOST           ds.b    1       ; Boolean to check if the game was lost

    END    START












*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
