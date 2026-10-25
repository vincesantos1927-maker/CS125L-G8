;==============================================================
; 20_main.asm (SINGCAY) : MAIN, INITIALIZEGAME, STARTLEVEL, RUNGAME
; MAIN loops on GameState: menu -> play -> game over -> exit.
;==============================================================
.CODE

;--------------------------------------------------------------
; MAIN : set up DS/ES, seed random, run the state dispatcher
;--------------------------------------------------------------
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX              ; DS = data segment
    MOV ES, AX              ; keep ES = DS
    CLD                     ; string instructions count up
    CALL SEEDRANDOM         ; seed random from the BIOS clock
    MOV GameState, STATE_MENU

MN_DISPATCH:                ; jump to the handler for the current state
    CMP GameState, STATE_MENU
    JE MN_MENU
    CMP GameState, STATE_PLAYING
    JE MN_PLAY
    CMP GameState, STATE_GAMEOVER
    JE MN_OVER
    JMP MN_EXIT

MN_MENU:
    CALL SHOWMAINMENU       ; AL = '1', '2' or '3'
    CMP AL, '1'
    JE MN_START
    CMP AL, '2'
    JE MN_INSTR
    MOV GameState, STATE_EXIT   ; '3' = exit
    JMP MN_DISPATCH

MN_START:
    CALL SELECTDIFFICULTY
    MOV GameState, STATE_PLAYING
    JMP MN_DISPATCH

MN_INSTR:
    CALL SHOWINSTRUCTIONS
    JMP MN_DISPATCH

MN_PLAY:
    CALL INITIALIZEGAME
    CALL RUNGAME            ; sets GameState when it returns
    JMP MN_DISPATCH

MN_OVER:
    CALL SHOWGAMEOVER       ; AL = 'R' or 'M'
    CMP AL, 'R'
    JNE MN_TOMENU
    CALL SELECTDIFFICULTY   ; replay: pick difficulty again
    MOV GameState, STATE_PLAYING
    JMP MN_DISPATCH

MN_TOMENU:
    MOV GameState, STATE_MENU
    JMP MN_DISPATCH

MN_EXIT:
    CALL RESTORETEXTMODE    ; always leave in text mode
    MOV AX, 4C00H           ; INT 21h / 4Ch : exit to DOS
    INT 21H
MAIN ENDP


;--------------------------------------------------------------
; INITIALIZEGAME : reset score, level, lives and flags for a new game
;--------------------------------------------------------------
INITIALIZEGAME PROC
    PUSH AX

    MOV ScoreValue, 0
    MOV LevelValue, 1
    MOV LivesValue, START_LIVES
    MOV FoodsInLevel, 0
    MOV QuitFlag, 0
    MOV LastHudScore, 0

    MOV AL, Difficulty
    CALL APPLYDIFFICULTY    ; sets the starting speed

    POP AX
    RET
INITIALIZEGAME ENDP


;--------------------------------------------------------------
; STARTLEVEL : draw board, snake, food and HUD (also after a lost life)
; INITGRAPHICS clears the screen, so the old snake disappears.
;--------------------------------------------------------------
STARTLEVEL PROC
    PUSH AX
    PUSH BX

    CALL INITGRAPHICS       ; mode 13h, clears the screen
    CALL DRAWBOARD          ; wall ring
    CALL INITSNAKE          ; snake back to its start position
    CALL GENERATEFOOD       ; after INITSNAKE so food is not on the snake
    MOV AL, FoodX           ; AL = column
    MOV AH, FoodY           ; AH = row
    MOV BL, FoodColor
    CALL DRAWFOOD
    CALL DRAWSNAKE
    CALL REFRESHHUD
    CALL CLEARKEYBUFFER     ; drop old key presses

    POP BX
    POP AX
    RET
STARTLEVEL ENDP


;--------------------------------------------------------------
; RUNGAME : the game loop (wait, move, handle crash)
;--------------------------------------------------------------
RUNGAME PROC
    PUSH AX

    CALL STARTLEVEL

RG_LOOP:
    CALL GAMEDELAY          ; wait one step, reads keys meanwhile
    CMP QuitFlag, 1
    JE RG_QUIT              ; ESC pressed
    CALL MOVESNAKE          ; AL = 1 if crashed
    CMP AL, 1
    JE RG_CRASH
    MOV AX, ScoreValue
    CMP AX, LastHudScore
    JE RG_LOOP              ; score unchanged: skip the HUD redraw
    CALL REFRESHHUD
    JMP RG_LOOP

RG_CRASH:
    CALL LOSELIFE           ; LivesValue - 1
    CMP LivesValue, 0
    JE RG_OVER
    CALL SHOWLIFELOST
    CALL STARTLEVEL         ; respawn, score kept
    JMP RG_LOOP

RG_OVER:
    CALL RESTORETEXTMODE
    MOV GameState, STATE_GAMEOVER
    JMP RG_END

RG_QUIT:
    CALL RESTORETEXTMODE
    MOV GameState, STATE_MENU

RG_END:
    POP AX
    RET
RUNGAME ENDP

