;==============================================================
; 10_data.asm (SINGCAY) : all variables and text strings
;==============================================================
.DATA

;---------------- snake (owner B) -----------------------------
SnakeX          DB SNAKE_MAX DUP(0)   ; column of each segment, 0 = head
SnakeY          DB SNAKE_MAX DUP(0)   ; row of each segment
SnakeLen        DB START_LEN
SnakeDir        DB DIR_RIGHT          ; direction last moved
NextDir         DB DIR_RIGHT          ; direction requested by player
NewX            DB 0                  ; next head column
NewY            DB 0                  ; next head row
TailX           DB 0                  ; tail removed by last move
TailY           DB 0
DxTab           DB 0, 1, 0, 0FFH      ; column step per direction
DyTab           DB 0FFH, 0, 1, 0      ; row step per direction
QuitFlag        DB 0                  ; 1 = ESC pressed
AccQ            DW 0                  ; GAMEDELAY leftover quarter-ticks
WaitTicks       DW 0
LastTick        DW 0
PauseText       DB '** PAUSED **',0

;---------------- food / rules (owner C) ----------------------
FoodX           DB 0
FoodY           DB 0
FoodColor       DB CLR_FOOD           ; C sets this when placing food
SpeedQ          DB SPEEDQ_NORMAL      ; quarter-ticks per move
FoodsInLevel    DB 0                  ; foods eaten since last level-up
RandSeed        DW 1
HighScore       DW 0                  ; best score this session

;---------------- HUD values (read by A's DRAWHUD) ------------
ScoreValue      DW 0
LivesValue      DW START_LIVES
LevelValue      DW 1
DifficultyValue DB 'NORMAL',0,0       ; 8 bytes: room for the longest name
DigitColor      DB CLR_TEXT           ; used by A's PRINTNUMBER

;---------------- game flow (owner D) -------------------------
GameState       DB STATE_MENU
Difficulty      DB 2                  ; 1 = easy, 2 = normal, 3 = hard
LastHudScore    DW 0                  ; score shown on the HUD right now

;---------------- HUD labels (A's DRAWHUD) --------------------
TitleText       DB 'NOT PYTHON',0
ScoreText       DB 'SCORE: ',0
LivesText       DB 'LIVES: ',0
LevelText       DB 'LEVEL: ',0
; 13-byte buffer: SELECTDIFFICULTY copies lblShort/lblLong here
; so 'DIFF: <name>' always ends at the same right edge as LIVES
DifficultyText  DB '    DIFF: ',0,0,0

;---------------- menu and prompt text (owner D) --------------
; 0DH,0AH = new line; 0 ends every string
msgCRLF         DB 0DH,0AH,0
msgTitle        DB '=== NOT PYTHON : Snake in 8086 Assembly ===',0DH,0AH,0DH,0AH,0
msgDesc1        DB 'Steer the snake, eat the food and avoid',0DH,0AH,0
msgDesc2        DB 'the walls and your own body.',0DH,0AH,0
msgDesc3        DB 'You have 3 lives. The game speeds up as',0DH,0AH,0
msgDesc4        DB 'your level rises.',0DH,0AH,0
msgMenu1        DB 0DH,0AH,'  [1] Play',0DH,0AH,0
msgMenu2        DB '  [2] Instructions',0DH,0AH,0
msgMenu3        DB '  [3] Exit',0DH,0AH,0
msgMenuAsk      DB 0DH,0AH,'Choose an option (1-3): ',0
msgMenuKeys     DB '123',0

msgInstr1       DB '=== HOW TO PLAY ===',0DH,0AH,0DH,0AH,0
msgInstr2       DB 'Arrow keys or W A S D : steer the snake',0DH,0AH,0
msgInstr3       DB 'P                     : pause / resume',0DH,0AH,0
msgInstr4       DB 'ESC                   : back to the menu',0DH,0AH,0
msgInstr5       DB 'You cannot turn straight back into yourself.',0DH,0AH,0
msgInstr6       DB 0DH,0AH,'Press any key to return...',0

msgDiff         DB 'Select difficulty: [1] Easy  [2] Normal  [3] Hard : ',0
msgDiffKeys     DB '123',0
msgEasy         DB 'EASY',0
msgNormal       DB 'NORMAL',0
msgHard         DB 'HARD',0
; address tables: entry 0 = Easy, 1 = Normal, 2 = Hard
DiffNames       DW OFFSET msgEasy, OFFSET msgNormal, OFFSET msgHard
; HUD label per difficulty (EASY/HARD need 2 more spaces than NORMAL)
lblShort        DB '      DIFF: ',0  ; 6 spaces (EASY, HARD)
lblLong         DB '    DIFF: ',0    ; 4 spaces (NORMAL)
DiffLabels      DW OFFSET lblShort, OFFSET lblLong, OFFSET lblShort

msgInvalid      DB 0DH,0AH,'Invalid key. Try again: ',0

msgOver         DB '=== GAME OVER ===',0DH,0AH,0DH,0AH,0
msgFinal        DB 'Final score  : ',0
msgLevelReach   DB 'Level reached: ',0
msgHigh         DB 'High score   : ',0
msgReplay       DB 0DH,0AH,0DH,0AH,'Press [R] to replay or [M] for menu: ',0
msgOverKeys     DB 'RM',0

msgLifeLost     DB 'LIFE LOST - press any key',0
msgLivesLeft    DB 'LIVES LEFT: ',0

