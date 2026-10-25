;==============================================================
; MODULE M2 : 40_snake.asm   (Member B - Snake / Input)
; Procedures: INITSNAKE, DRAWSNAKE, MOVESNAKE, READINPUT,
;             UPDATEDIRECTION, GAMEDELAY, HANDLEPAUSE,
;             CLEARKEYBUFFER  (+ helpers GROWSNAKE, SHRINKSNAKE)
;
; GRID (matches 30_gfx.asm): 40 columns x 25 rows, 1 cell = 8x8 px
;   walls : column 0 and 39, row 3 and 24
;   inside: columns 1..38, rows 4..23
;
; SHARED CONSTANTS REQUIRED (put in 00_header.asm):
;
; SNAKE_MAX    EQU 150    ; maximum snake length
; START_COL    EQU 20     ; head start column
; START_ROW    EQU 14     ; head start row
; HEAD_COLOR   EQU 0AH    ; light green
; BODY_COLOR   EQU 02H    ; green
; ERASE_COLOR  EQU 00H    ; black
; PAUSE_COL    EQU 28     ; text column of the PAUSED message
;
; SHARED DATA REQUIRED (put in 10_data.asm):
;
; ---- owned by B (this module) ----
; SnakeX      DB 150 DUP(0)   ; column of each segment (0 = head)
; SnakeY      DB 150 DUP(0)   ; row of each segment
; SnakeLen    DB 3
; SnakeDir    DB 1            ; 0=Up 1=Right 2=Down 3=Left (direction last moved)
; NextDir     DB 1            ; direction requested by the player
; NewX        DB 0            ; next head column (read by C's CHECKCOLLISION)
; NewY        DB 0            ; next head row
; TailX       DB 0            ; tail removed by the last move
; TailY       DB 0
; DxTab       DB 0, 1, 0, 0FFH
; DyTab       DB 0FFH, 0, 1, 0
; QuitFlag    DB 0            ; set to 1 when ESC is pressed (D checks it)
; AccQ        DW 0            ; leftover quarter-ticks (GAMEDELAY)
; WaitTicks   DW 0
; LastTick    DW 0
; PauseText   DB '** PAUSED **', 0
;
; ---- owned by C (this module only READS them) ----
; FoodX       DB 0            ; food column
; FoodY       DB 0            ; food row
; SpeedQ      DB 16           ; delay per move in quarter-ticks (4 = ~55 ms)
;                             ; written by C's ApplyDifficulty / UpdateLevel
;
; PROCEDURES REQUIRED FROM OTHER MODULES:
;   A: DRAWCELL, FILLRECT, SETCURSOR, PRINTSTRING
;   C: CHECKCOLLISION  in : NewX, NewY      out: AL = 1 if hit, else 0
;                      (must also test the snake's own body, tail included)
;      APPLYFOOD       called by MOVESNAKE when the new head is on the food;
;                      C calls GROWSNAKE or SHRINKSNAKE from inside it
;==============================================================

; -----------------------------------------
; INITSNAKE
; Puts a 3-segment snake in the middle of the
; playfield, heading right. Does not draw it.
; -----------------------------------------
INITSNAKE PROC
    PUSH AX

    MOV SnakeLen, 3

    ; Columns: head at START_COL, body to its left
    MOV AL, START_COL
    MOV SnakeX[0], AL
    DEC AL
    MOV SnakeX[1], AL
    DEC AL
    MOV SnakeX[2], AL

    ; All three segments start on the same row
    MOV AL, START_ROW
    MOV SnakeY[0], AL
    MOV SnakeY[1], AL
    MOV SnakeY[2], AL

    ; Moving right
    MOV SnakeDir, 1
    MOV NextDir, 1
    MOV AccQ, 0

    POP AX
    RET
INITSNAKE ENDP


; -----------------------------------------
; DRAWSNAKE
; Draws the whole snake: head light green,
; every other segment green
; -----------------------------------------
DRAWSNAKE PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH SI

    CLD
    XOR SI, SI
    MOV CL, SnakeLen
    XOR CH, CH
    MOV BL, HEAD_COLOR      ; first segment = head

DSN_LOOP:
    MOV AL, SnakeX[SI]      ; AL = column
    MOV AH, SnakeY[SI]      ; AH = row
    CALL DRAWCELL           ; BL = color
    MOV BL, BODY_COLOR      ; remaining segments = body
    INC SI
    LOOP DSN_LOOP

    POP SI
    POP CX
    POP BX
    POP AX
    RET
DRAWSNAKE ENDP


; -----------------------------------------
; MOVESNAKE
; Moves the snake one cell.
; Output: AL = 1 if the snake crashed (nothing
;         was moved), AL = 0 if the move was made
; -----------------------------------------
MOVESNAKE PROC
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    CLD

    ; Commit the direction the player asked for
    MOV AL, NextDir
    MOV SnakeDir, AL

    ; New head = old head + direction table
    XOR BX, BX
    MOV BL, SnakeDir
    MOV AL, SnakeX[0]
    ADD AL, DxTab[BX]
    MOV NewX, AL
    MOV AL, SnakeY[0]
    ADD AL, DyTab[BX]
    MOV NewY, AL

    ; Ask C's module whether that cell is deadly
    CALL CHECKCOLLISION
    CMP AL, 1
    JNE MS_GO
    JMP MS_END              ; crashed: AL stays 1

MS_GO:
    ; Remember the tail (needed to erase it / to grow)
    XOR BX, BX
    MOV BL, SnakeLen
    DEC BX
    MOV AL, SnakeX[BX]
    MOV TailX, AL
    MOV AL, SnakeY[BX]
    MOV TailY, AL

    ; Shift every segment one place toward the tail with
    ; STD + REP MOVSB (copy backwards because the ranges overlap)
    PUSH ES
    PUSH DS
    POP ES                  ; ES = DS
    MOV CX, BX              ; CX = SnakeLen - 1 bytes to move
    MOV DX, BX              ; keep the count for the second array
    STD
    LEA SI, SnakeX
    ADD SI, DX
    DEC SI                  ; source      = SnakeX + (len-2)
    LEA DI, SnakeX
    ADD DI, DX              ; destination = SnakeX + (len-1)
    REP MOVSB
    MOV CX, DX
    LEA SI, SnakeY
    ADD SI, DX
    DEC SI
    LEA DI, SnakeY
    ADD DI, DX
    REP MOVSB
    CLD
    POP ES

    ; Store the new head
    MOV AL, NewX
    MOV SnakeX[0], AL
    MOV AL, NewY
    MOV SnakeY[0], AL

    ; Erase old tail first (so a head entering that cell stays visible)
    MOV AL, TailX
    MOV AH, TailY
    MOV BL, ERASE_COLOR
    CALL DRAWCELL

    ; Old head becomes body
    MOV AL, SnakeX[1]
    MOV AH, SnakeY[1]
    MOV BL, BODY_COLOR
    CALL DRAWCELL

    ; Draw the new head
    MOV AL, NewX
    MOV AH, NewY
    MOV BL, HEAD_COLOR
    CALL DRAWCELL

    ; Did the head land on the food?
    MOV AL, NewX
    CMP AL, FoodX
    JNE MS_OK
    MOV AL, NewY
    CMP AL, FoodY
    JNE MS_OK
    CALL APPLYFOOD          ; C: score, effects, new food

MS_OK:
    MOV AL, 0               ; move succeeded

MS_END:
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    RET
MOVESNAKE ENDP


; -----------------------------------------
; GROWSNAKE
; Call from APPLYFOOD right after MOVESNAKE
; moved the head. Puts the old tail back so
; the snake is one segment longer.
; -----------------------------------------
GROWSNAKE PROC
    PUSH AX
    PUSH BX

    CMP SnakeLen, SNAKE_MAX ; already at maximum length?
    JAE GRS_DONE

    XOR BX, BX
    MOV BL, SnakeLen        ; index of the new last segment
    MOV AL, TailX
    MOV AH, TailY
    MOV SnakeX[BX], AL
    MOV SnakeY[BX], AH

    MOV BL, BODY_COLOR      ; redraw the cell that MOVESNAKE erased
    CALL DRAWCELL
    INC SnakeLen

GRS_DONE:
    POP BX
    POP AX
    RET
GROWSNAKE ENDP


; -----------------------------------------
; SHRINKSNAKE
; Removes up to 2 segments from the tail
; (never goes below length 3) and erases them
; -----------------------------------------
SHRINKSNAKE PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH SI

    MOV CX, 2

SHS_LOOP:
    CMP SnakeLen, 3
    JBE SHS_DONE

    XOR AH, AH
    MOV AL, SnakeLen
    DEC AL
    MOV SI, AX              ; SI = index of the last segment
    MOV AL, SnakeX[SI]
    MOV AH, SnakeY[SI]
    MOV BL, ERASE_COLOR
    CALL DRAWCELL           ; erase that segment
    DEC SnakeLen
    LOOP SHS_LOOP

SHS_DONE:
    POP SI
    POP CX
    POP BX
    POP AX
    RET
SHRINKSNAKE ENDP


; -----------------------------------------
; UPDATEDIRECTION
; Input: BL = wanted direction (0-3)
; Ignores a 180-degree turn. Opposite of
; direction D is (D + 2) AND 3.
; -----------------------------------------
UPDATEDIRECTION PROC
    PUSH AX

    MOV AL, SnakeDir
    ADD AL, 2
    AND AL, 3
    CMP AL, BL
    JE UD_DONE              ; reverse turn -> ignored
    MOV NextDir, BL

UD_DONE:
    POP AX
    RET
UPDATEDIRECTION ENDP


; -----------------------------------------
; READINPUT
; Non-blocking keyboard check:
;   arrows / WASD = turn, P = pause, ESC = quit
; Returns immediately when no key is waiting
; -----------------------------------------
READINPUT PROC
    PUSH AX
    PUSH BX

    MOV AH, 01H             ; INT 16h / 01h : key waiting? (ZF = 1 -> none)
    INT 16H
    JNZ RI_GET
    JMP RI_END

RI_GET:
    MOV AH, 00H             ; INT 16h / 00h : AL = ASCII, AH = scan code
    INT 16H

    CMP AL, 27              ; ESC
    JNE RI_N1
    MOV QuitFlag, 1
    JMP RI_END

RI_N1:
    CMP AL, 0               ; extended key (arrows)
    JE RI_EXT
    CMP AL, 0E0H
    JE RI_EXT

    OR AL, 20H              ; force lowercase
    CMP AL, 'w'
    JE RI_UP
    CMP AL, 'd'
    JE RI_RIGHT
    CMP AL, 's'
    JE RI_DOWN
    CMP AL, 'a'
    JE RI_LEFT
    CMP AL, 'p'
    JNE RI_END
    CALL HANDLEPAUSE
    JMP RI_END

RI_EXT:                     ; scan codes: up / right / down / left
    CMP AH, 48H
    JE RI_UP
    CMP AH, 4DH
    JE RI_RIGHT
    CMP AH, 50H
    JE RI_DOWN
    CMP AH, 4BH
    JNE RI_END

RI_LEFT:
    MOV BL, 3
    JMP RI_SET
RI_UP:
    MOV BL, 0
    JMP RI_SET
RI_RIGHT:
    MOV BL, 1
    JMP RI_SET
RI_DOWN:
    MOV BL, 2

RI_SET:
    CALL UPDATEDIRECTION

RI_END:
    POP BX
    POP AX
    RET
READINPUT ENDP


; -----------------------------------------
; GAMEDELAY
; Waits one game step while still reading keys.
; Step length = SpeedQ quarter-ticks (4 = one
; BIOS tick, ~55 ms). The leftover quarter-ticks
; are carried over (AccQ) so speed can rise
; smoothly. Returns early if ESC is pressed.
; -----------------------------------------
GAMEDELAY PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    XOR AX, AX
    MOV AL, SpeedQ
    ADD AX, AccQ            ; add leftover quarter-ticks
    MOV BX, AX
    AND BX, 3               ; new leftover = remainder of /4
    MOV AccQ, BX
    SHR AX, 1
    SHR AX, 1               ; whole ticks to wait
    MOV WaitTicks, AX

    MOV AH, 00H             ; INT 1Ah / 00h : CX:DX = BIOS tick counter
    INT 1AH
    MOV LastTick, DX

GD_WAIT:
    CALL READINPUT          ; keep reading keys while waiting
    CMP QuitFlag, 1
    JE GD_DONE
    MOV AH, 00H
    INT 1AH
    MOV AX, DX
    SUB AX, LastTick        ; ticks elapsed
    CMP AX, WaitTicks
    JB GD_WAIT

GD_DONE:
    POP DX
    POP CX
    POP BX
    POP AX
    RET
GAMEDELAY ENDP


; -----------------------------------------
; HANDLEPAUSE
; Freezes the game: P = resume, ESC = quit.
; Shows ** PAUSED ** on text row 0 and erases
; it again when the game resumes.
; -----------------------------------------
HANDLEPAUSE PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    MOV DH, 0               ; row 0
    MOV DL, PAUSE_COL
    CALL SETCURSOR
    MOV SI, OFFSET PauseText
    MOV BL, 0EH             ; yellow
    CALL PRINTSTRING

HP_WAIT:
    MOV AH, 00H             ; INT 16h / 00h : wait for a key
    INT 16H
    CMP AL, 'p'
    JE HP_RESUME
    CMP AL, 'P'
    JE HP_RESUME
    CMP AL, 27
    JNE HP_WAIT
    MOV QuitFlag, 1         ; ESC while paused = quit

HP_RESUME:
    ; Erase the message: black rectangle x = PAUSE_COL*8, y = 0, 96 x 8
    MOV CX, PAUSE_COL
    SHL CX, 1
    SHL CX, 1
    SHL CX, 1
    MOV DX, 0
    MOV SI, 96
    MOV DI, 8
    MOV BL, ERASE_COLOR
    CALL FILLRECT

    CALL CLEARKEYBUFFER     ; drop keys typed while paused

    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
HANDLEPAUSE ENDP


; -----------------------------------------
; CLEARKEYBUFFER
; Throws away every key waiting in the BIOS
; keyboard buffer
; -----------------------------------------
CLEARKEYBUFFER PROC
    PUSH AX

CKB_LOOP:
    MOV AH, 01H             ; key waiting?
    INT 16H
    JZ CKB_DONE             ; ZF = 1 -> buffer empty
    MOV AH, 00H             ; remove it
    INT 16H
    JMP CKB_LOOP

CKB_DONE:
    POP AX
    RET
CLEARKEYBUFFER ENDP