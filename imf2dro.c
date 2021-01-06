/*  -------------------------------------------------------------------
 *  This utility converts IMF file to DRO, so you can include it into
 *  my DRO player to play it back on Commodore 64 equipped with SFX
 *  Sound Expander cartridge and YM3812 chip.
 *  Note: I am planning to have IMF player on C64 without this converter too!
 *  -------------------------------------------------------------------
 *  This file is part of the "c64-sfx-cartridge-player" project.
 *  You can access the project site of this source at (with wiki/doc etc too):
 *  https://code.google.com/p/c64-sfx-cartridge-player/
 *  -------------------------------------------------------------------
 *  (C)2011 Gábor Lénárt (LGB) lgb@lgb.hu
 *  License: GNU GPL 2 or 3 (you can choose) or any future later version.
 *  License text (v2): http://www.gnu.org/licenses/gpl-2.0.html
 *  License text (v3): http://www.gnu.org/licenses/gpl-3.0.html
 *  -------------------------------------------------------------------
 *  Compile under UNIX-like systems with gcc:
 *  gcc -o imf2dro imf2dro.c
 *  On windows: I have no idea, try to figure out yourself :)
 *  -------------------------------------------------------------------
 *  Usage (command line):
 *  ./imf2dro 280 inputfile.imf outputfile.dro
 *  The number (280) is just an example, it's the "speed info" which
 *  is not included in the file (it's a major disadvantage of IMF format).
 *  For more info about the IMF format (it also describes what is "speed
 *  info" and what values are used!):
 *  https://code.google.com/p/c64-sfx-cartridge-player/wiki/IMF
 * --------------------------------------------------------------------
 *  IMPORTANT NOTE:
 *  This converter - originally - is written by me to convert IMF files
 *  to be playable with my DRO v2 only player. So I am not sure it's
 *  a good choice for a general IMF->DRO converter. I try my best,
 *  but I only test it with my own player! If you find bugs with the
 *  produced DRO, please tell me!
 *  -------------------------------------------------------------------
 */

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>

#define DEBUG

#define MIN_IMF_FILE_SIZE 6
#define MAX_IMF_FILE_SIZE 60000
#define MAX_DRO_FILE_SIZE 60000

static unsigned char ibuf[MAX_IMF_FILE_SIZE+1],obuf[MAX_DRO_FILE_SIZE];
static int speed;

// DRO specific offsets in the file format:

#define DRO_MAJOR_VER_LO	0x08	// should be: 2
#define DRO_MAJOR_VER_HI	0x09	// should be: 0
#define DRO_MINOR_VER_LO  	0x0A	// should be: 0
#define DRO_MINOR_VER_HI	0x0B	// should be: 0
#define DRO_LENGTH_UINT32LE	0x0C
#define DRO_MS_UINT32LE		0x10
#define DRO_HW_TYPE		0x14	// should be: 0 (OPL2)
#define DRO_FORMAT		0x15	// should be: 0 (interleaved)
#define DRO_COMPRESSION		0x16	// should be: 0 (no compression)
#define DRO_SHORT_DELAY_CODE	0x17	// example: 7A
#define DRO_LONG_DELAY_CODE	0x18	// example: 7B
#define DRO_CODEMAP_LEN		0x19	// example: 7A
#define DRO_CODEMAP_START	0x1A


// │00000000 44 42 52 41 57 4f 50 4c-02 00 00 00 8e 38 00 00 |DBRAWOPL?   ?8  |   ^

/*
 *  For simplicity, we use only DRO v2 (also the C64 player knows
 *  about that _only_), with codemap length of 126. We may waste
 *  some space this way (unused entries in code map table), but
 *  it's much easier to convert this way (max of ~125 is only one
 *  AdLib reg is used, which is abnormal of course). The reason of
 *  our choice: we can use fixed delay codes without the need to
 *  do two-pass conversion.
 *  Also, only OPL2 is supported Dual OPL2 or OPL3 DROs are not generated!
 */

