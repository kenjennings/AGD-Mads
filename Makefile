all: chap06.xex chap06Mod.xex

INCLUDES= ANTIC.asm DOS.asm GTIA.asm OS.asm PIA.asm POKEY.asm

LIBRARIES= macros.asm macros_math.asm macros_screen.asm lib_screen.asm

LIBRARIES= macros.asm macros_math.asm macros_screen.asm

SOURCES= chap06Memory.asm chap06lib_screen.asm

MAIN= chap06Main.asm

MAINMOD= chap06MainMod.asm

clean:
	rm *.xex *.lst *.lab 

run: chap06.xex
	atari800 chap06.xex

runmod: chap06mod.xex
	atari800 chap06mod.xex

chap06.xex: ${MAIN} ${SOURCES} ${INCLUDES} ${LIBRARIES}
	mads ${MAIN}  -l -t -o:chap06.xex

chap06mod.xex: ${MAINMOD} ${SOURCES} ${INCLUDES} ${LIBRARIES}
	mads ${MAIN}  -l -t -o:chap06mod.xex

