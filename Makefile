all: chap06.xex

clean:
	rm *.xex *.lst *.lab 

run: chap06.xex
	atari800 chap06.xex

INCLUDES= ANTIC.asm DOS.asm GTIA.asm OS.asm PIA.asm POKEY.asm

LIBRARIES= lib_screen.asm macros.asm macros_math.asm macros_screen.asm

SOURCES= chap06Memory.asm

MAIN= chap06Main.asm

chap06.xex: ${MAIN} ${SOURCES} ${INCLUDES} ${LIBRARIES}
	mads ${MAIN}  -l -t -o:chap06.xex
	

