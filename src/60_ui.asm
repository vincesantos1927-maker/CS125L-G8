;==============================================================
; 60_ui.asm (SINGCAY) : menus, prompts and messages
; Invalid keys never crash: GETMENUKEY prints a message and waits again.
;==============================================================

;--------------------------------------------------------------
; GETMENUKEY : wait for a key in the list at SI (0-terminated);
; returns it in AL, re-prompts on an invalid key
;--------------------------------------------------------------
GETMENUKEY PROC
    PUSH BX

GK_WAIT:
    MOV AH, 00H             ; INT 16h / 00h : wait for a key
    INT 16H
    CMP AL, 'a'
    JB GK_FIND
    CMP AL, 'z'
    JA GK_FIND
    AND AL, 0DFH            ; a-z -> A-Z (letters only, not digits)

GK_FIND:
    MOV BX, SI              ; BX walks the valid-key list
GK_SCAN:
    MOV AH, [BX]
    CMP AH, 0
    JE GK_BAD               ; end of list: invalid key
    CMP AL, AH
    JE GK_OK
    INC BX
    JMP GK_SCAN

GK_BAD:
    PUSH SI
    MOV SI, OFFSET msgInvalid
    MOV BL, CLR_WARN
    CALL PRINTSTRING        ; "Invalid key. Try again:"
    POP SI
    JMP GK_WAIT

GK_OK:
    MOV AH, 0EH             ; INT 10h / 0Eh : echo the key
    MOV BH, 0
    MOV BL, CLR_TEXT
    INT 10H
    POP BX
    RET
GETMENUKEY ENDP


;--------------------------------------------------------------
; SHOWMAINMENU : title, description, options; returns '1'/'2'/'3' in AL
;--------------------------------------------------------------
SHOWMAINMENU PROC
    PUSH BX
    PUSH DX
    PUSH SI

    CALL CLEARTEXTSCREEN
    MOV DH, 0               ; cursor to row 0, column 0
    MOV DL, 0
    CALL SETCURSOR

    MOV BL, CLR_TEXT
    MOV SI, OFFSET msgTitle
    CALL PRINTSTRING
    MOV SI, OFFSET msgDesc1
    CALL PRINTSTRING
    MOV SI, OFFSET msgDesc2
    CALL PRINTSTRING
    MOV SI, OFFSET msgDesc3
    CALL PRINTSTRING
    MOV SI, OFFSET msgDesc4
    CALL PRINTSTRING
    MOV SI, OFFSET msgMenu1
    CALL PRINTSTRING
    MOV SI, OFFSET msgMenu2
    CALL PRINTSTRING
    MOV SI, OFFSET msgMenu3
    CALL PRINTSTRING
    MOV SI, OFFSET msgMenuAsk
    CALL PRINTSTRING

    MOV SI, OFFSET msgMenuKeys  ; valid keys: 1, 2, 3
    CALL GETMENUKEY

    POP SI
    POP DX
    POP BX
    RET
SHOWMAINMENU ENDP


;--------------------------------------------------------------
; SHOWINSTRUCTIONS : controls screen, any key returns
;--------------------------------------------------------------
SHOWINSTRUCTIONS PROC
    PUSH AX
    PUSH BX
    PUSH DX
    PUSH SI

    CALL CLEARTEXTSCREEN
    MOV DH, 0
    MOV DL, 0
    CALL SETCURSOR

    MOV BL, CLR_TEXT
    MOV SI, OFFSET msgInstr1
    CALL PRINTSTRING
    MOV SI, OFFSET msgInstr2
    CALL PRINTSTRING
    MOV SI, OFFSET msgInstr3
    CALL PRINTSTRING
    MOV SI, OFFSET msgInstr4
    CALL PRINTSTRING
    MOV SI, OFFSET msgInstr5
    CALL PRINTSTRING
    MOV SI, OFFSET msgInstr6
    CALL PRINTSTRING

    MOV AH, 00H             ; wait for any key
    INT 16H

    POP SI
    POP DX
    POP BX
    POP AX
    RET
SHOWINSTRUCTIONS ENDP


