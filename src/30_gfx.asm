; SHARED DATA REQUIRED (defined in 10_data.asm):
;
; TitleText        DB 'NOT PYTHON', 0
; ScoreText        DB 'SCORE: ', 0
; LivesText        DB 'LIVES: ', 0
; LevelText        DB 'LEVEL: ', 0
; DifficultyText   DB 'DIFFICULTY: ', 0
;
; ScoreValue       DW 0
; LivesValue       DW 3
; LevelValue       DW 1
; DifficultyValue  DB 'EASY', 0
; DigitColor       DB 0FH
;
;==============================================================
; GRAPHICS PROCEDURES
;==============================================================

; -----------------------------------------
; DRAWBOARD
; Draws the horizontal and vertical walls
; -----------------------------------------
DRAWBOARD PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH BP
    
    CLD                 

    ; Top wall: y = 24, height = 8
    MOV CX, 0
    MOV DX, 24
    MOV SI, 320
    MOV DI, 8
    MOV BL, 07H
    CALL FILLRECT

    ; Bottom wall: y = 192, height = 8
    MOV CX, 0
    MOV DX, 192
    MOV SI, 320
    MOV DI, 8
    MOV BL, 07H
    CALL FILLRECT

    ; Left wall: x = 0, y = 32, height = 160
    MOV CX, 0
    MOV DX, 32
    MOV SI, 8
    MOV DI, 160
    MOV BL, 07H
    CALL FILLRECT

    ; Right wall: x = 312, y = 32, height = 160
    MOV CX, 312
    MOV DX, 32
    MOV SI, 8
    MOV DI, 160
    MOV BL, 07H
    CALL FILLRECT

    POP BP
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
DRAWBOARD ENDP


; -----------------------------------------
; DRAWFOOD
; Input: AL = food column
;        AH = food row
;        BL = food color
; Purpose: Draw one food cell
; -----------------------------------------
DRAWFOOD PROC
    PUSH AX
    PUSH BX    
    
    CLD                 

    CALL DRAWCELL

    POP BX
    POP AX
    RET
DRAWFOOD ENDP


; Input: DH = text row, DL = text column
SETCURSOR PROC
    PUSH AX
    PUSH BX
    PUSH DX  
    
    CLD                 

    MOV AH, 02H
    MOV BH, 0
    INT 10H

    POP DX
    POP BX
    POP AX
    RET
SETCURSOR ENDP


; Input: DS:SI = string address, BL = color
PRINTSTRING PROC
    PUSH AX
    PUSH BX
    PUSH SI

    CLD

PS_NEXT:
    LODSB
    CMP AL, 0
    JE PS_DONE

    MOV AH, 0EH
    MOV BH, 0
    INT 10H
    JMP PS_NEXT

PS_DONE:
    POP SI
    POP BX
    POP AX
    RET
PRINTSTRING ENDP


; Input: AX = unsigned number
;        BL = digit color
PRINTNUMBER PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX 
    
    CLD                 

    ; Save the requested color before BX becomes the divisor
    MOV DigitColor, BL

    XOR CX, CX
    MOV BX, 10

    CMP AX, 0
    JNE PN_DIVIDE

    ; Special case: print zero
    MOV AL, '0'
    MOV BL, DigitColor
    MOV AH, 0EH
    MOV BH, 0
    INT 10H
    JMP PN_DONE

PN_DIVIDE:
    XOR DX, DX
    DIV BX
    PUSH DX
    INC CX
    CMP AX, 0
    JNE PN_DIVIDE

PN_PRINT:
    POP DX
    MOV AL, DL
    ADD AL, '0'

    ; Restore the requested color before printing
    MOV BL, DigitColor
    MOV AH, 0EH
    MOV BH, 0
    INT 10H

    LOOP PN_PRINT

PN_DONE:
    POP DX
    POP CX
    POP BX
    POP AX
    RET
PRINTNUMBER ENDP
                

; -----------------------------------------
; CLEARTEXTSCREEN
; Clears the text screen using BIOS INT 10h
; -----------------------------------------
CLEARTEXTSCREEN PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX 
    
    CLD               

    MOV AH, 06H       ; Scroll up / clear window
    MOV AL, 00H       ; Clear the entire window
    MOV BH, 07H       ; Normal text attribute
    MOV CX, 0000H     ; Upper-left corner: row 0, col 0
    MOV DX, 184FH     ; Lower-right: row 24, col 79
    INT 10H

    POP DX
    POP CX
    POP BX
    POP AX
    RET