#define CODEMAP_LEN		126
#define CODEMAP_SHORT_DELAY	CODEMAP_LEN
#define CODEMAP_LONG_DELAY	CODEMAP_LEN+1
#define CODEMAP_UNUSED		255

#define SONG_START		DRO_CODEMAP_START+CODEMAP_LEN

static int codemap_allocate ( int reg )
{
	int a;
	for(a=DRO_CODEMAP_START;a<DRO_CODEMAP_START+CODEMAP_LEN;a++)
		if (obuf[a]==reg) {
#			ifdef DEBUG
			printf("CODEMAP: hit for reg %02Xh as codemap entry %02Xh.\n",reg,a-DRO_CODEMAP_START);
#			endif
			return a-DRO_CODEMAP_START;
		} else if (obuf[a]==CODEMAP_UNUSED) {
#			ifdef DEBUG
			printf("CODEMAP: new for reg %02Xh as codemap entry %02Xh.\n",reg,a-DRO_CODEMAP_START);
#			endif
			obuf[a]=reg; // record it!
			return a-DRO_CODEMAP_START;
		}
	fprintf(stderr,"CODEMAP: ERROR: out of codemap space!\n");
	return -1;
}


static void show_hexdump ( int o )
{
	int a;
	if (o<0) {
		printf("     ");
		for(a=0;a<16;a++)
			printf(" %02X",a);
	} else {
		printf("%04X  ",o);
		for(a=o;a<16+o;a++)
			printf("%02X ",obuf[a]);
		putchar(' ');
		for(a=o;a<16+o;a++)
			putchar(obuf[a]>=32&&obuf[a]<127?obuf[a]:'?');
	}
	putchar('\n');
}


static int convert ( int size )
{
	int i,o,ni,no;
	unsigned int msecs=0;
	i=ibuf[0]|(ibuf[1]<<8);
	if (i) { // type-1 IMF file
		if (size<i) {
			fprintf(stderr,"Bad Type-1 IMF file\n");
			return -1;
		}
		size=i; // currently we don't use tag info (etc) in Type-1 files
	} else
		size-=2;
	size&=0xFFFC; // I don't understand :(
	if (size&3) {
		fprintf(stderr,"Bad IMF file: song data length must be multiple of 4, we got %d.\n",size);
		return -1;
	}
	// just to be safe and to avoid the need of setting zero values later,
	// we reset our output buffer
	// which is part of the headers (minus id string) till the codemap table
	memset(obuf+8,0,DRO_CODEMAP_START-8);
	// but we want codemap part to be filled with the 'unused' value
	// so codemap_allocate() will detect it's usable as a new one
	memset(obuf+DRO_CODEMAP_START,CODEMAP_UNUSED,CODEMAP_LEN);
	// DRO id string
	memcpy(obuf,"DBRAWOPL",8);
	// DRO version, major low byte
	obuf[DRO_MAJOR_VER_LO]=2;
	// DRO short delay code
	obuf[DRO_SHORT_DELAY_CODE]=CODEMAP_SHORT_DELAY;
	printf("Short delay command (@$%02X): $%02X\n",DRO_SHORT_DELAY_CODE,CODEMAP_SHORT_DELAY);
	// DRO long delay code
	obuf[DRO_LONG_DELAY_CODE]=CODEMAP_LONG_DELAY;
	printf("Long delay command (@$%02X): $%02X\n",DRO_LONG_DELAY_CODE,CODEMAP_LONG_DELAY);
	// DRO codemap size
	obuf[DRO_CODEMAP_LEN]=CODEMAP_LEN;
	printf("Codemap size (@$%02X): $%02X\n",DRO_CODEMAP_LEN,CODEMAP_LEN);
	// debug ...
	show_hexdump(-1);
	show_hexdump(0);
	show_hexdump(0x10);
	// ok, start the conversion itself
	o=SONG_START;
	printf("SONG START position: $%02X\n",SONG_START);
	i=4; // WHY?!
	ni=0;
	no=0;
	while (i<size+2) {
		int r=codemap_allocate(ibuf[i]);
		int delay=ibuf[i+2]|(ibuf[i+3]<<8);
		ni++;
		if (r<0)
			return -1;
		if (o>=MAX_DRO_FILE_SIZE-6) {
			fprintf(stderr,"Out of DRO space (max size limitation).\n");
			return -1;
		}
		obuf[o++]=r;
		obuf[o++]=ibuf[i+1];
		no++;
		i+=4;
		if (delay>0) {
			// calculate the delay from speed, convert into msecs
			delay=(int)((double)delay*1000.0/(double)speed);
			msecs+=delay;
#			ifdef DEBUG
			printf("Delay (msec): %d (on %d Hz)\n",delay,speed);
#			endif
			if (delay>256) {
				obuf[o++]=CODEMAP_LONG_DELAY;
				obuf[o++]=(delay>>8)-1;
				delay&=0xFF;
				no++;
			}
			if (delay) {
				obuf[o++]=CODEMAP_SHORT_DELAY;
				obuf[o++]=delay-1;
				no++;
			}
		}
	}
	// ok, fix the header with lengths information
	obuf[DRO_LENGTH_UINT32LE]=no&255; // can't be larget than 64K, and high bytes are reset already
	obuf[DRO_LENGTH_UINT32LE+1]=no>>8;
	// well, we don't need this (in my player), but anyway ...
	// here we use all of the 32 bits, since the length of the
	// song can be more than 64K msecs (about one minute)
	obuf[DRO_MS_UINT32LE]=msecs&255;
	obuf[DRO_MS_UINT32LE+1]=(msecs>>8)&255;
	obuf[DRO_MS_UINT32LE+2]=(msecs>>16)&255;
	obuf[DRO_MS_UINT32LE+3]=msecs>>24;
	// some misc printing
	printf("---- END ----\n");
	printf("IP=%d OP=%d NI=%d NO=%d\n",i,o,ni,no);
	// debug ...
	show_hexdump(-1);
	show_hexdump(0);
	show_hexdump(0x10);
	return o;
}




