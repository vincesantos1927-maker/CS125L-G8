;==============================================================
; PROGRAM TITLE : Not Python - Graphical Snake Game (8086)
; COURSE        : CS125L Machine Problem: Assembly Language Program
; SECTION       : <SECTION>
; GROUP NAME    : <GROUP NAME> (Group 8)
; MEMBERS       : 1. ONA     (Graphics)
;                 2. SANTOS  (Snake / input)
;                 3. TAYAS   (Rules)
;                 4. SINGCAY (UI / integration)
; ASSEMBLER     : EMU8086 <VERSION>
; DESCRIPTION   : Steer a snake in mode 13h, eat food, avoid the
;                 walls and your own body. 3 lives, the game
;                 speeds up as the level rises.
; CONTROLS      : Arrows or W A S D = steer, P = pause, ESC = menu
;==============================================================
; 00_header.asm (SINGCAY) : model, stack, constants
;==============================================================

.MODEL SMALL
.STACK 200H

;---------------- grid (40 x 25 cells of 8 x 8 pixels) --------
CELL_SIZE       EQU 8
CELL_SHIFT      EQU 3
GRID_COLS       EQU 40
GRID_ROWS       EQU 25

;---------------- layout: HUD rows 0-2, wall ring, field ------
WALL_TOP        EQU 3
WALL_BOTTOM     EQU 24
WALL_LEFT       EQU 0
WALL_RIGHT      EQU 39
FIELD_MIN_COL   EQU 1
FIELD_MAX_COL   EQU 38
FIELD_MIN_ROW   EQU 4
FIELD_MAX_ROW   EQU 23

;---------------- snake (names used by 40_snake.asm) ----------
SNAKE_MAX       EQU 150          ; array size of SnakeX / SnakeY
MAX_LEN         EQU SNAKE_MAX    ; alias for the guide's name
START_LEN       EQU 3
START_COL       EQU 20
START_ROW       EQU 14
START_LIVES     EQU 3
HEAD_COLOR      EQU 0AH          ; light green
BODY_COLOR      EQU 02H          ; green
ERASE_COLOR     EQU 00H          ; black
PAUSE_COL       EQU 28           ; text column of ** PAUSED **

;---------------- directions: opposite = (dir + 2) AND 3 -------
DIR_UP          EQU 0
DIR_RIGHT       EQU 1
DIR_DOWN        EQU 2
DIR_LEFT        EQU 3

;---------------- speed: SpeedQ = quarter-ticks per move ------
; 4 quarter-ticks = 1 BIOS tick (about 55 ms); tune by playing
SPEEDQ_EASY     EQU 16
SPEEDQ_NORMAL   EQU 12
SPEEDQ_HARD     EQU 8
SPEEDQ_MIN      EQU 4            ; fastest allowed
FOODS_PER_LEVEL EQU 5

;---------------- food ----------------------------------------
PTS_NORMAL      EQU 10
CLR_FOOD        EQU 0CH          ; light red

;---------------- game states (main dispatcher) ---------------
STATE_MENU      EQU 0
STATE_PLAYING   EQU 1
STATE_PAUSED    EQU 2            ; unused: B's HANDLEPAUSE blocks itself
STATE_GAMEOVER  EQU 3
STATE_EXIT      EQU 4

;---------------- text colors ---------------------------------
CLR_TEXT        EQU 0FH          ; white
CLR_WALL        EQU 09H          ; light blue (message box border)
CLR_WARN        EQU 0CH          ; light red (invalid-key message)