;--------------------------------------------------------------
; SELECTDIFFICULTY : ask 1/2/3, save Difficulty and copy its name
; and HUD label (DifficultyValue, DifficultyText) for the HUD
;--------------------------------------------------------------
SELECTDIFFICULTY PROC
    PUSH AX
    PUSH BX
    PUSH DX
    PUSH SI
    PUSH DI

    CALL CLEARTEXTSCREEN
    MOV DH, 0
    MOV DL, 0
    CALL SETCURSOR

    MOV BL, CLR_TEXT
    MOV SI, OFFSET msgDiff
    CALL PRINTSTRING
    MOV SI, OFFSET msgDiffKeys  ; valid keys: 1, 2, 3
    CALL GETMENUKEY

    SUB AL, '0'             ; '1'..'3' -> 1..3
    MOV Difficulty, AL

    XOR AH, AH
    DEC AX                  ; table position 0..2
    MOV BX, AX
    SHL BX, 1               ; x2: table entries are words
    MOV SI, DiffNames[BX]   ; SI = name string
    MOV DI, OFFSET DifficultyValue
SD_COPY:
    LODSB                   ; copy the name including its 0
    STOSB
    CMP AL, 0
    JNE SD_COPY

    MOV SI, DiffLabels[BX]  ; SI = matching HUD label
    MOV DI, OFFSET DifficultyText
SD_COPY2:
    LODSB                   ; copy the label the same way
    STOSB
    CMP AL, 0
    JNE SD_COPY2

    POP DI
    POP SI
    POP DX
    POP BX
    POP AX
    RET
SELECTDIFFICULTY ENDP


;--------------------------------------------------------------
; SHOWGAMEOVER : final score, level, high score; returns 'R' or 'M' in AL
;--------------------------------------------------------------
SHOWGAMEOVER PROC
    PUSH BX
    PUSH DX
    PUSH SI

    CALL CLEARTEXTSCREEN
    MOV DH, 0
    MOV DL, 0
    CALL SETCURSOR

    MOV BL, CLR_TEXT
    MOV SI, OFFSET msgOver
    CALL PRINTSTRING

    MOV SI, OFFSET msgFinal
    CALL PRINTSTRING
    MOV AX, ScoreValue      ; AX = number to print
    MOV BL, CLR_TEXT
    CALL PRINTNUMBER
    MOV SI, OFFSET msgCRLF
    CALL PRINTSTRING

    MOV SI, OFFSET msgLevelReach
    CALL PRINTSTRING
    MOV AX, LevelValue
    MOV BL, CLR_TEXT
    CALL PRINTNUMBER
    MOV SI, OFFSET msgCRLF
    CALL PRINTSTRING

    MOV SI, OFFSET msgHigh
    CALL PRINTSTRING
    MOV AX, HighScore
    MOV BL, CLR_TEXT
    CALL PRINTNUMBER
    MOV SI, OFFSET msgCRLF
    CALL PRINTSTRING

    MOV SI, OFFSET msgReplay
    CALL PRINTSTRING
    MOV SI, OFFSET msgOverKeys  ; valid keys: R, M
    CALL GETMENUKEY

    POP SI
    POP DX
    POP BX
    RET
SHOWGAMEOVER ENDP


;--------------------------------------------------------------
; SHOWLIFELOST : "LIFE LOST" box with lives left, waits for a key
;--------------------------------------------------------------
SHOWLIFELOST PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    MOV CX, 40              ; border: x, y, width, height in pixels
    MOV DX, 84
    MOV SI, 240
    MOV DI, 32
    MOV BL, CLR_WALL
    CALL FILLRECT
    MOV CX, 42              ; black inside
    MOV DX, 86
    MOV SI, 236
    MOV DI, 28
    MOV BL, ERASE_COLOR
    CALL FILLRECT

    MOV DH, 11              ; message on text row 11
    MOV DL, 7
    CALL SETCURSOR
    MOV SI, OFFSET msgLifeLost
    MOV BL, CLR_TEXT
    CALL PRINTSTRING

    MOV DH, 12              ; lives left on row 12
    MOV DL, 7
    CALL SETCURSOR
    MOV SI, OFFSET msgLivesLeft
    MOV BL, CLR_TEXT
    CALL PRINTSTRING
    MOV AX, LivesValue
    MOV BL, CLR_WARN
    CALL PRINTNUMBER

    CALL CLEARKEYBUFFER     ; ignore keys pressed during the crash
    MOV AH, 00H             ; wait for a new key
    INT 16H

    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
SHOWLIFELOST ENDP


;--------------------------------------------------------------
; REFRESHHUD : erase the old HUD numbers, then redraw the HUD
; (BIOS text does not erase, so old digits must be cleared first)
;--------------------------------------------------------------
REFRESHHUD PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    MOV CX, 64              ; black box over the score/level numbers
    MOV DX, 8
    MOV SI, 48
    MOV DI, 16
    MOV BL, ERASE_COLOR
    CALL FILLRECT

    CALL DRAWHUD

    MOV AX, ScoreValue      ; remember the score now on screen
    MOV LastHudScore, AX

    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
REFRESHHUD ENDP

