DRO AdLib OPL2 player for Commodore 64 equipped with SFX Sound Expander
cartridge with YM3812 chip (the "normal" chip this cartridge was shipped
with may work, but since OPL2 features do not exist on those, music will
be somewhat "odd" to listen to).

Uses embedded DRO file, recorded by DOSBOX, currently, there is no
possibility to "load" music on-the-fly, you must recompile the player
with that.

The included DRO file for testing purposes was recorded from the StarPort
BBS intro (from Future Crew) using DOSBOX.

The included MEGA65 version is for MEGA65, and uses direct addressing of
the mapped OPL registers instead of using the normal SFX ones. Still, you
need to load the PRG file in C64 mode though.

Compile: simply say (assuming UNIX-like enivonment, CC65 and GNU make
installed): `make`

Testing:
* Real C64: SFX Sound Expander cartridge with the OPL2 chip (OPL1 - default -
  chip can cause strange sounding)
* C64 emulation: with VICE (SFX Sound Expander cartridge emulation enabled
  with OPL2)
  You can use `make vice` to start the emulator with the right parameters.
* Real MEGA65: as of writing, real MEGA65 has problems with its implemented
  OPL3 (thus OPL2 compatible), simply no sound. This project also aiming to
  give a tool to test MEGA65 in this respect.
  You can use `make mega65` to transfer and start program onto your real
  MEGA65 (if USB connection is present and the right `m65` tool is working).
  MEGA65 issue ticket: https://github.com/MEGA65/mega65-core/issues/232
* MEGA65 emulation: Xemu/MEGA65
  (note: there can be some glitches due to the suboptimal method how Xemu
  emulates sound currently in terms of timing).
  You can use `make xemu` to start the emulator with the program loaded.
  More on Xemu:
  https://github.lgb.hu/xemu/  https://github.com/lgblgblgb/xemu

(C)2011,2020-2021 LGB (Gábor Lénárt) lgb@lgb.hu, this program can be used
according to the GNU/GPL 2 or 3 (or later, if a new one is released) license.
License: http://www.gnu.org/licenses/gpl-2.0.html
License: http://www.gnu.org/licenses/gpl-3.0.html
Personal note: PLEASE drop me a mail if you have ideas to modify
this program (patches, bugs, features etc) or if you use it in your work,
as the GPL defines, you should provide the source of your work then
too as it must be GPL then. Thanks! Of course any feedback is welcome, anyway.
