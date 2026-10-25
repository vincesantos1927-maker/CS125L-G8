;==============================================================
; TEMPORARY STAND-IN for src\50_rules.asm (Member C's module).
; build.bat uses this file ONLY when src\50_rules.asm is missing.
; It is just enough to play the game. Never merge it with C's file.
; Assumed interface (tell D if C's real procedures differ):
;   SEEDRANDOM        -> RandSeed
;   RANDOM            -> AX
;   RANDOMRANGE       CX = N (1..255)  -> DX = 0..N-1
;   GENERATEFOOD      -> FoodX, FoodY, FoodColor (not on the snake)
;   CHECKCOLLISION    NewX, NewY -> AL = 1 wall/self, else 0
;   APPLYFOOD         score, grow, level, new food (draws it)
;   UPDATESCORE       AX = points -> ScoreValue, HighScore
;   UPDATELEVEL       every FOODS_PER_LEVEL: LevelValue++, SpeedQ--
;   LOSELIFE          LivesValue--
;   APPLYDIFFICULTY   AL = 1..3 -> SpeedQ
;==============================================================

SEEDRANDOM PROC
    PUSH AX
    PUSH CX
    PUSH DX
    MOV AH, 00H             ; INT 1Ah / 00h : CX:DX = BIOS ticks
    INT 1AH
    XOR DX, CX              ; mix both halves
    MOV RandSeed, DX
    POP DX
    POP CX
    POP AX
    RET
SEEDRANDOM ENDP

RANDOM PROC                 ; OUT AX = next seed*25173+13849
    PUSH DX
    MOV AX, RandSeed
    MOV DX, 25173
    MUL DX                  ; DX:AX = AX*25173, keep AX
    ADD AX, 13849
    MOV RandSeed, AX
    POP DX
    RET
RANDOM ENDP

RANDOMRANGE PROC            ; IN CX = N, OUT DX = 0..N-1
    PUSH AX
    CALL RANDOM
    MOV AL, AH              ; high byte is the better one
    XOR AH, AH
    XOR DX, DX              ; DIV uses DX:AX
    DIV CX
    POP AX
    RET
RANDOMRANGE ENDP

GENERATEFOOD PROC
    PUSH AX
    PUSH CX
    PUSH DX
    PUSH SI
GF_TRY:
    MOV CX, 38
    CALL RANDOMRANGE
    ADD DL, FIELD_MIN_COL
    MOV AL, DL              ; AL = column
    MOV CX, 20
    CALL RANDOMRANGE
    ADD DL, FIELD_MIN_ROW
    MOV AH, DL              ; AH = row
    XOR CH, CH
    MOV CL, SnakeLen
    XOR SI, SI
GF_CHECK:
    CMP AL, SnakeX[SI]
    JNE GF_NEXT
    CMP AH, SnakeY[SI]
    JE GF_TRY               ; on the snake: pick again
GF_NEXT:
    INC SI
    LOOP GF_CHECK
    MOV FoodX, AL
    MOV FoodY, AH
    MOV FoodColor, CLR_FOOD
    POP SI
    POP DX
    POP CX
    POP AX
    RET
GENERATEFOOD ENDP

CHECKCOLLISION PROC         ; OUT AL = 1 if NewX/NewY is deadly
    PUSH CX
    PUSH SI
    MOV AL, NewX
    CMP AL, FIELD_MIN_COL
    JB CC_HIT
    CMP AL, FIELD_MAX_COL
    JA CC_HIT
    MOV AH, NewY
    CMP AH, FIELD_MIN_ROW
    JB CC_HIT
    CMP AH, FIELD_MAX_ROW
    JA CC_HIT
    XOR CH, CH
    MOV CL, SnakeLen
    XOR SI, SI
CC_LOOP:
    CMP AL, SnakeX[SI]
    JNE CC_NEXT
    CMP AH, SnakeY[SI]
    JE CC_HIT               ; any body cell, tail included
CC_NEXT:
    INC SI
    LOOP CC_LOOP
    MOV AL, 0
    JMP CC_DONE
CC_HIT:
    MOV AL, 1
CC_DONE:
    POP SI
    POP CX
    RET
CHECKCOLLISION ENDP

APPLYFOOD PROC
    PUSH AX
    PUSH BX
    MOV AX, PTS_NORMAL
    CALL UPDATESCORE
    CALL GROWSNAKE          ; B
    INC FoodsInLevel
    CALL UPDATELEVEL
    CALL GENERATEFOOD
    MOV AL, FoodX
    MOV AH, FoodY
    MOV BL, FoodColor
    CALL DRAWFOOD           ; A
    POP BX
    POP AX
    RET
APPLYFOOD ENDP

UPDATESCORE PROC            ; IN AX = points
    ADD ScoreValue, AX
    PUSH AX
    MOV AX, ScoreValue
    CMP AX, HighScore
    JBE US_DONE
    MOV HighScore, AX
US_DONE:
    POP AX
    RET
UPDATESCORE ENDP

UPDATELEVEL PROC
    CMP FoodsInLevel, FOODS_PER_LEVEL
    JB UL_DONE
    MOV FoodsInLevel, 0
    INC LevelValue
    CMP SpeedQ, SPEEDQ_MIN
    JBE UL_DONE
    DEC SpeedQ
UL_DONE:
    RET
UPDATELEVEL ENDP

LOSELIFE PROC
    DEC LivesValue
    RET
LOSELIFE ENDP

APPLYDIFFICULTY PROC        ; IN AL = 1..3
    CMP AL, 1
    JE AD_EASY
    CMP AL, 3
    JE AD_HARD
    MOV SpeedQ, SPEEDQ_NORMAL
    RET
AD_EASY:
    MOV SpeedQ, SPEEDQ_EASY
    RET
AD_HARD:
    MOV SpeedQ, SPEEDQ_HARD
    RET
APPLYDIFFICULTY ENDP