int main ( int argc, char **argv )
{
	int fd,size;
	struct stat st;
	if (argc!=4) {
		fprintf(stderr,"Usage: %s speed inputfile.imf outputfile.dro\n",argv[0]);
		return 1;
	}
	speed=atoi(argv[1]);
	if (speed<100||speed>1000) {
		fprintf(stderr,"Invalid speed value (integer, it must be between 100 and 1000)\n");
		return 1;
	}
	fd=open(argv[2],O_RDONLY);
	if (fd<0) {
		fprintf(stderr,"Cannot open input file: %s\n",argv[2]);
		return 1;
	}
	if (fstat(fd,&st)) {
		close(fd);
		fprintf(stderr,"Cannot stat() input file\n");
		return 1;
	}
	size=st.st_size;
	if (size<MIN_IMF_FILE_SIZE) {
		close(fd);
		fprintf(stderr,"Abnormally short IMF file\n");
		return 1;
	}
	if (size>MAX_IMF_FILE_SIZE) {
		close(fd);
		fprintf(stderr,"Too long IMF size to convert (limit is: %d bytes)\n",MAX_IMF_FILE_SIZE);
		return 1;
	}
	if (read(fd,ibuf,size+1)!=size) { // we try to read size+1, but we except size. Anyway we make buffer larger with one byte not to cause buffer overrun
		close(fd);
		fprintf(stderr,"Input file read error\n");
		return 1;
	}
	close(fd);
	size=convert(size);
	if (size<=0) {
		fprintf(stderr,"Conversion failure\n");
		return 1;
	}
	fd=creat(argv[3],0666);
	if (fd<0) {
		fprintf(stderr,"Cannot create(/truncate) output file: %s\n",argv[3]);
		return 1;
	}
	if (write(fd,obuf,size)!=size) {
		close(fd);
		unlink(argv[3]);
		fprintf(stderr,"Cannot write output file\n");
		return 1;
	}
	close(fd);
	printf("Conversion is OK, output file \"%s\" is written.\n",argv[3]);
	return 0;
}
