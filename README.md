# AGD-Mads
AGD - Using MADS Assembler

Atari Game Development (MADS Assembler Version)

Ported (or parodied depending on opinion) from the book "Retro Game Development - C64 Edition".

The game designs for Atari duplicate the 25 text lines standard with the C64.  The programs leverage the Atari's flexible graphics to optionally provide two extra lines for runtime diagnostics (one line above the normal display, and one line below.)  The diagnostic support can be turned on and off by defining the value DO_DIAG=1.

---

The 6502 is the same between platforms.  Basic logic, math, and such are identical in the programs.  Generally speaking some graphics features are similar:

- The actual bitmap arrangement of data for high-res and multi-color character sets is the same on the C64 as the Atari (Eight bytes per character, one byte/eight bits per each scan line from top to bottom, leftmost bit is the high bit,  or for multi-color fonts the eight bits are divided into four pairs of bits where each bit pair describes one of four color values.)

- The C64 and Atari have corresponding screen resolution modes.  Both can support a one-bit pixel for 320 horizonal pixels on a line, or two-bit pixels for 160 horizontal pixels on a line.

- Text screen memory is linear on both (1000 contiguous characters.)

- Both use the same Atari 2600-compatible digital joysticks with four directional bits corresponding to up, down, left, right, and a bit for Fire.

- Both support fine scrolling text displays. 

More detailed and rigorous use of the hardware features increase the distance of the differences, sometimes significantly:

- The C64 has a 16-color palette and partially uses a color map to apply colors, and partially uses indirection through color registers.  The Atari has a 128-color palette and uses color registers/indirection for everything on the display, and can optionally combine sprite and playfield colors to produce extra colors.  This makes the systems vary in how to apply color, and how much color can be displayed on the same line. 

- The C64 "Sprites" have more horizontal resolution than the Atari's "Player/Missile" graphics which have more vertical resolution.  Both have different memory organization.  Multi-color objects are done differently.

- The C64's VIC-II video chip has four choices of video banks providing fixed memory addresses for text, graphics, and sprites.  The Atari's ANTIC video chip can reference all of the 16-bit address space in the system for playfield displays, and Player/Missile graphics, etc.

- The C64 supports a couple kinds of text displays, and a couple graphics modes. The Atari has 14 basic display modes: six text modes with four kinds of character representation, and eight graphics modes.  The 14 display modes can be presented using four kinds of color interpretation methods. 

- Bitmapped graphics on the C64 uses memory organized like a character set where the Atari uses linear memory for a line of graphics.

- Both systems have 256 characters in a font, though the C64 defines a 2K bitmap for all 256 characters, and the Atari defines a 1K bitmap for 128 characters with the subsequent 128 characters automatically displayed in reverse video.  Character order also differs in the character sets.

- The C64 has three sound voices with automatic volume envelopes where the Atari has four voices.

Therefore, some things just don't always port directly.  The code will be different.  Each computer may require alternate methods to create visually similar results.   Where the C64 uses a sprite, it may make more sense on the Atari to use characters.  On the Atari's side the graphic chip makes it very easy to mix different text and graphics modes without any special 6502 code considerations, where the C64 would require a design compromise, or doing more complicated code to create interrupts to manage the display.

---

[Chapter 6](https://github.com/kenjennings/AGD-Mads/blob/master/chap06_README.md "Chapter 6") 

Create a text display.

---

[Chapter 7](https://github.com/kenjennings/AGD-Mads/blob/master/chap07_README.md "Chapter 7") 

A player-controlled moving object. 

---
