;==============================================================
; MODULE M3 : 50_rules.asm   (Member C - TAYAS : Rules)
; Procedures: SEEDRANDOM, RANDOM, RANDOMRANGE, GENERATEFOOD,
;             CHECKCOLLISION, APPLYFOOD, UPDATESCORE,
;             UPDATELEVEL, LOSELIFE, APPLYDIFFICULTY
;
; Uses (defined in 10_data.asm / 00_header.asm):
;   RandSeed, FoodX, FoodY, FoodColor, SpeedQ, FoodsInLevel,
;   ScoreValue, HighScore, LevelValue, LivesValue,
;   SnakeX, SnakeY, SnakeLen, NewX, NewY
; Calls other modules: GROWSNAKE (B), DRAWFOOD (A)
; Label prefixes used here: GF_  CC_  US_  UL_  LL_  AD_
;==============================================================

;--------------------------------------------------------------
; SEEDRANDOM
; Purpose : set RandSeed from the BIOS clock so every run differs
; IN      : none
; OUT     : RandSeed
; Changes : flags (AX, CX, DX saved)
;--------------------------------------------------------------
SEEDRANDOM PROC
    PUSH AX
    PUSH CX
    PUSH DX

    MOV AH, 00H             ; INT 1Ah / 00h : CX:DX = BIOS tick count
    INT 1AH
    XOR DX, CX              ; mix high and low halves of the clock
    MOV RandSeed, DX        ; store as the starting seed

    POP DX
    POP CX
    POP AX
    RET
SEEDRANDOM ENDP


;--------------------------------------------------------------
; RANDOM
; Purpose : next pseudo-random number (LCG)
;           seed = seed * 25173 + 13849   (mod 65536)
; IN      : none
; OUT     : AX = new seed
; Changes : flags, AX
;--------------------------------------------------------------
RANDOM PROC
    PUSH DX

    MOV AX, RandSeed        ; AX = old seed
    MOV DX, 25173           ; multiplier
    MUL DX                  ; DX:AX = AX * 25173 (we keep only AX)
    ADD AX, 13849           ; add the increment
    MOV RandSeed, AX        ; save the new seed for next call

    POP DX
    RET
RANDOM ENDP


;--------------------------------------------------------------
; RANDOMRANGE
; Purpose : random number from 0 to N-1
; IN      : CX = N (1..255)
; OUT     : DX = 0..N-1
; Changes : flags, DX (AX saved)
;--------------------------------------------------------------
RANDOMRANGE PROC
    PUSH AX

    CALL RANDOM             ; AX = random 16-bit value
    MOV AL, AH              ; use the HIGH byte (low bit alternates)
    XOR AH, AH              ; AX = 0..255
    XOR DX, DX              ; DIV uses DX:AX, so DX must be 0
    DIV CX                  ; AX = quotient, DX = remainder (0..N-1)

    POP AX
    RET
RANDOMRANGE ENDP


;--------------------------------------------------------------
; GENERATEFOOD
; Purpose : choose a random free cell for the food
; IN      : none
; OUT     : FoodX, FoodY, FoodColor
; Changes : flags (AX, CX, DX, SI saved)
;--------------------------------------------------------------
GENERATEFOOD PROC
    PUSH AX
    PUSH CX
    PUSH DX
    PUSH SI

GF_TRY:
    MOV CX, 38              ; columns 1..38 -> 38 choices
    CALL RANDOMRANGE        ; DX = 0..37
    ADD DL, FIELD_MIN_COL   ; shift into 1..38
    MOV AL, DL              ; AL = candidate column

    MOV CX, 20              ; rows 4..23 -> 20 choices
    CALL RANDOMRANGE        ; DX = 0..19
    ADD DL, FIELD_MIN_ROW   ; shift into 4..23
    MOV AH, DL              ; AH = candidate row

    XOR CH, CH
    MOV CL, SnakeLen        ; CX = number of snake segments
    XOR SI, SI              ; start at segment 0 (head)
GF_CHECK:
    CMP AL, SnakeX[SI]      ; same column as this segment?
    JNE GF_NEXT
    CMP AH, SnakeY[SI]      ; same row too?
    JE GF_TRY               ; yes: food would be on the snake, retry
GF_NEXT:
    INC SI                  ; next segment
    LOOP GF_CHECK

    MOV FoodX, AL           ; cell is free: save it
    MOV FoodY, AH
    MOV FoodColor, CLR_FOOD ; normal food colour

    POP SI
    POP DX
    POP CX
    POP AX
    RET
GENERATEFOOD ENDP


