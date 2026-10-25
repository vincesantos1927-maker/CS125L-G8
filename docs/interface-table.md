# Interface table (Member D) - what the merged game actually uses

Source of truth = the real files in the repo (30_gfx.asm, 40_snake.asm), not the guide.

## D's procedures
| Procedure | IN | OUT | Calls |
|---|---|---|---|
| MAIN | - | - | SEEDRANDOM, all state handlers |
| INITIALIZEGAME | Difficulty | resets score/level/lives/flags | APPLYDIFFICULTY |
| STARTLEVEL | - | fresh board, snake, food, HUD | INITGRAPHICS, DRAWBOARD, INITSNAKE, GENERATEFOOD, DRAWFOOD, DRAWSNAKE, REFRESHHUD, CLEARKEYBUFFER |
| RUNGAME | - | GameState = MENU or GAMEOVER | GAMEDELAY, MOVESNAKE, LOSELIFE, SHOWLIFELOST, REFRESHHUD |
| GETMENUKEY | SI -> valid keys | AL = key | PRINTSTRING |
| SHOWMAINMENU | - | AL = '1'/'2'/'3' | GETMENUKEY |
| SHOWINSTRUCTIONS | - | - | PRINTSTRING |
| SELECTDIFFICULTY | - | Difficulty, DifficultyValue | GETMENUKEY |
| SHOWGAMEOVER | ScoreValue, LevelValue, HighScore | AL = 'R'/'M' | PRINTNUMBER, GETMENUKEY |
| SHOWLIFELOST | LivesValue | - | FILLRECT, PRINTSTRING, PRINTNUMBER |
| REFRESHHUD | - | LastHudScore | FILLRECT, DRAWHUD |

## What D needs from C (50_rules.asm) - please confirm or tell D what differs
| Procedure | Contract D relies on |
|---|---|
| SEEDRANDOM | no inputs |
| GENERATEFOOD | sets FoodX, FoodY **and FoodColor**; never on the snake. D draws it with DRAWFOOD after STARTLEVEL |
| CHECKCOLLISION | B calls it: NewX/NewY in, AL = 1 if wall or body (tail included), else 0 |
| APPLYFOOD | B calls it after moving onto food. Must: add score (UPDATESCORE), call GROWSNAKE (or SHRINKSNAKE), count FoodsInLevel, UPDATELEVEL, new food + DRAWFOOD |
| UPDATESCORE | AX = points -> ScoreValue (DW); raises HighScore (DW) |
| UPDATELEVEL | LevelValue is a **word**; lowers SpeedQ (byte, quarter-ticks), never below SPEEDQ_MIN |
| LOSELIFE | decrements LivesValue (**word**). D checks `LivesValue = 0` itself |
| APPLYDIFFICULTY | AL = 1..3 -> SpeedQ (D uses SPEEDQ_EASY/NORMAL/HARD from 00_header) |

## Notes for A and B
* A: DRAWHUD prints over old digits. REFRESHHUD blacks out x=64..111, y=8..23 (text cols 8-13, rows 1-2) first. If you move the HUD values, change those 4 numbers in REFRESHHUD.
* A: 'DIFFICULTY: ' + 'NORMAL' ends at column 40 and wraps, so the data file uses 'DIFF: '.
* B: nothing to change. RUNGAME relies on GAMEDELAY calling READINPUT, and on QuitFlag.