CLEARTEXTSCREEN ENDP

; -----------------------------------------
; INITGRAPHICS
; Enters Mode 13h: 320 x 200, 256 colors
; -----------------------------------------
INITGRAPHICS PROC
    PUSH AX
    
    CLD
    MOV AX, 0013H
    INT 10H

    POP AX
    RET
INITGRAPHICS ENDP


; -----------------------------------------
; RESTORETEXTMODE
; Restores the standard 80x25 text display
; -----------------------------------------
RESTORETEXTMODE PROC
    PUSH AX
     
    CLD
    MOV AX, 0003H
    INT 10H

    POP AX
    RET
RESTORETEXTMODE ENDP


DRAWHUD PROC
    PUSH AX
    PUSH BX
    PUSH DX
    PUSH SI    
    
    CLD                 

    ; Centered title: white
    MOV DH, 0
    MOV DL, 15
    CALL SETCURSOR
    MOV SI, OFFSET TitleText
    MOV BL, 0FH
    CALL PRINTSTRING

    ; Score label: white
    MOV DH, 1
    MOV DL, 1
    CALL SETCURSOR
    MOV SI, OFFSET ScoreText
    MOV BL, 0FH
    CALL PRINTSTRING

    ; Score value: light green
    MOV AX, ScoreValue
    MOV BL, 0BH
    CALL PRINTNUMBER

    ; Lives label: white
    MOV DH, 1
    MOV DL, 31
    CALL SETCURSOR
    MOV SI, OFFSET LivesText
    MOV BL, 0FH
    CALL PRINTSTRING

    ; Lives value: light red
    MOV AX, LivesValue
    MOV BL, 0CH
    CALL PRINTNUMBER

    ; Level label: white
    MOV DH, 2
    MOV DL, 1
    CALL SETCURSOR
    MOV SI, OFFSET LevelText
    MOV BL, 0FH
    CALL PRINTSTRING

    ; Level value: light green
    MOV AX, LevelValue
    MOV BL, 0AH
    CALL PRINTNUMBER

    ; Difficulty label: white
    MOV DH, 2
    MOV DL, 23
    CALL SETCURSOR
    MOV SI, OFFSET DifficultyText
    MOV BL, 0FH
    CALL PRINTSTRING

    ; Difficulty value: yellow
    MOV SI, OFFSET DifficultyValue
    MOV BL, 0EH
    CALL PRINTSTRING

    POP SI
    POP DX
    POP BX
    POP AX
    RET
DRAWHUD ENDP

; -----------------------------------------
; DRAWCELL
; Input: AL = column, AH = row, BL = color
; Draws one 8 x 8 pixel cell
; -----------------------------------------
DRAWCELL PROC
    PUSH AX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI 
    
    CLD                 

    ; Convert row to pixel Y = row * 8
    MOV DL, AH
    XOR DH, DH
    MOV CL, 3
    SHL DX, CL

    ; Convert column to pixel X = column * 8
    XOR AH, AH
    SHL AX, CL
    MOV CX, AX

    ; Rectangle size = 8 x 8 pixels
    MOV SI, 8
    MOV DI, 8

    ; Draw the cell
    CALL FILLRECT

    POP DI
    POP SI
    POP DX
    POP CX
    POP AX
    RET
DRAWCELL ENDP


; -----------------------------------------
; FILLRECT
; Input: CX = X, DX = Y
;        SI = width, DI = height
;        BL = color
; Draws a filled rectangle pixel by pixel
; -----------------------------------------
FILLRECT PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI 
    
    CLD                 

    MOV AL, BL
    MOV BH, 0

FR_ROW:
    ; Save starting X and width
    PUSH CX
    PUSH SI

FR_COL:
    ; Draw pixel at CX, DX
    MOV AH, 0CH
    INT 10H

    INC CX
    DEC SI
    JNZ FR_COL

    ; Restore X and width for next row
    POP SI
    POP CX

    ; Move to next pixel row
    INC DX
    DEC DI
    JNZ FR_ROW

    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
FILLRECT ENDP