;--------------------------------------------------------------
; CHECKCOLLISION
; Purpose : is the cell (NewX, NewY) deadly?
;           Wall, or any snake segment (tail included).
; IN      : NewX, NewY (set by MOVESNAKE, snake NOT yet shifted)
; OUT     : AL = 1 if deadly, 0 if safe
; Changes : flags, AL (BX, CX, SI saved)
;--------------------------------------------------------------
CHECKCOLLISION PROC
    PUSH BX
    PUSH CX
    PUSH SI

    MOV BL, NewX            ; BL = column to test
    MOV BH, NewY            ; BH = row to test

    CMP BL, FIELD_MIN_COL   ; --- wall tests (unsigned) ---
    JB CC_HIT               ; left of the field (0FFh also lands here)
    CMP BL, FIELD_MAX_COL
    JA CC_HIT               ; right of the field
    CMP BH, FIELD_MIN_ROW
    JB CC_HIT               ; above the field
    CMP BH, FIELD_MAX_ROW
    JA CC_HIT               ; below the field

    XOR CH, CH              ; --- self test ---
    MOV CL, SnakeLen        ; CX = number of segments
    XOR SI, SI              ; start at the head
CC_LOOP:
    CMP BL, SnakeX[SI]
    JNE CC_NEXT
    CMP BH, SnakeY[SI]
    JE CC_HIT               ; same cell as a body part
CC_NEXT:
    INC SI
    LOOP CC_LOOP

    MOV AL, 0               ; nothing hit
    JMP CC_DONE
CC_HIT:
    MOV AL, 1               ; deadly cell
CC_DONE:
    POP SI
    POP CX
    POP BX
    RET
CHECKCOLLISION ENDP


;--------------------------------------------------------------
; APPLYFOOD
; Purpose : everything that happens when the snake eats food
; IN      : none (called by MOVESNAKE after the head is on the food)
; OUT     : score, snake length, level, new food updated
; Changes : flags (AX, BX saved)
;--------------------------------------------------------------
APPLYFOOD PROC
    PUSH AX
    PUSH BX

    MOV AX, PTS_NORMAL      ; points for this food
    CALL UPDATESCORE        ; add to score, check high score
    CALL GROWSNAKE          ; (B) snake gets one segment longer
    INC FoodsInLevel        ; one more food eaten this level
    CALL UPDATELEVEL        ; level up every FOODS_PER_LEVEL
    CALL GENERATEFOOD       ; new food, after growing so not on snake

    MOV AL, FoodX           ; draw the new food
    MOV AH, FoodY
    MOV BL, FoodColor
    CALL DRAWFOOD           ; (A)

    POP BX
    POP AX
    RET
APPLYFOOD ENDP


;--------------------------------------------------------------
; UPDATESCORE
; Purpose : ScoreValue += AX, keep HighScore up to date
; IN      : AX = points
; OUT     : ScoreValue, HighScore
; Changes : flags (AX saved)
;--------------------------------------------------------------
UPDATESCORE PROC
    PUSH AX

    ADD ScoreValue, AX      ; add the points
    JNC US_CHECK            ; no carry: still fits in 16 bits
    MOV ScoreValue, 0FFFFH  ; overflow: cap at 65535
US_CHECK:
    MOV AX, ScoreValue
    CMP AX, HighScore
    JBE US_DONE             ; not higher: leave HighScore alone
    MOV HighScore, AX       ; new record
US_DONE:
    POP AX
    RET
UPDATESCORE ENDP


;--------------------------------------------------------------
; UPDATELEVEL
; Purpose : after FOODS_PER_LEVEL foods, level + 1 and faster
; IN      : FoodsInLevel
; OUT     : FoodsInLevel, LevelValue, SpeedQ
; Changes : flags
;--------------------------------------------------------------
UPDATELEVEL PROC
    CMP FoodsInLevel, FOODS_PER_LEVEL
    JB UL_DONE              ; not enough foods yet
    MOV FoodsInLevel, 0     ; start counting again
    INC LevelValue          ; next level (word variable)
    CMP SpeedQ, SPEEDQ_MIN
    JBE UL_DONE             ; already at the fastest speed
    DEC SpeedQ              ; smaller SpeedQ = shorter wait = faster
UL_DONE:
    RET
UPDATELEVEL ENDP


;--------------------------------------------------------------
; LOSELIFE
; Purpose : take one life away (never below 0)
; IN      : LivesValue
; OUT     : LivesValue
; Changes : flags
;--------------------------------------------------------------
LOSELIFE PROC
    CMP LivesValue, 0
    JE LL_DONE              ; already 0: do nothing
    DEC LivesValue
LL_DONE:
    RET
LOSELIFE ENDP


;--------------------------------------------------------------
; APPLYDIFFICULTY
; Purpose : set the starting speed from the chosen difficulty
; IN      : AL = 1 (easy), 2 (normal), 3 (hard)
; OUT     : SpeedQ
; Changes : flags
;--------------------------------------------------------------
APPLYDIFFICULTY PROC
    CMP AL, 1
    JE AD_EASY
    CMP AL, 3
    JE AD_HARD
    MOV SpeedQ, SPEEDQ_NORMAL   ; 2 (or anything unexpected)
    RET
AD_EASY:
    MOV SpeedQ, SPEEDQ_EASY
    RET
AD_HARD:
    MOV SpeedQ, SPEEDQ_HARD
    RET
APPLYDIFFICULTY ENDP

