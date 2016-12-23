/*
  Name:         Zeta
  Description:  Experimental chess engine written in OpenCL.
  Author:       Srdja Matovic <s.matovic@app26.de>
  Created at:   2011-01-15
  Updated at:   2016
  License:      GPL >= v2

  Copyright (C) 2011-2016 Srdja Matovic

  Zeta is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 2 of the License, or
  (at your option) any later version.

  Zeta is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.
*/

// mandatory extensions
#pragma OPENCL EXTENSION cl_khr_local_int32_base_atomics        : enable
#pragma OPENCL EXTENSION cl_khr_local_int32_extended_atomics    : enable
//#pragma OPENCL EXTENSION cl_khr_int64_base_atomics              : enable
#pragma OPENCL EXTENSION cl_khr_int64_extended_atomics          : enable
// deprecated
//#pragma OPENCL EXTENSION cl_khr_global_int32_base_atomics       : enable
//#pragma OPENCL EXTENSION cl_khr_global_int32_extended_atomics   : enable
// otpional
//#pragma OPENCL EXTENSION cl_khr_byte_addressable_store          : enable

typedef ulong   u64;
typedef uint    u32;
typedef int     s32;
typedef short   s16;
typedef uchar    u8;
typedef char     s8;

typedef u32     TTMove;
typedef s32     Score;
typedef s16     TTScore;
typedef u8      Square;
typedef u8      Piece;

typedef u64     Cr;
typedef u64     Move;
typedef u64     Bitboard;
typedef u64     Hash;

// transposition table entry
typedef struct
{
  Hash hash;
  TTMove bestmove;
  TTScore score;
  u8 flag;
  u8 depth;
} TTE;
// TT node type flags
#define FAILLOW         0
#define EXACTSCORE      1
#define FAILHIGH        2
// search modes
#define INIT            0
#define MOVEUP          1
#define MOVEDOWN        2
#define EXIT            3
// defaults
#define VERSION "099a"
// quad bitboard array index definition
#define QBBBLACK  0     // pieces white
#define QBBP1     1     // piece type first bit
#define QBBP2     2     // piece type second bit
#define QBBP3     3     // piece type third bit
#define QBBPMVD   4     // piece moved flags, for castle rights
#define QBBHASH   5     // 64 bit board Zobrist hash
#define QBBLAST   6     // lastmove + ep target + halfmove clock + move score
/* move encoding 
   0  -  5  square from
   6  - 11  square to
  12  - 17  square capture
  18  - 21  piece from
  22  - 25  piece to
  26  - 29  piece capture
  30  - 35  square en passant target
  36        move is castle kingside
  37        move is castle queenside
  38  - 39  2 bit free
  40  - 47  halfmove clock for fity move rule, last capture/castle/pawn move
  48  - 63  move score, signed 16 bit
*/
// engine defaults
#define MAXPLY              64      // max internal search ply
#define MAXGAMEPLY          1024    // max ply a game can reach
#define MAXMOVES            256     // max amount of legal moves per position
// colors
#define BLACK               1
#define WHITE               0
// score indexing
#define ALPHA               0
#define BETA                1
// scores
#define INF                 1000000000
#define MATESCORE            999000000
#define DRAWSCORE           0
#define STALEMATESCORE      0
// piece type enumeration
#define PNONE               0
#define PAWN                1
#define KNIGHT              2
#define KING                3
#define BISHOP              4
#define ROOK                5
#define QUEEN               6
// move is castle flag
#define MOVEISCR            0x0000003000000000UL
#define MOVEISCRK           0x0000001000000000UL
#define MOVEISCRQ           0x0000002000000000UL
// bitboard masks, computation prefered over lookup
#define SETMASKBB(sq)       (1UL<<(sq))
#define CLRMASKBB(sq)       (~(1UL<<(sq)))
// u64 defaults
#define BBEMPTY             0x0000000000000000UL
#define BBFULL              0xFFFFFFFFFFFFFFFFUL
#define MOVENONE            0x0000000000000000UL
#define HASHNONE            0x0000000000000000UL
#define CRNONE              0x0000000000000000UL
#define SCORENONE           0x0000000000000000UL
// set masks
#define SMMOVE              0x0000003FFFFFFFFFUL
#define SMSQEP              0x0000000FC0000000UL
#define SMHMC               0x0000FF0000000000UL
#define SMCRALL             0x8900000000000091UL
#define SMSCORE             0xFFFF000000000000UL
#define SMTTMOVE            0x000000003FFFFFFFUL
// clear masks
#define CMMOVE              0xFFFFFFC000000000UL
#define CMSQEP              0xFFFFFFF03FFFFFFFUL
#define CMHMC               0xFFFF00FFFFFFFFFFUL
#define CMCRALL             0x76FFFFFFFFFFFF6EUL
#define CMSCORE             0x0000FFFFFFFFFFFFUL
#define CMTTMOVE            0xFFFFFFFFC0000000UL
// castle right masks
#define SMCRWHITE           0x0000000000000091UL
#define SMCRWHITEQ          0x0000000000000011UL
#define SMCRWHITEK          0x0000000000000090UL
#define SMCRBLACK           0x9100000000000000UL
#define SMCRBLACKQ          0x1100000000000000UL
#define SMCRBLACKK          0x9000000000000000UL
// move helpers
#define MAKEPIECE(p,c)     ((((Piece)p)<<1)|(Piece)c)
#define JUSTMOVE(move)     (move&SMTTMOVE)
#define GETCOLOR(p)        ((p)&0x1)
#define GETPTYPE(p)        (((p)>>1)&0x7)      // 3 bit piece type encoding
#define GETSQFROM(mv)      ((mv)&0x3F)         // 6 bit square
#define GETSQTO(mv)        (((mv)>>6)&0x3F)    // 6 bit square
#define GETSQCPT(mv)       (((mv)>>12)&0x3F)   // 6 bit square
#define GETPFROM(mv)       (((mv)>>18)&0xF)    // 4 bit piece encoding
#define GETPTO(mv)         (((mv)>>22)&0xF)    // 4 bit piece encoding
#define GETPCPT(mv)        (((mv)>>26)&0xF)    // 4 bit piece encodinge
#define GETSQEP(mv)        (((mv)>>30)&0x3F)   // 6 bit square
#define SETSQEP(mv,sq)     (((mv)&CMSQEP)|(((sq)&0x3F)<<30))
#define GETHMC(mv)         (((mv)>>40)&0xFF)   // 8 bit halfmove clock
#define SETHMC(mv,hmc)     (((mv)&CMHMC)|(((hmc)&0xFF)<<40))
#define GETSCORE(mv)       (((mv)>>48)&0xFFFF) // signed 16 bit move score
#define SETSCORE(mv,score) (((mv)&CMSCORE)|(((score)&0xFFFF)<<48)) 
// pack move into 64 bits
#define MAKEMOVE(sqfrom, sqto, sqcpt, pfrom, pto, pcpt, sqep, hmc, score) \
( \
     sqfrom      | (sqto<<6)  | (sqcpt<<12) \
  | (pfrom<<18)  | (pto<<22)  | (pcpt<<26) \
  | (sqep<<30)   | (hmc<<40)  | (score<<48) \
)
// square helpers
#define MAKESQ(file,rank)   ((rank)<<3|(file))
#define GETRANK(sq)         ((sq)>>3)
#define GETFILE(sq)         ((sq)&7)
#define GETRRANK(sq,color)  ((color)?(((sq)>>3)^7):((sq)>>3))
#define FLIP(sq)            ((sq)^7)
#define FLOP(sq)            ((sq)^56)
#define FLIPFLOP(sq)        (((sq)^56)^7)
// piece helpers
#define GETPIECE(board,sq)  ( \
                               ((board[0]>>(sq))&0x1)\
                           |  (((board[1]>>(sq))&0x1)<<1) \
                           |  (((board[2]>>(sq))&0x1)<<2) \
                           |  (((board[3]>>(sq))&0x1)<<3) \
                             )
#define GETPIECETYPE(board,sq) ( \
                              (((board[1]>>(sq))&0x1)) \
                           |  (((board[2]>>(sq))&0x1)<<1) \
                           |  (((board[3]>>(sq))&0x1)<<2) \
                             )
// file enumeration
enum Files
{
  FILE_A, FILE_B, FILE_C, FILE_D, FILE_E, FILE_F, FILE_G, FILE_H, FILE_NONE
};
#define BBFILEA             0x0101010101010101UL
#define BBFILEB             0x0202020202020202UL
#define BBFILEC             0x0404040404040404UL
#define BBFILED             0x0808080808080808UL
#define BBFILEE             0x1010101010101010UL
#define BBFILEF             0x2020202020202020UL
#define BBFILEG             0x4040404040404040UL
#define BBFILEH             0x8080808080808080UL
#define BBNOTHFILE          0x7F7F7F7F7F7F7F7FUL
#define BBNOTAFILE          0xFEFEFEFEFEFEFEFEUL
// rank enumeration
enum Ranks
{
  RANK_1, RANK_2, RANK_3, RANK_4, RANK_5, RANK_6, RANK_7, RANK_8, RANK_NONE
};
#define BBRANK7             0x00FF000000000000UL
#define BBRANK5             0x000000FF00000000UL
#define BBRANK4             0x00000000FF000000UL
#define BBRANK2             0x000000000000FF00UL
// square enumeration
enum Squares
{
  SQ_A1, SQ_B1, SQ_C1, SQ_D1, SQ_E1, SQ_F1, SQ_G1, SQ_H1,
  SQ_A2, SQ_B2, SQ_C2, SQ_D2, SQ_E2, SQ_F2, SQ_G2, SQ_H2,
  SQ_A3, SQ_B3, SQ_C3, SQ_D3, SQ_E3, SQ_F3, SQ_G3, SQ_H3,
  SQ_A4, SQ_B4, SQ_C4, SQ_D4, SQ_E4, SQ_F4, SQ_G4, SQ_H4,
  SQ_A5, SQ_B5, SQ_C5, SQ_D5, SQ_E5, SQ_F5, SQ_G5, SQ_H5,
  SQ_A6, SQ_B6, SQ_C6, SQ_D6, SQ_E6, SQ_F6, SQ_G6, SQ_H6,
  SQ_A7, SQ_B7, SQ_C7, SQ_D7, SQ_E7, SQ_F7, SQ_G7, SQ_H7,
  SQ_A8, SQ_B8, SQ_C8, SQ_D8, SQ_E8, SQ_F8, SQ_G8, SQ_H8
};
// is score a mate in n
#define ISMATE(val)           ((((val)>MATESCORE&&(val)<INF)||((val)<-MATESCORE&&(val)>-INF))?true:false)
// is score default inf
#define ISINF(val)            (((val)==INF||(val)==-INF)?true:false)
// tuneable search parameter
#define MAXEVASIONSDEPTH     3               // max check evasions from qsearch
#define SMOOTHUCT            1.00           // factor for uct params in select formula
#define SKIPMATE             1             // 0 or 1
#define SKIPDRAW             1            // 0 or 1
#define INCHECKEXT           1           // 0 or 1
#define SINGLEEXT            1          // 0 or 1
#define PROMOEXT             1         // 0 or 1
#define ROOTSEARCH           1        // 0 or 1, distribute root nodes equaly in select phase
#define SCOREWEIGHT          0.42    // factor for board score in select formula
#define BROADWELL            1      // 0 or 1, will apply bf select formula
#define DEPTHWELL            32    // 0 to totalThreads, every nth thread will search depth wise
#define MAXBFPLY             128  // max ply of bf search tree
// functions
Score EvalMove(Move move);
// rotate left based zobrist hashing
__constant Hash Zobrist[17]=
{
  0x9D39247E33776D41, 0x2AF7398005AAA5C7, 0x44DB015024623547, 0x9C15F73E62A76AE2,
  0x75834465489C0C89, 0x3290AC3A203001BF, 0x0FBBAD1F61042279, 0xE83A908FF2FB60CA,
  0x0D7E765D58755C10, 0x1A083822CEAFE02D, 0x9605D5F0E25EC3B0, 0xD021FF5CD13A2ED5,
  0x40BDF15D4A672E32, 0x011355146FD56395, 0x5DB4832046F3D9E5, 0x239F8B2D7FF719CC,
  0x05D1A1AE85B49AA1
};

//  piece square tables based on proposal by Tomasz Michniewski
//  https://chessprogramming.wikispaces.com/Simplified+evaluation+function


// piece values
// pnone, pawn, knight, king, bishop, rook, queen
//__constant Score EvalPieceValues[7] = {0, 100, 300, 0, 300, 500, 900};
__constant Score EvalPieceValues[7] = {0, 100, 400, 0, 400, 600, 1200};
// square control bonus, black view
// flop square for white-index: sq^56
__constant Score EvalControl[64] =
{
    0,  0,  5,  5,  5,  5,  0,  0,
    5,  0,  5,  5,  5,  5,  0,  5,
    0,  0, 10,  5,  5, 10,  0,  0,
    0,  5,  5, 10, 10,  5,  5,  0,
    0,  5,  5, 10, 10,  5,  5,  0,
    0,  0, 10,  5,  5, 10,  0,  0,
    0,  0,  5,  5,  5,  5,  0,  0,
    0,  0,  5,  5,  5,  5,  0,  0
};
// piece square tables, black view
// flop square for white-index: sq^56
__constant Score EvalTable[7*64] =
{
    // piece none 
    0,  0,  0,  0,  0,  0,  0,  0,
    0,  0,  0,  0,  0,  0,  0,  0,
    0,  0,  0,  0,  0,  0,  0,  0,
    0,  0,  0,  0,  0,  0,  0,  0,
    0,  0,  0,  0,  0,  0,  0,  0,
    0,  0,  0,  0,  0,  0,  0,  0,
    0,  0,  0,  0,  0,  0,  0,  0,
    0,  0,  0,  0,  0,  0,  0,  0,

    // pawn
    0,  0,  0,  0,  0,  0,  0,  0,
   50, 50, 50, 50, 50, 50, 50, 50,
   30, 30, 30, 30, 30, 30, 30, 30,
    5,  5,  5, 10, 10,  5,  5,  5,
    3,  3,  3,  8,  8,  3,  3,  3,
    2,  2,  2,  2,  2,  2,  2,  2,
    0,  0,  0, -5, -5,  0,  0,  0,
    0,  0,  0,  0,  0,  0,  0,  0,

     // knight
  -50,-40,-30,-30,-30,-30,-40,-50,
  -40,-20,  0,  0,  0,  0,-20,-40,
  -30,  0, 10, 15, 15, 10,  0,-30,
  -30,  5, 15, 20, 20, 15,  5,-30,
  -30,  0, 15, 20, 20, 15,  0,-30,
  -30,  5, 10, 15, 15, 10,  5,-30,
  -40,-20, 0,   5,  5,  0,-20,-40,
  -50,-40,-30,-30,-30,-30,-40,-50,

    // king 
   -1, -1, -1, -1, -1, -1, -1, -1,
   -1,  0,  0,  0,  0,  0,  0, -1,
   -1,  0,  0,  0,  0,  0,  0, -1,
   -1,  0,  0,  0,  0,  0,  0, -1,
   -1,  0,  0,  0,  0,  0,  0, -1,
   -1,  0,  0,  0,  0,  0,  0, -1,
   -1,  0,  0,  0,  0,  0,  0, -1,
   -1, -1, -1, -1, -1, -1, -1, -1,

    // bishop
  -20,-10,-10,-10,-10,-10,-10,-20,
  -10,  0,  0,  0,  0,  0,  0,-10,
  -10,  0,  5, 10, 10,  5,  0,-10,
  -10,  5,  5, 10, 10,  5,  5,-10,
  -10,  0, 10, 10, 10, 10,  0,-10,
  -10, 10, 10, 10, 10, 10, 10,-10,
  -10,  5,  0,  0,  0,  0,  5,-10,
  -20,-10,-10,-10,-10,-10,-10,-20,

    // rook
    0,  0,  0,  0,  0,  0,  0,  0,
    5, 10, 10, 10, 10, 10, 10,  5,
   -5,  0,  0,  0,  0,  0,  0, -5,
   -5,  0,  0,  0,  0,  0,  0, -5,
   -5,  0,  0,  0,  0,  0,  0, -5,
   -5,  0,  0,  0,  0,  0,  0, -5,
   -5,  0,  0,  0,  0,  0,  0, -5,
    0,  0,  0,  5,  5,  0,  0,  0,

    // queen
  -20,-10,-10, -5, -5,-10,-10,-20,
  -10,  0,  0,  0,  0,  0,  0,-10,
  -10,  0,  5,  5,  5,  5,  0,-10,
   -5,  0,  5,  5,  5,  5,  0, -5,
   -5,  0,  5,  5,  5 , 5 , 0, -5,
  -10,  0,  5,  5,  5,  5,  0,-10,
  -10,  0,  0,  0,  0 , 0 , 0,-10,
  -20,-10,-10, -5, -5,-10,-10,-20
};
// OpenCL 1.2 has popcount function
#if __OPENCL_VERSION__ < 120
// population count, Donald Knuth SWAR style
// as described on CWP
// http://chessprogramming.wikispaces.com/Population+Count#SWAR-Popcount
u8 count1s(u64 x) 
{
  x =  x                        - ((x >> 1)  & 0x5555555555555555);
  x = (x & 0x3333333333333333)  + ((x >> 2)  & 0x3333333333333333);
  x = (x                        +  (x >> 4)) & 0x0f0f0f0f0f0f0f0f;
  x = (x * 0x0101010101010101) >> 56;
  return (u8)x;
}
#else
// wrapper for casting
u8 count1s(u64 x) 
{
  return (u8)popcount(x);
}
#endif
//  pre condition: x != 0;
u8 first1(u64 x)
{
  return count1s((x&-x)-1);
}
//  pre condition: x != 0;
u8 popfirst1(u64 *a)
{
  u64 b = *a;
  *a &= (*a-1);  // clear lsb 
  return count1s((b&-b)-1); // return pop count of isolated lsb
}
// bit twiddling hacks
//  bb_work=bb_temp&-bb_temp;  // get lsb 
//  bb_temp&=bb_temp-1;       // clear lsb

// apply move on board, quick during move generation
void domovequick(Bitboard *board, Move move)
{
  Square sqfrom   = GETSQFROM(move);
  Square sqto     = GETSQTO(move);
  Square sqcpt    = GETSQCPT(move);
  Bitboard pto    = GETPTO(move);
  Bitboard bbTemp = BBEMPTY;

  // check for edges
  if (move==MOVENONE)
    return;

  // unset square from, square capture and square to
  bbTemp = CLRMASKBB(sqfrom)&CLRMASKBB(sqcpt)&CLRMASKBB(sqto);
  board[QBBBLACK] &= bbTemp;
  board[QBBP1]    &= bbTemp;
  board[QBBP2]    &= bbTemp;
  board[QBBP3]    &= bbTemp;

  // set piece to
  board[QBBBLACK] |= (pto&0x1)<<sqto;
  board[QBBP1]    |= ((pto>>1)&0x1)<<sqto;
  board[QBBP2]    |= ((pto>>2)&0x1)<<sqto;
  board[QBBP3]    |= ((pto>>3)&0x1)<<sqto;
}
// restore board again, quick during move generation
void undomovequick(Bitboard *board, Move move)
{
  Square sqfrom   = GETSQFROM(move);
  Square sqto     = GETSQTO(move);
  Square sqcpt    = GETSQCPT(move);
  Bitboard pfrom  = GETPFROM(move);
  Bitboard pcpt   = GETPCPT(move);
  Bitboard bbTemp = BBEMPTY;

  // check for edges
  if (move==MOVENONE)
    return;

  // unset square capture, square to
  bbTemp = CLRMASKBB(sqcpt)&CLRMASKBB(sqto);
  board[QBBBLACK] &= bbTemp;
  board[QBBP1]    &= bbTemp;
  board[QBBP2]    &= bbTemp;
  board[QBBP3]    &= bbTemp;

  // restore piece capture
  board[QBBBLACK] |= (pcpt&0x1)<<sqcpt;
  board[QBBP1]    |= ((pcpt>>1)&0x1)<<sqcpt;
  board[QBBP2]    |= ((pcpt>>2)&0x1)<<sqcpt;
  board[QBBP3]    |= ((pcpt>>3)&0x1)<<sqcpt;

  // restore piece from
  board[QBBBLACK] |= (pfrom&0x1)<<sqfrom;
  board[QBBP1]    |= ((pfrom>>1)&0x1)<<sqfrom;
  board[QBBP2]    |= ((pfrom>>2)&0x1)<<sqfrom;
  board[QBBP3]    |= ((pfrom>>3)&0x1)<<sqfrom;
}
// apply move on board
void domove(Bitboard *board, Move move)
{
  Square sqfrom   = GETSQFROM(move);
  Square sqto     = GETSQTO(move);
  Square sqcpt    = GETSQCPT(move);
  Bitboard pfrom  = GETPFROM(move);
  Bitboard pto    = GETPTO(move);
  Bitboard pcpt   = GETPCPT(move);
  Bitboard bbTemp = BBEMPTY;
  Bitboard pcastle= PNONE;
  u64 hmc         = GETHMC(board[QBBLAST]);
  Hash zobrist;

  // check for edges
  if (move==MOVENONE)
    return;

  // increase half move clock
  hmc++;

  // do hash increment , clear old 
  // castle rights
  if(((~board[QBBPMVD])&SMCRWHITEK)==SMCRWHITEK)
    board[QBBHASH] ^= Zobrist[12];
  if(((~board[QBBPMVD])&SMCRWHITEQ)==SMCRWHITEQ)
    board[QBBHASH] ^= Zobrist[13];
  if(((~board[QBBPMVD])&SMCRBLACKK)==SMCRBLACKK)
    board[QBBHASH] ^= Zobrist[14];
  if(((~board[QBBPMVD])&SMCRBLACKQ)==SMCRBLACKQ)
    board[QBBHASH] ^= Zobrist[15];

  // file en passant
  if (GETSQEP(board[QBBLAST]))
  {
    zobrist = Zobrist[16];
    board[QBBHASH] ^= ((zobrist<<GETFILE(GETSQEP(board[QBBLAST])))|(zobrist>>(64-GETFILE(GETSQEP(board[QBBLAST])))));; // rotate left 64
  }

  // unset square from, square capture and square to
  bbTemp = CLRMASKBB(sqfrom)&CLRMASKBB(sqcpt)&CLRMASKBB(sqto);
  board[QBBBLACK] &= bbTemp;
  board[QBBP1]    &= bbTemp;
  board[QBBP2]    &= bbTemp;
  board[QBBP3]    &= bbTemp;

  // set piece to
  board[QBBBLACK] |= (pto&0x1)<<sqto;
  board[QBBP1]    |= ((pto>>1)&0x1)<<sqto;
  board[QBBP2]    |= ((pto>>2)&0x1)<<sqto;
  board[QBBP3]    |= ((pto>>3)&0x1)<<sqto;

  // set piece moved flag, for castle rights
  board[QBBPMVD]  |= SETMASKBB(sqfrom);
  board[QBBPMVD]  |= SETMASKBB(sqto);
  board[QBBPMVD]  |= SETMASKBB(sqcpt);

  // handle castle rook, queenside
  pcastle = (move&MOVEISCRQ)?MAKEPIECE(ROOK,GETCOLOR(pfrom)):PNONE;
  // unset castle rook from
  bbTemp  = (move&MOVEISCRQ)?CLRMASKBB(sqfrom-4):BBFULL;
  board[QBBBLACK] &= bbTemp;
  board[QBBP1]    &= bbTemp;
  board[QBBP2]    &= bbTemp;
  board[QBBP3]    &= bbTemp;
  // set castle rook to
  board[QBBBLACK] |= (pcastle&0x1)<<(sqto+1);
  board[QBBP1]    |= ((pcastle>>1)&0x1)<<(sqto+1);
  board[QBBP2]    |= ((pcastle>>2)&0x1)<<(sqto+1);
  board[QBBP3]    |= ((pcastle>>3)&0x1)<<(sqto+1);
  // set piece moved flag, for castle rights
  board[QBBPMVD]  |= (pcastle)?SETMASKBB(sqfrom-4):BBEMPTY;
  // reset halfmoveclok
  hmc = (pcastle)?0:hmc;  // castle move
  // do hash increment, clear old rook
  zobrist = Zobrist[GETCOLOR(pcastle)*6+ROOK-1];
  board[QBBHASH] ^= (pcastle)?((zobrist<<(sqfrom-4))|(zobrist>>(64-(sqfrom-4)))):BBEMPTY;
  // do hash increment, set new rook
  board[QBBHASH] ^= (pcastle)?((zobrist<<(sqto+1))|(zobrist>>(64-(sqto+1)))):BBEMPTY;

  // handle castle rook, kingside
  pcastle = (move&MOVEISCRK)?MAKEPIECE(ROOK,GETCOLOR(pfrom)):PNONE;
  // unset castle rook from
  bbTemp  = (move&MOVEISCRK)?CLRMASKBB(sqfrom+3):BBFULL;
  board[QBBBLACK] &= bbTemp;
  board[QBBP1]    &= bbTemp;
  board[QBBP2]    &= bbTemp;
  board[QBBP3]    &= bbTemp;
  // set castle rook to
  board[QBBBLACK] |= (pcastle&0x1)<<(sqto-1);
  board[QBBP1]    |= ((pcastle>>1)&0x1)<<(sqto-1);
  board[QBBP2]    |= ((pcastle>>2)&0x1)<<(sqto-1);
  board[QBBP3]    |= ((pcastle>>3)&0x1)<<(sqto-1);
  // set piece moved flag, for castle rights
  board[QBBPMVD]  |= (pcastle)?SETMASKBB(sqfrom+3):BBEMPTY;
  // reset halfmoveclok
  hmc = (pcastle)?0:hmc;  // castle move
  // do hash increment, clear old rook
  board[QBBHASH] ^= (pcastle)?((zobrist<<(sqfrom+3))|(zobrist>>(64-(sqfrom+3)))):BBEMPTY;
  // do hash increment, set new rook
  board[QBBHASH] ^= (pcastle)?((zobrist<<(sqto-1))|(zobrist>>(64-(sqto-1)))):BBEMPTY;

  // handle halfmove clock
  hmc = (GETPTYPE(pfrom)==PAWN)?0:hmc;   // pawn move
  hmc = (GETPTYPE(pcpt)!=PNONE)?0:hmc;  // capture move

  // do hash increment , set new
  // do hash increment, clear piece from
  zobrist = Zobrist[GETCOLOR(pfrom)*6+GETPTYPE(pfrom)-1];
  board[QBBHASH] ^= ((zobrist<<(sqfrom))|(zobrist>>(64-(sqfrom))));
  // do hash increment, set piece to
  zobrist = Zobrist[GETCOLOR(pto)*6+GETPTYPE(pto)-1];
  board[QBBHASH] ^= ((zobrist<<(sqto))|(zobrist>>(64-(sqto))));
  // do hash increment, clear piece capture
  zobrist = Zobrist[GETCOLOR(pcpt)*6+GETPTYPE(pcpt)-1];
  board[QBBHASH] ^= (pcpt)?((zobrist<<(sqcpt))|(zobrist>>(64-(sqcpt)))):BBEMPTY;
  // castle rights
  if(((~board[QBBPMVD])&SMCRWHITEK)==SMCRWHITEK)
    board[QBBHASH] ^= Zobrist[12];
  if(((~board[QBBPMVD])&SMCRWHITEQ)==SMCRWHITEQ)
    board[QBBHASH] ^= Zobrist[13];
  if(((~board[QBBPMVD])&SMCRBLACKK)==SMCRBLACKK)
    board[QBBHASH] ^= Zobrist[14];
  if(((~board[QBBPMVD])&SMCRBLACKQ)==SMCRBLACKQ)
    board[QBBHASH] ^= Zobrist[15];
 
  // file en passant
  if (GETSQEP(move))
  {
    zobrist = Zobrist[16];
    board[QBBHASH] ^= ((zobrist<<GETFILE(GETSQEP(move)))|(zobrist>>(64-GETFILE(GETSQEP(move)))));; // rotate left 64
  }

  // color flipping
  board[QBBHASH] ^= 0x1;

  // store hmc   
  move = SETHMC(move, hmc);
  // store lastmove in board
  board[QBBLAST] = move;
}
// restore board again
void undomove(Bitboard *board, Move move, Move lastmove, Cr cr, Hash hash)
{
  Square sqfrom   = GETSQFROM(move);
  Square sqto     = GETSQTO(move);
  Square sqcpt    = GETSQCPT(move);
  Bitboard pfrom  = GETPFROM(move);
  Bitboard pcpt   = GETPCPT(move);
  Bitboard bbTemp = BBEMPTY;
  Bitboard pcastle= PNONE;

  // check for edges
  if (move==MOVENONE)
    return;

  // restore lastmove with hmc and cr
  board[QBBLAST] = lastmove;
  // restore castle rights. via piece moved flags
  board[QBBPMVD] = cr;
  // restore hash
  board[QBBHASH] = hash;

  // unset square capture, square to
  bbTemp = CLRMASKBB(sqcpt)&CLRMASKBB(sqto);
  board[QBBBLACK] &= bbTemp;
  board[QBBP1]    &= bbTemp;
  board[QBBP2]    &= bbTemp;
  board[QBBP3]    &= bbTemp;

  // restore piece capture
  board[QBBBLACK] |= (pcpt&0x1)<<sqcpt;
  board[QBBP1]    |= ((pcpt>>1)&0x1)<<sqcpt;
  board[QBBP2]    |= ((pcpt>>2)&0x1)<<sqcpt;
  board[QBBP3]    |= ((pcpt>>3)&0x1)<<sqcpt;

  // restore piece from
  board[QBBBLACK] |= (pfrom&0x1)<<sqfrom;
  board[QBBP1]    |= ((pfrom>>1)&0x1)<<sqfrom;
  board[QBBP2]    |= ((pfrom>>2)&0x1)<<sqfrom;
  board[QBBP3]    |= ((pfrom>>3)&0x1)<<sqfrom;

  // handle castle rook, queenside
  pcastle = (move&MOVEISCRQ)?MAKEPIECE(ROOK,GETCOLOR(pfrom)):PNONE;
  // unset castle rook to
  bbTemp  = (move&MOVEISCRQ)?CLRMASKBB(sqto+1):BBFULL;
  board[QBBBLACK] &= bbTemp;
  board[QBBP1]    &= bbTemp;
  board[QBBP2]    &= bbTemp;
  board[QBBP3]    &= bbTemp;
  // restore castle rook from
  board[QBBBLACK] |= (pcastle&0x1)<<(sqfrom-4);
  board[QBBP1]    |= ((pcastle>>1)&0x1)<<(sqfrom-4);
  board[QBBP2]    |= ((pcastle>>2)&0x1)<<(sqfrom-4);
  board[QBBP3]    |= ((pcastle>>3)&0x1)<<(sqfrom-4);
  // handle castle rook, kingside
  pcastle = (move&MOVEISCRK)?MAKEPIECE(ROOK,GETCOLOR(pfrom)):PNONE;
  // restore castle rook from
  bbTemp  = (move&MOVEISCRK)?CLRMASKBB(sqto-1):BBFULL;
  board[QBBBLACK] &= bbTemp;
  board[QBBP1]    &= bbTemp;
  board[QBBP2]    &= bbTemp;
  board[QBBP3]    &= bbTemp;
  // set castle rook to
  board[QBBBLACK] |= (pcastle&0x1)<<(sqfrom+3);
  board[QBBP1]    |= ((pcastle>>1)&0x1)<<(sqfrom+3);
  board[QBBP2]    |= ((pcastle>>2)&0x1)<<(sqfrom+3);
  board[QBBP3]    |= ((pcastle>>3)&0x1)<<(sqfrom+3);
}
Hash computehash(__private Bitboard *board, bool stm)
{
  Piece piece;
  Bitboard bbWork;
  Square sq;
  Hash hash = HASHNONE;
  Hash zobrist;
  u8 side;

  // for each color
  for (side=WHITE;side<=BLACK;side++)
  {
    bbWork = (side==BLACK)?board[QBBBLACK]:(board[QBBBLACK]^(board[QBBP1]|board[QBBP2]|board[QBBP3]));
    // for each piece
    while(bbWork)
    {
      sq    = popfirst1(&bbWork);
      piece = GETPIECE(board,sq);
      zobrist = Zobrist[GETCOLOR(piece)*6+GETPTYPE(piece)-1];
      hash ^= ((zobrist<<sq)|(zobrist>>(64-sq)));; // rotate left 64
    }
  }
  // castle rights
  if (((~board[QBBPMVD])&SMCRWHITEK)==SMCRWHITEK)
      hash ^= Zobrist[12];
  if (((~board[QBBPMVD])&SMCRWHITEQ)==SMCRWHITEQ)
      hash ^= Zobrist[13];
  if (((~board[QBBPMVD])&SMCRBLACKK)==SMCRBLACKK)
      hash ^= Zobrist[14];
  if (((~board[QBBPMVD])&SMCRBLACKQ)==SMCRBLACKQ)
      hash ^= Zobrist[15];
 
  // file en passant
  if (GETSQEP(board[QBBLAST]))
  {
    sq = GETFILE(GETSQEP(board[QBBLAST]));
    zobrist = Zobrist[16];
    hash ^= ((zobrist<<sq)|(zobrist>>(64-sq)));; // rotate left 64
  }
 
  // site to move
  if (!stm)
    hash ^= 0x1;

  return hash;
}
// move generator costants
__constant ulong4 shift4 = (ulong4)( 9, 1, 7, 8);

// wraps for kogge stone shifts
__constant ulong4 wraps4[2] =
{
  // wraps shift left
  (ulong4)(
            0xfefefefefefefe00, // <<9
            0xfefefefefefefefe, // <<1
            0x7f7f7f7f7f7f7f00, // <<7
            0xffffffffffffff00  // <<8
          ),

  // wraps shift right
  (ulong4)(
            0x007f7f7f7f7f7f7f, // >>9
            0x7f7f7f7f7f7f7f7f, // >>1
            0x00fefefefefefefe, // >>7
            0x00ffffffffffffff  // >>8
          )
};
// precomputed attack tables for move generation and square in check
__constant Bitboard AttackTablesPawnPushes[2*64] = 
{
  // white pawn pushes
  0x100,0x200,0x400,0x800,0x1000,0x2000,0x4000,0x8000,0x1010000,0x2020000,0x4040000,0x8080000,0x10100000,0x20200000,0x40400000,0x80800000,0x1000000,0x2000000,0x4000000,0x8000000,0x10000000,0x20000000,0x40000000,0x80000000,0x100000000,0x200000000,0x400000000,0x800000000,0x1000000000,0x2000000000,0x4000000000,0x8000000000,0x10000000000,0x20000000000,0x40000000000,0x80000000000,0x100000000000,0x200000000000,0x400000000000,0x800000000000,0x1000000000000,0x2000000000000,0x4000000000000,0x8000000000000,0x10000000000000,0x20000000000000,0x40000000000000,0x80000000000000,0x100000000000000,0x200000000000000,0x400000000000000,0x800000000000000,0x1000000000000000,0x2000000000000000,0x4000000000000000,0x8000000000000000,0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x0,
  // black pawn pushes
  0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x1,0x2,0x4,0x8,0x10,0x20,0x40,0x80,0x100,0x200,0x400,0x800,0x1000,0x2000,0x4000,0x8000,0x10000,0x20000,0x40000,0x80000,0x100000,0x200000,0x400000,0x800000,0x1000000,0x2000000,0x4000000,0x8000000,0x10000000,0x20000000,0x40000000,0x80000000,0x100000000,0x200000000,0x400000000,0x800000000,0x1000000000,0x2000000000,0x4000000000,0x8000000000,0x10100000000,0x20200000000,0x40400000000,0x80800000000,0x101000000000,0x202000000000,0x404000000000,0x808000000000,0x1000000000000,0x2000000000000,0x4000000000000,0x8000000000000,0x10000000000000,0x20000000000000,0x40000000000000,0x80000000000000
};
// piece attack tables
__constant Bitboard AttackTables[7*64] = 
{
  // white pawn
  0x200,0x500,0xa00,0x1400,0x2800,0x5000,0xa000,0x4000,0x20000,0x50000,0xa0000,0x140000,0x280000,0x500000,0xa00000,0x400000,0x2000000,0x5000000,0xa000000,0x14000000,0x28000000,0x50000000,0xa0000000,0x40000000,0x200000000,0x500000000,0xa00000000,0x1400000000,0x2800000000,0x5000000000,0xa000000000,0x4000000000,0x20000000000,0x50000000000,0xa0000000000,0x140000000000,0x280000000000,0x500000000000,0xa00000000000,0x400000000000,0x2000000000000,0x5000000000000,0xa000000000000,0x14000000000000,0x28000000000000,0x50000000000000,0xa0000000000000,0x40000000000000,0x200000000000000,0x500000000000000,0xa00000000000000,0x1400000000000000,0x2800000000000000,0x5000000000000000,0xa000000000000000,0x4000000000000000,0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x0,
  // black pawn
  0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x2,0x5,0xa,0x14,0x28,0x50,0xa0,0x40,0x200,0x500,0xa00,0x1400,0x2800,0x5000,0xa000,0x4000,0x20000,0x50000,0xa0000,0x140000,0x280000,0x500000,0xa00000,0x400000,0x2000000,0x5000000,0xa000000,0x14000000,0x28000000,0x50000000,0xa0000000,0x40000000,0x200000000,0x500000000,0xa00000000,0x1400000000,0x2800000000,0x5000000000,0xa000000000,0x4000000000,0x20000000000,0x50000000000,0xa0000000000,0x140000000000,0x280000000000,0x500000000000,0xa00000000000,0x400000000000,0x2000000000000,0x5000000000000,0xa000000000000,0x14000000000000,0x28000000000000,0x50000000000000,0xa0000000000000,0x40000000000000,
  // knight
  0x20400,0x50800,0xa1100,0x142200,0x284400,0x508800,0xa01000,0x402000,0x2040004,0x5080008,0xa110011,0x14220022,0x28440044,0x50880088,0xa0100010,0x40200020,0x204000402,0x508000805,0xa1100110a,0x1422002214,0x2844004428,0x5088008850,0xa0100010a0,0x4020002040,0x20400040200,0x50800080500,0xa1100110a00,0x142200221400,0x284400442800,0x508800885000,0xa0100010a000,0x402000204000,0x2040004020000,0x5080008050000,0xa1100110a0000,0x14220022140000,0x28440044280000,0x50880088500000,0xa0100010a00000,0x40200020400000,0x204000402000000,0x508000805000000,0xa1100110a000000,0x1422002214000000,0x2844004428000000,0x5088008850000000,0xa0100010a0000000,0x4020002040000000,0x400040200000000,0x800080500000000,0x1100110a00000000,0x2200221400000000,0x4400442800000000,0x8800885000000000,0x100010a000000000,0x2000204000000000,0x4020000000000,0x8050000000000,0x110a0000000000,0x22140000000000,0x44280000000000,0x88500000000000,0x10a00000000000,0x20400000000000,
  // king
  0x302,0x705,0xe0a,0x1c14,0x3828,0x7050,0xe0a0,0xc040,0x30203,0x70507,0xe0a0e,0x1c141c,0x382838,0x705070,0xe0a0e0,0xc040c0,0x3020300,0x7050700,0xe0a0e00,0x1c141c00,0x38283800,0x70507000,0xe0a0e000,0xc040c000,0x302030000,0x705070000,0xe0a0e0000,0x1c141c0000,0x3828380000,0x7050700000,0xe0a0e00000,0xc040c00000,0x30203000000,0x70507000000,0xe0a0e000000,0x1c141c000000,0x382838000000,0x705070000000,0xe0a0e0000000,0xc040c0000000,0x3020300000000,0x7050700000000,0xe0a0e00000000,0x1c141c00000000,0x38283800000000,0x70507000000000,0xe0a0e000000000,0xc040c000000000,0x302030000000000,0x705070000000000,0xe0a0e0000000000,0x1c141c0000000000,0x3828380000000000,0x7050700000000000,0xe0a0e00000000000,0xc040c00000000000,0x203000000000000,0x507000000000000,0xa0e000000000000,0x141c000000000000,0x2838000000000000,0x5070000000000000,0xa0e0000000000000,0x40c0000000000000,
  // bishop
  0x8040201008040200,0x80402010080500,0x804020110a00,0x8041221400,0x182442800,0x10204885000,0x102040810a000,0x102040810204000,0x4020100804020002,0x8040201008050005,0x804020110a000a,0x804122140014,0x18244280028,0x1020488500050,0x102040810a000a0,0x204081020400040,0x2010080402000204,0x4020100805000508,0x804020110a000a11,0x80412214001422,0x1824428002844,0x102048850005088,0x2040810a000a010,0x408102040004020,0x1008040200020408,0x2010080500050810,0x4020110a000a1120,0x8041221400142241,0x182442800284482,0x204885000508804,0x40810a000a01008,0x810204000402010,0x804020002040810,0x1008050005081020,0x20110a000a112040,0x4122140014224180,0x8244280028448201,0x488500050880402,0x810a000a0100804,0x1020400040201008,0x402000204081020,0x805000508102040,0x110a000a11204080,0x2214001422418000,0x4428002844820100,0x8850005088040201,0x10a000a010080402,0x2040004020100804,0x200020408102040,0x500050810204080,0xa000a1120408000,0x1400142241800000,0x2800284482010000,0x5000508804020100,0xa000a01008040201,0x4000402010080402,0x2040810204080,0x5081020408000,0xa112040800000,0x14224180000000,0x28448201000000,0x50880402010000,0xa0100804020100,0x40201008040201,
  // rook
  0x1010101010101fe,0x2020202020202fd,0x4040404040404fb,0x8080808080808f7,0x10101010101010ef,0x20202020202020df,0x40404040404040bf,0x808080808080807f,0x10101010101fe01,0x20202020202fd02,0x40404040404fb04,0x80808080808f708,0x101010101010ef10,0x202020202020df20,0x404040404040bf40,0x8080808080807f80,0x101010101fe0101,0x202020202fd0202,0x404040404fb0404,0x808080808f70808,0x1010101010ef1010,0x2020202020df2020,0x4040404040bf4040,0x80808080807f8080,0x1010101fe010101,0x2020202fd020202,0x4040404fb040404,0x8080808f7080808,0x10101010ef101010,0x20202020df202020,0x40404040bf404040,0x808080807f808080,0x10101fe01010101,0x20202fd02020202,0x40404fb04040404,0x80808f708080808,0x101010ef10101010,0x202020df20202020,0x404040bf40404040,0x8080807f80808080,0x101fe0101010101,0x202fd0202020202,0x404fb0404040404,0x808f70808080808,0x1010ef1010101010,0x2020df2020202020,0x4040bf4040404040,0x80807f8080808080,0x1fe010101010101,0x2fd020202020202,0x4fb040404040404,0x8f7080808080808,0x10ef101010101010,0x20df202020202020,0x40bf404040404040,0x807f808080808080,0xfe01010101010101,0xfd02020202020202,0xfb04040404040404,0xf708080808080808,0xef10101010101010,0xdf20202020202020,0xbf40404040404040,0x7f80808080808080,
  // queen
  0x81412111090503fe,0x2824222120a07fd,0x404844424150efb,0x8080888492a1cf7,0x10101011925438ef,0x2020212224a870df,0x404142444850e0bf,0x8182848890a0c07f,0x412111090503fe03,0x824222120a07fd07,0x4844424150efb0e,0x80888492a1cf71c,0x101011925438ef38,0x20212224a870df70,0x4142444850e0bfe0,0x82848890a0c07fc0,0x2111090503fe0305,0x4222120a07fd070a,0x844424150efb0e15,0x888492a1cf71c2a,0x1011925438ef3854,0x212224a870df70a8,0x42444850e0bfe050,0x848890a0c07fc0a0,0x11090503fe030509,0x22120a07fd070a12,0x4424150efb0e1524,0x88492a1cf71c2a49,0x11925438ef385492,0x2224a870df70a824,0x444850e0bfe05048,0x8890a0c07fc0a090,0x90503fe03050911,0x120a07fd070a1222,0x24150efb0e152444,0x492a1cf71c2a4988,0x925438ef38549211,0x24a870df70a82422,0x4850e0bfe0504844,0x90a0c07fc0a09088,0x503fe0305091121,0xa07fd070a122242,0x150efb0e15244484,0x2a1cf71c2a498808,0x5438ef3854921110,0xa870df70a8242221,0x50e0bfe050484442,0xa0c07fc0a0908884,0x3fe030509112141,0x7fd070a12224282,0xefb0e1524448404,0x1cf71c2a49880808,0x38ef385492111010,0x70df70a824222120,0xe0bfe05048444241,0xc07fc0a090888482,0xfe03050911214181,0xfd070a1222428202,0xfb0e152444840404,0xf71c2a4988080808,0xef38549211101010,0xdf70a82422212020,0xbfe0504844424140,0x7fc0a09088848281,
};
// generate rook moves via koggestone shifts
Bitboard ks_attacks_ls1(Bitboard bbBlockers, Square sq)
{
  Bitboard bbPro;
  Bitboard bbGen;

  // directions left shifting <<1 ROOK
  bbPro   = ~bbBlockers;
  bbGen   = SETMASKBB(sq);
  bbPro  &= BBNOTAFILE;
  // do kogge stone
  bbGen  |= bbPro &   (bbGen << 1);
  bbPro  &=           (bbPro << 1);
  bbGen  |= bbPro &   (bbGen << 2*1);
  bbPro  &=           (bbPro << 2*1);
  bbGen  |= bbPro &   (bbGen << 4*1);
  // shift one further
  bbGen   = BBNOTAFILE &  (bbGen << 1);

  return bbGen;
}
Bitboard ks_attacks_ls8(Bitboard bbBlockers, Square sq)
{
  Bitboard bbPro;
  Bitboard bbGen;

  // directions left shifting <<8 ROOK
  bbPro   = ~bbBlockers;
  bbGen   = SETMASKBB(sq);
  // do kogge stone
  bbGen  |= bbPro &   (bbGen << 8);
  bbPro  &=           (bbPro << 8);
  bbGen  |= bbPro &   (bbGen << 2*8);
  bbPro  &=           (bbPro << 2*8);
  bbGen  |= bbPro &   (bbGen << 4*8);
  // shift one further
  bbGen   =           (bbGen << 8);
  
  return bbGen;
}
Bitboard ks_attacks_rs1(Bitboard bbBlockers, Square sq)
{
  Bitboard bbPro;
  Bitboard bbGen;

  // directions right shifting >>1 ROOK
  bbPro   = ~bbBlockers;
  bbGen   = SETMASKBB(sq);
  bbPro  &= BBNOTHFILE;
  // do kogge stone
  bbGen  |= bbPro &   (bbGen >> 1);
  bbPro  &=           (bbPro >> 1);
  bbGen  |= bbPro &   (bbGen >> 2*1);
  bbPro  &=           (bbPro >> 2*1);
  bbGen  |= bbPro &   (bbGen >> 4*1);
  // shift one further
  bbGen   = BBNOTHFILE &  (bbGen >> 1);

  return bbGen;
}
Bitboard ks_attacks_rs8(Bitboard bbBlockers, Square sq)
{
  Bitboard bbPro;
  Bitboard bbGen;

  // directions right shifting >>8 ROOK
  bbPro   = ~bbBlockers;
  bbGen   = SETMASKBB(sq);
  // do kogge stone
  bbGen  |= bbPro &   (bbGen >> 8);
  bbPro  &=           (bbPro >> 8);
  bbGen  |= bbPro &   (bbGen >> 2*8);
  bbPro  &=           (bbPro >> 2*8);
  bbGen  |= bbPro &   (bbGen >> 4*8);
  // shift one further
  bbGen   =           (bbGen >> 8);

  return bbGen;
}
Bitboard rook_attacks(Bitboard bbBlockers, Square sq)
{
  return ks_attacks_ls1(bbBlockers, sq) |
         ks_attacks_ls8(bbBlockers, sq) |
         ks_attacks_rs1(bbBlockers, sq) |
         ks_attacks_rs8(bbBlockers, sq);
}
// generate bishop moves via koggestone shifts
Bitboard ks_attacks_ls9(Bitboard bbBlockers, Square sq)
{
  Bitboard bbPro;
  Bitboard bbGen;

  // directions left shifting <<9 BISHOP
  bbPro   = ~bbBlockers;
  bbGen   = SETMASKBB(sq);
  bbPro  &= BBNOTAFILE;
  // do kogge stone
  bbGen  |= bbPro &   (bbGen << 9);
  bbPro  &=           (bbPro << 9);
  bbGen  |= bbPro &   (bbGen << 2*9);
  bbPro  &=           (bbPro << 2*9);
  bbGen  |= bbPro &   (bbGen << 4*9);
  // shift one further
  bbGen   = BBNOTAFILE &  (bbGen << 9);

  return bbGen;
}
Bitboard ks_attacks_ls7(Bitboard bbBlockers, Square sq)
{
  Bitboard bbPro;
  Bitboard bbGen;

  // directions left shifting <<7 BISHOP
  bbPro   = ~bbBlockers;
  bbGen   = SETMASKBB(sq);
  bbPro  &= BBNOTHFILE;
  // do kogge stone
  bbGen  |= bbPro &   (bbGen << 7);
  bbPro  &=           (bbPro << 7);
  bbGen  |= bbPro &   (bbGen << 2*7);
  bbPro  &=           (bbPro << 2*7);
  bbGen  |= bbPro &   (bbGen << 4*7);
  // shift one further
  bbGen   = BBNOTHFILE &  (bbGen << 7);

  return bbGen;
}
Bitboard ks_attacks_rs9(Bitboard bbBlockers, Square sq)
{
  Bitboard bbPro;
  Bitboard bbGen;

  // directions right shifting >>9 BISHOP
  bbPro   = ~bbBlockers;
  bbGen   = SETMASKBB(sq);
  bbPro  &= BBNOTHFILE;
  // do kogge stone
  bbGen  |= bbPro &   (bbGen >> 9);
  bbPro  &=           (bbPro >> 9);
  bbGen  |= bbPro &   (bbGen >> 2*9);
  bbPro  &=           (bbPro >> 2*9);
  bbGen  |= bbPro &   (bbGen >> 4*9);
  // shift one further
  bbGen   = BBNOTHFILE &  (bbGen >> 9);

  return bbGen;
}
Bitboard ks_attacks_rs7(Bitboard bbBlockers, Square sq)
{
  Bitboard bbPro;
  Bitboard bbGen;

  // directions right shifting >>7 BISHOP
  bbPro   = ~bbBlockers;
  bbGen   = SETMASKBB(sq);
  bbPro  &= BBNOTAFILE;
  // do kogge stone
  bbGen  |= bbPro &   (bbGen >> 7);
  bbPro  &=           (bbPro >> 7);
  bbGen  |= bbPro &   (bbGen >> 2*7);
  bbPro  &=           (bbPro >> 2*7);
  bbGen  |= bbPro &   (bbGen >> 4*7);
  // shift one further
  bbGen   = BBNOTAFILE &  (bbGen >> 7);

  return bbGen;
}
Bitboard bishop_attacks(Bitboard bbBlockers, Square sq)
{
  return ks_attacks_ls7(bbBlockers, sq) |
         ks_attacks_ls9(bbBlockers, sq) |
         ks_attacks_rs7(bbBlockers, sq) |
         ks_attacks_rs9(bbBlockers, sq);
}
Square getkingsq(__private Bitboard *board, bool side)
{
  Bitboard bbTemp = (side)?board[0]:board[0]^(board[1]|board[2]|board[3]);;
  bbTemp &= board[1]&board[2]&~board[3]; // get king
  return first1(bbTemp);
}
// is square attacked by an enemy piece, via superpiece approach
bool squareunderattack(__private Bitboard *board, bool stm, Square sq) 
{
  Bitboard bbWork;
  Bitboard bbMoves;
  Bitboard bbBlockers;
  Bitboard bbMe;

  bbBlockers = board[1]|board[2]|board[3];
  bbMe       = (stm)?board[0]:(board[0]^bbBlockers);

  // rooks and queens
  bbMoves = rook_attacks(bbBlockers, sq);
  bbWork =    (bbMe&(board[1]&~board[2]&board[3])) 
            | (bbMe&(~board[1]&board[2]&board[3]));
  if (bbMoves&bbWork)
  {
    return true;
  }
  bbMoves = bishop_attacks(bbBlockers, sq);
  // bishops and queens
  bbWork =  (bbMe&(~board[1]&~board[2]&board[3])) 
          | (bbMe&(~board[1]&board[2]&board[3]));
  if (bbMoves&bbWork)
  {
    return true;
  }
  // knights
  bbWork = bbMe&(~board[1]&board[2]&~board[3]);
  bbMoves = AttackTables[128+sq] ;
  if (bbMoves&bbWork) 
  {
    return true;
  }
  // pawns
  bbWork = bbMe&(board[1]&~board[2]&~board[3]);
  bbMoves = AttackTables[!stm*64+sq];
  if (bbMoves&bbWork)
  {
    return true;
  }
  // king
  bbWork = bbMe&(board[1]&board[2]&~board[3]);
  bbMoves = AttackTables[192+sq];
  if (bbMoves&bbWork)
  {
    return true;
  } 

  return false;
}
// perft on gpu, 64 threads in parallel on one chess position
__kernel void perft_gpu(  
                      const __global Bitboard *BOARD,
                            __global u64 *COUNTERS,
                            __global Hash *HashHistory,
                      const __global Bitboard *bbInBetween,
                      const __global Bitboard *bbLine,
                               const s32 stm_init,
                               const s32 ply_init,
                               const s32 search_depth,
                               const u64 max_nodes
)
{
  // Quadbitboard + piece moved flags + hash + lastmove
  __private Bitboard board[7]; 
//  __local Bitboard lboard[7];

  // iterative search var stack
  __local Score localAlphaBetaScores[MAXPLY*2];
  __local s32 localTodoIndex[MAXPLY];
  __local s32 localMoveCounter[MAXPLY];
  __local Move localMoveHistory[MAXPLY];
  __local Cr localCrHistory[MAXPLY];
  __local Hash localHashHistory[MAXPLY];
  __local Score localMoveIndexScore[MAXPLY];

  bool stm;
  s32 sd;
  s32 ply;

  __local s32 mode;
  __local s32 movecount;
  __local Move lmove;
  __local Score lscore;
  __local Square sqchecker;

  __local Bitboard bbAttacks;
  __local Bitboard bbCheckers;

  const s32 gid = get_global_id(0) * get_global_size(1) + get_global_id(1);
  const Square lid = get_local_id(2);

  bool tmpb;
  bool kic;
  bool rootkic;
  bool qs;

  Square sqking;
  Square sqfrom;
  Square sqto;
  Square sqcpt;   
  Square sqep;

  Piece pfrom;
  Piece pto;
  Piece pcpt;
  Piece ppromo;

  Score score;
  Score tmpscore;

  s32 n;

  Move move;
  Move tmpmove;

  Bitboard bbBlockers;
  Bitboard bbMe;
  Bitboard bbOpp;
  Bitboard bbTemp;
  Bitboard bbWork;
  Bitboard bbMask;
  Bitboard bbMoves;
  Bitboard bbPinned;

  ulong4 bbPro4;
  ulong4 bbGen4; 

  // get init quadbitboard plus plus
  board[QBBBLACK] = BOARD[QBBBLACK];
  board[QBBP1]    = BOARD[QBBP1];
  board[QBBP2]    = BOARD[QBBP2];
  board[QBBP3]    = BOARD[QBBP3];
  board[QBBPMVD]  = BOARD[QBBPMVD]; // piece moved flags
  board[QBBHASH]  = BOARD[QBBHASH]; // hash
  board[QBBLAST]  = BOARD[QBBLAST]; // lastmove
  stm             = (bool)stm_init;
  ply             = 0;
  sd              = 1;

  if (lid==0)
  {
    mode            = MOVEUP;
    lmove           = MOVENONE;

    // init ab search var stack
    localAlphaBetaScores[0*2+ALPHA] =-INF;
    localAlphaBetaScores[0*2+BETA]  = INF;
    localMoveCounter[0]             = 0;
    localTodoIndex[0]               = 0;
    localMoveIndexScore[0]          = INF;
    localMoveHistory[0]             = BOARD[QBBLAST];
    localCrHistory[0]               = BOARD[QBBPMVD];
    localHashHistory[0]             = BOARD[QBBHASH];
    localAlphaBetaScores[sd*2+ALPHA]=-INF;
    localAlphaBetaScores[sd*2+BETA] = INF;
    localMoveCounter[sd]            = 0;
    localTodoIndex[sd]              = 0;
    localMoveIndexScore[sd]         = INF;
    localMoveHistory[sd]            = MOVENONE;
    localCrHistory[sd]              = BBEMPTY;
    localHashHistory[sd]            = BBEMPTY;

    COUNTERS[gid*64+1]              = (u64)-INF; 
  }
  barrier(CLK_LOCAL_MEM_FENCE);
  barrier(CLK_GLOBAL_MEM_FENCE);
  // ################################
  // ####       main loop        ####
  // ################################
  while(mode!=EXIT)
  {
    // ################################
    // ####     movegenerator x64  ####
    // ################################

    // resets
    if (lid==0)
    {
      movecount = 0;
      lscore = -INF;
      lmove = MOVENONE;
      bbAttacks = BBEMPTY;
      bbCheckers  = BBEMPTY;
    }

    // get init quadbitboard plus plus
/*
    board[QBBBLACK] = lboard[QBBBLACK];
    board[QBBP1]    = lboard[QBBP1];
    board[QBBP2]    = lboard[QBBP2];
    board[QBBP3]    = lboard[QBBP3];
    board[QBBPMVD]  = lboard[QBBPMVD]; // piece moved flags
    board[QBBHASH]  = lboard[QBBHASH]; // hash
    board[QBBLAST]  = lboard[QBBLAST]; // lastmove
*/
    bbPinned = BBEMPTY;

    n = 0;
    qs = (sd>search_depth)?true:false; // enter quiescence search?

    bbBlockers  = board[1]|board[2]|board[3];
    bbMe        =  (stm)?board[0]:(board[0]^bbBlockers);
    bbOpp       = (!stm)?board[0]:(board[0]^bbBlockers);

    // calc superking and get pinned pieces
    // get colored king
    bbTemp = bbMe&board[QBBP1]&board[QBBP2]&~board[QBBP3];
    // get king square
    sqking = first1(bbTemp);

    // get superking, rooks n queens
    bbWork = rook_attacks(BBEMPTY, sqking) & ((bbOpp&(board[QBBP1]&~board[QBBP2]&board[QBBP3])) | (bbOpp&(~board[QBBP1]&board[QBBP2]&board[QBBP3])));
    // get superking, bishops n queems
    bbWork|= bishop_attacks(BBEMPTY, sqking) & ((bbOpp&(~board[QBBP1]&~board[QBBP2]&board[QBBP3])) | (bbOpp&(~board[QBBP1]&board[QBBP2]&board[QBBP3])));
    // get pinned pieces
    while (bbWork)
    {
      sqfrom = popfirst1(&bbWork);
      bbTemp = bbInBetween[sqfrom*64+sqking]&bbBlockers;
      if (count1s(bbTemp)==1)
        bbPinned |= bbTemp;
    }
    // generate own moves and opposite attacks
    sqfrom  = lid;
    pfrom   = GETPIECE(board, sqfrom);
    kic     = GETCOLOR(pfrom);
    // get koggestone wraps
    // generator and propagator (piece and empty squares)
    bbGen4  = (ulong4)bbBlockers&SETMASKBB(sqfrom);
    bbPro4  = (ulong4)(~bbBlockers);
    bbPro4 ^= (kic==stm)?BBEMPTY:SETMASKBB(sqking);
//    bbPro4  = (SETMASKBB(sqfrom)&bbMe)?(ulong4)(~bbBlockers):(ulong4)(~bbBlockers^SETMASKBB(sqking));
    // kogge stone shift left via ulong4 vector
    bbPro4 &= wraps4[0];
    bbGen4 |= bbPro4    & (bbGen4 << shift4);
    bbPro4 &=             (bbPro4 << shift4);
    bbGen4 |= bbPro4    & (bbGen4 << 2*shift4);
    bbPro4 &=             (bbPro4 << 2*shift4);
    bbGen4 |= bbPro4    & (bbGen4 << 4*shift4);
    bbGen4  = wraps4[0] & (bbGen4 << shift4);
    bbTemp  = bbGen4.s0|bbGen4.s1|bbGen4.s2|bbGen4.s3;
    // get koggestone wraps
    // set generator and propagator (piece and empty squares)
    bbGen4  = (ulong4)bbBlockers&SETMASKBB(sqfrom);
    bbPro4  = (ulong4)(~bbBlockers);
    bbPro4 ^= (kic==stm)?BBEMPTY:SETMASKBB(sqking);
//    bbPro4  = (SETMASKBB(sqfrom)&bbMe)?(ulong4)(~bbBlockers):(ulong4)(~bbBlockers^SETMASKBB(sqking));
    // kogge stone shift right via ulong4 vector
    bbPro4 &= wraps4[1];
    bbGen4 |= bbPro4    & (bbGen4 >> shift4);
    bbPro4 &=             (bbPro4 >> shift4);
    bbGen4 |= bbPro4    & (bbGen4 >> 2*shift4);
    bbPro4 &=             (bbPro4 >> 2*shift4);
    bbGen4 |= bbPro4    & (bbGen4 >> 4*shift4);
    bbGen4  = wraps4[1] & (bbGen4 >> shift4);
    bbTemp |= bbGen4.s0|bbGen4.s1|bbGen4.s2|bbGen4.s3;
    // consider knights
    bbTemp  = (GETPTYPE(pfrom)==KNIGHT)?BBFULL:bbTemp;
    // verify captures
    n       = (kic==stm)?(s32)stm:(s32)!stm;
    n       = (GETPTYPE(pfrom)==PAWN)?n:GETPTYPE(pfrom);
    bbMask  = AttackTables[n*64+sqfrom];
    bbMoves = (kic==stm)?(bbMask&bbTemp&bbOpp):(bbMask&bbTemp);
    // verify non captures
    bbMask  = (GETPTYPE(pfrom)==PAWN)?(AttackTablesPawnPushes[stm*64+sqfrom]):bbMask;
    bbMoves|= (kic==stm&&!qs)?(bbMask&bbTemp&~bbBlockers):BBEMPTY; 

    // collect opp attacks
    barrier(CLK_LOCAL_MEM_FENCE);
    if (kic!=stm)
      atom_or(&bbAttacks, bbMoves);
    // get king checkers
    if (bbMoves&SETMASKBB(sqking))
    {
      sqchecker = sqfrom;
      atom_or(&bbCheckers, SETMASKBB(sqfrom));
    }
    barrier(CLK_LOCAL_MEM_FENCE);

    rootkic = (bbCheckers)?true:false;

    // extract only own moves
    bbMoves = (kic==stm)?bbMoves:BBEMPTY;

    n = count1s(bbCheckers);

    // double check, king moves only
    tmpb = (n>=2&&GETPTYPE(pfrom)!=KING)?true:false;
    bbMoves = (tmpb)?BBEMPTY:bbMoves;

    // consider pinned pieces
    tmpb = (SETMASKBB(sqfrom)&bbPinned)?true:false;
    bbMoves &= (tmpb)?bbLine[sqfrom*64+sqking]:BBFULL;

    // consider king and opp attacks
    tmpb = (GETPTYPE(pfrom)==KING)?true:false;
    bbMoves &= (tmpb)?~bbAttacks:BBFULL;

    // consider single checker
    tmpb = (n==1&&GETPTYPE(pfrom)!=KING)?true:false;
    bbMoves &= (tmpb)?(bbInBetween[sqchecker*64+sqking]|bbCheckers):BBFULL;

// 570k, 470K

    // gen en passant moves, TODO reimplement
    bbTemp = BBEMPTY;
    sqep   = GETSQEP(board[QBBLAST]); 
    if (sqep)
    {
      bbMask  = bbMe&(board[QBBP1]&~board[QBBP2]&~board[QBBP3]); // get our pawns
      bbMask &= (stm)?0xFF000000UL:0xFF00000000UL;
      bbTemp  = bbMask&(SETMASKBB(sqep+1)|SETMASKBB(sqep-1));
    }
    // check for en passant pawns, TODO: ep legality check wo domove/undomove/kic, maybe paralellx64???:TODO
    if (bbTemp&SETMASKBB(sqfrom))
    {
      pfrom   = GETPIECE(board, sqfrom);
      pto     = pfrom;
      sqcpt   = sqep;
      pcpt    = GETPIECE(board, sqcpt);
      sqto    = (stm)? sqep-8:sqep+8;
      // pack move into 64 bits, considering castle rights and halfmovecounter and score
      move    = MAKEMOVE((Move)sqfrom, (Move)sqto, (Move)sqcpt, (Move)pfrom, (Move)pto, (Move)pcpt, 0x0UL, 0x0UL, 0x0UL);
      // legal moves only
      domovequick(board, move);
      kic = squareunderattack(board, !stm, sqking);
      undomovequick(board, move);
      if (!kic)
      {
        bbMoves |= SETMASKBB(sqto);
      }
//      bbMoves |= SETMASKBB(((stm)?sqep-8:sqep+8));
    }
    // TODO: speedup
    // gen castle moves queenside
    tmpb = (lid==sqking&&!qs&&(board[QBBPMVD]&SMCRALL)&&((stm&&(((~board[QBBPMVD])&SMCRBLACKQ)==SMCRBLACKQ))||(!stm&&(((~board[QBBPMVD])&SMCRWHITEQ)==SMCRWHITEQ))))?true:false;
    if (tmpb)
    { 
      // get king square
      sqfrom  = sqking;
      sqto    = sqfrom-2;
      pfrom   = GETPIECE(board, sqfrom);
      // rook present
      bbTemp  = (GETPIECE(board, sqfrom-4)==MAKEPIECE(ROOK,GETCOLOR(pfrom)))?true:false;
      // check for empty squares
      bbMask  = ((bbBlockers&SETMASKBB(sqfrom-1))|(bbBlockers&SETMASKBB(sqfrom-2))|(bbBlockers&SETMASKBB(sqfrom-3)));
      // check for king and empty squares in check
      bbWork =  (bbAttacks&SETMASKBB(sqfrom))|(bbAttacks&SETMASKBB(sqfrom-1))|(bbAttacks&SETMASKBB(sqfrom-2));
      // store move
      if (bbTemp&&!bbMask&&!bbWork)
      {
        bbMoves |= SETMASKBB(sqto);
      }
    }
    // gen castle moves kingside
    tmpb =  (lid==sqking&&!qs&&(board[QBBPMVD]&SMCRALL)&&((stm&&(((~board[QBBPMVD])&SMCRBLACKK)==SMCRBLACKK))||(!stm&&(((~board[QBBPMVD])&SMCRWHITEK)==SMCRWHITEK))))?true:false;
    if (tmpb)
    {
      sqfrom  = sqking;
      sqto    = sqfrom+2;
      // rook present
      bbTemp  = (GETPIECE(board, sqfrom+3)==MAKEPIECE(ROOK,GETCOLOR(pfrom)))?true:false;
      // check for empty squares
      bbMask  = ((bbBlockers&SETMASKBB(sqfrom+1))|(bbBlockers&SETMASKBB(sqfrom+2)));
      // check for king and empty squares in check
      bbWork =  (bbAttacks&SETMASKBB(sqfrom))|(bbAttacks&SETMASKBB(sqfrom+1))|(bbAttacks&SETMASKBB(sqfrom+2));
      // store move
      if (bbTemp&&!bbMask&&!bbWork)
      {
        bbMoves |= SETMASKBB(sqto);
      }
    }
// 385K, 420K / wo ep move gen

    // ################################
    // ####     movepicker x64     ####
    // ################################
    // move picker, extract moves x64 parallel
    n       = 0;
    move    = MOVENONE;
    score   = -INF;
    sqfrom  = lid;
    pfrom   = GETPIECE(board, sqfrom);
    ppromo  = GETPTYPE(pfrom);

    while(bbMoves)
    {
      sqto  = popfirst1(&bbMoves);
      sqcpt = sqto; 
      // set en passant target square
      sqep  = (GETPTYPE(pfrom)==PAWN&&GETRRANK(sqto,stm)-GETRRANK(sqfrom,stm)==2)?sqto:0x0; 
      // get piece captured
      pcpt  = GETPIECE(board, sqcpt);
      // check for en passant capture square
      if (GETPTYPE(pfrom)==PAWN&&stm&&sqfrom-sqto!=8&&sqfrom-sqto!=16&&pcpt==PNONE)
      {
        sqcpt = (stm)? sqto+8:sqto-8;
      }
      if (GETPTYPE(pfrom)==PAWN&&!stm&&sqto-sqfrom!=8&&sqto-sqfrom!=16&&pcpt==PNONE)
      {
        sqcpt = (stm)? sqto+8:sqto-8;
      }
      pcpt  = GETPIECE(board, sqcpt);
      pto   = pfrom;
      // set pawn prommotion, queen
//      pto   = (GETPTYPE(pfrom)==PAWN&&GETRRANK(sqto,stm)==RANK_8)?MAKEPIECE(QUEEN,GETCOLOR(pfrom)):pfrom;

      // handle all pawn promo, repeat loop
      if (GETPTYPE(pfrom)==PAWN&&GETRRANK(sqto,stm)==RANK_8)
      {
        ppromo++;
        ppromo=(ppromo==KING)?BISHOP:ppromo; // skip king
        pto = MAKEPIECE(ppromo,GETCOLOR(pfrom));
        bbMoves |= (ppromo<QUEEN)?SETMASKBB(sqto):BBEMPTY;
        ppromo=(ppromo==QUEEN)?PAWN:ppromo; // reset ppromo for further sqto
      }

      // make move
      tmpmove  = MAKEMOVE((Move)sqfrom, (Move)sqto, (Move)sqcpt, (Move)pfrom, (Move)pto, (Move)pcpt, (Move)sqep, (u64)GETHMC(board[QBBLAST]), 0x0UL);
      tmpmove |= (GETPTYPE(pfrom)==KING&&sqfrom-sqto==2)?MOVEISCRQ:MOVENONE;
      tmpmove |= (GETPTYPE(pfrom)==KING&&sqto-sqfrom==2)?MOVEISCRK:MOVENONE;

      // domove
//      domovequick(board, tmpmove);
//      // king in check, illegal move
//      kic = squareunderattack(board, !stm, getkingsq(board, stm));
//      undomovequick(board, tmpmove);
//      if (kic)
//        continue;
      atom_inc(&movecount);
      n++;
      // eval move
      // wood count and piece square tables, pto-pfrom   
      tmpscore = EvalPieceValues[GETPTYPE(pto)]+EvalTable[GETPTYPE(pto)*64+((stm)?sqto:FLIPFLOP(sqto))]+EvalControl[((stm)?sqto:FLIPFLOP(sqto))];
      tmpscore-= EvalPieceValues[GETPTYPE(pfrom)]+EvalTable[GETPTYPE(pfrom)*64+((stm)?sqfrom:FLIPFLOP(sqfrom))]+EvalControl[((stm)?sqfrom:FLIPFLOP(sqfrom))];
      // MVV-LVA
      tmpscore = (pcpt!=PNONE)?EvalPieceValues[GETPTYPE(pcpt)]*16-EvalPieceValues[GETPTYPE(pto)]:tmpscore;
      tmpscore = tmpscore*1000+lid*64+n;
      // ignore moves already searched
      if (tmpscore>=localMoveIndexScore[sd])
        continue;
      // get move with highest score
      if (tmpscore<=score)
        continue;
      score = tmpscore;
      move = tmpmove;
    }

// 150K, 260K wo ep check

    // get sorted next move and store to local memory
    barrier(CLK_LOCAL_MEM_FENCE);
    // get sorted next move and store to local memory
    atom_max(&lscore, score);
    barrier(CLK_LOCAL_MEM_FENCE);
    tmpscore = atom_cmpxchg(&lscore, score, score);
    if (tmpscore==score)
    {
      lmove = move;
      localMoveIndexScore[sd] = score;
    }
    barrier(CLK_LOCAL_MEM_FENCE);
/*
    // ################################
    // ####     evaluation x64      ###
    // ################################
    lscore  = 0;
    sqfrom  = lid;
    pfrom   = GETPIECE(board, sqfrom);
    kic     = GETCOLOR(pfrom); // get color to work on
    pfrom   = GETPTYPE(pfrom);
    bbMask  = board[QBBP1]&~board[QBBP2]&~board[QBBP3]; // get all pawns
    bbMe    =  (kic)?board[QBBBLACK]:board[QBBBLACK]^bbBlockers;
    bbOpp   = (!kic)?board[QBBBLACK]:board[QBBBLACK]^bbBlockers;
    tmpscore= 0;
    // piece bonus
    tmpscore+= (pfrom!=PNONE)?(kic)?-10:10:0;
    // wood count
    tmpscore+= (pfrom!=PNONE)?(kic)?-EvalPieceValues[pfrom]:EvalPieceValues[pfrom]:0;
    // piece square tables
    tmpscore+= (pfrom!=PNONE)?(kic)?-EvalTable[pfrom*64+sqfrom]:EvalTable[pfrom*64+FLIPFLOP(sqfrom)]:0;
    // square control table
    tmpscore+= (pfrom!=PNONE)?(kic)?-EvalControl[sqfrom]:EvalControl[FLIPFLOP(sqfrom)]:0;
    // simple pawn structure white
    // blocked
    if (pfrom==PAWN&&kic==WHITE)
    {
      tmpscore-=(GETRANK(sqfrom)<RANK_8&&(bbOpp&SETMASKBB(sqfrom+8)))?15:0;
        // chain
      tmpscore+=(GETFILE(sqfrom)<FILE_H&&(bbMask&bbOpp&SETMASKBB(sqfrom-7)))?10:0;
      tmpscore+=(GETFILE(sqfrom)>FILE_A&&(bbMask&bbOpp&SETMASKBB(sqfrom-9)))?10:0;
      // column, TODO: popcount based
      for(sqto=sqfrom-8;sqto>7;sqto-=8)
        tmpscore-=(bbMask&bbMe&SETMASKBB(sqto))?30:0;
    }
    // simple pawn structure black
    // blocked
    if (pfrom==PAWN&&kic==BLACK)
    {
      tmpscore+=(GETRANK(sqfrom)>RANK_1&&(bbOpp&SETMASKBB(sqfrom-8)))?15:0;
        // chain
      tmpscore-=(GETFILE(sqfrom)>FILE_A&&(bbMask&bbOpp&SETMASKBB(sqfrom+7)))?10:0;
      tmpscore-=(GETFILE(sqfrom)<FILE_H&&(bbMask&bbOpp&SETMASKBB(sqfrom+9)))?10:0;
      // column, TODO: popcount based
      for(sqto=sqfrom+8;sqto<56;sqto+=8)
        tmpscore+=(bbMask&bbMe&SETMASKBB(sqto))?30:0;
    }
    // duble bishop
    if (lid==0)
    {
      tmpscore-= (count1s(board[QBBBLACK]&(~board[QBBP1]&~board[QBBP2]&board[QBBP3]))==2)?25:0;
      tmpscore+= (count1s((board[QBBBLACK]^bbBlockers)&(~board[QBBP1]&~board[QBBP2]&board[QBBP3]))==2)?25:0;
    }
    // store scores in local memory
    barrier(CLK_LOCAL_MEM_FENCE);
    atom_add(&lscore, tmpscore);
    barrier(CLK_LOCAL_MEM_FENCE);
    score = lscore;
    // negamaxed scores
    score = (stm)?-score:score;
    // checkmate
    score = (!qs&&rootkic&&movecount==0)?-INF+sd:score;
    // stalemate
    score = (!qs&&!rootkic&&movecount==0)?STALEMATESCORE:score;

//      // draw by 3 fold repetition
//      for (s32 i=ply+ply_init-2;i>=ply+ply_init-(s32)GETHMC(board[QBBLAST])&&!qs&&index>0;i-=2)
//      {
//        if (board[QBBHASH]==global_hashhistory[pid*MAXGAMEPLY+i])
//        {
//          n       = 0;
//          score   = DRAWSCORE;
//          break;
//        }
//      }
*/

// 110K, 230K 

    // #################################
    // ####     alphabeta flow x1    ###
    // #################################
    if (lid==0)
    {
      // terminal node
      if (sd>search_depth)
      {
        // terminal node counter
        COUNTERS[gid*64+0]++;
        movecount = 0;
        lmove = MOVENONE;
      }
      localMoveCounter[sd]  = movecount;
      // terminal node
      if (mode==MOVEUP&&lmove==MOVENONE)
        mode = MOVEDOWN;
    }
    barrier(CLK_LOCAL_MEM_FENCE);
    // ################################
    // ####         moveup         ####
    // ################################
    // move up in tree
    if (lid==0&&mode==MOVEUP)
    {
      // set history
      localMoveHistory[sd]  = lmove;
      localCrHistory[sd]    = board[QBBPMVD];
      localHashHistory[sd]  = board[QBBHASH];
      localTodoIndex[sd]++;
    }
    // domove x64
    if (mode==MOVEUP)
    {
      domove(board, lmove);
      stm = !stm; // switch site to move
      sd++;       // increase depth counter
      ply++;      // increase ply counter
    }
    if (lid==0&&mode==MOVEUP)
    {
      // set values for next depth
      localMoveCounter[sd]              = 0;
      localTodoIndex[sd]                = 0;
      localAlphaBetaScores[sd*2+ALPHA]  = -localAlphaBetaScores[(sd-1)*2+BETA];
      localAlphaBetaScores[sd*2+BETA]   = -localAlphaBetaScores[(sd-1)*2+ALPHA];
      localMoveIndexScore[sd]           = INF;
    }
    // ################################
    // ####        movedown        ####
    // ################################
    // move down in tree
    // undomove x64
    if (mode==MOVEDOWN)
    {
      sd--;
      ply--;
      stm = !stm; // switch site to move
      undomove( board, 
                localMoveHistory[sd],
                localMoveHistory[sd-1],
                localCrHistory[sd], 
                localHashHistory[sd]
              );
    }
    barrier(CLK_LOCAL_MEM_FENCE);
    if (lid==0)
      mode = (sd<1)?EXIT:MOVEUP;
    barrier(CLK_LOCAL_MEM_FENCE);
  } // end main loop
//  COUNTERS[gid*64+1] += lscore;
//  COUNTERS[gid*64+2] |= bbMoves^bbAttacks;
}
// perft on gpu, 64 threads in parallel on one chess position
__kernel void alphabeta_gpu(
                      const __global Bitboard *BOARD,
                            __global u64 *COUNTERS,
                            __global Hash *HashHistory,
                      const __global Bitboard *bbInBetween,
                      const __global Bitboard *bbLine,
                            __global TTE *TT,
                               const s32 stm_init,
                               const s32 ply_init,
                               const s32 search_depth,
                               const u64 max_nodes,
                               const u64 ttindex
)
{
  // Quadbitboard + piece moved flags + hash + lastmove
  __private Bitboard board[7]; 

  // iterative search var stack
  __local Score localAlphaBetaScores[MAXPLY*2];
  __local Move localMoveHistory[MAXPLY];
  __local Cr localCrHistory[MAXPLY];
  __local Hash localHashHistory[MAXPLY];
  __local Score localMoveIndexScore[MAXPLY];

  __local Square sqchecker;

  __local s32 mode;
  __local s32 movecount;

  __local Score lscore;

  __local Move lmove;

  __local Bitboard bbAttacks;
  __local Bitboard bbCheckers;

  const s32 gid = get_global_id(0) * get_global_size(1) + get_global_id(1);
  const Square lid = get_local_id(2);

  bool tmpb;
  bool kic;
  bool rootkic;
  bool qs;
  bool stm;

  Square sqking;
  Square sqfrom;
  Square sqto;
  Square sqcpt;   
  Square sqep;

  Piece pfrom;
  Piece pto;
  Piece pcpt;

  Score score;
  Score tmpscore;

  s32 sd;
  s32 ply;
  s32 n;

  Move move;
  Move tmpmove;
  Move ttmove;

  Bitboard bbBlockers;
  Bitboard bbMe;
  Bitboard bbOpp;
  Bitboard bbTemp;
  Bitboard bbWork;
  Bitboard bbMask;
  Bitboard bbMoves;
  Bitboard bbPinned;

  ulong4 bbPro4;
  ulong4 bbGen4; 

  // get bbInBetween and bbLine into cache
//  prefetch(bbInBetween, 4096);
//  prefetch(bbLine, 4096);

  // get init quadbitboard plus plus
  board[QBBBLACK] = BOARD[QBBBLACK];
  board[QBBP1]    = BOARD[QBBP1];
  board[QBBP2]    = BOARD[QBBP2];
  board[QBBP3]    = BOARD[QBBP3];
  board[QBBPMVD]  = BOARD[QBBPMVD]; // piece moved flags
  board[QBBHASH]  = BOARD[QBBHASH]; // hash
  board[QBBLAST]  = BOARD[QBBLAST]; // lastmove
  stm             = (bool)stm_init;
  ply             = 0;
  sd              = 1;

  if (lid==0)
  {
    mode            = MOVEUP;
    lmove           = MOVENONE;
    // init ab search var stack
    localAlphaBetaScores[0*2+ALPHA] =-INF;
    localAlphaBetaScores[0*2+BETA]  = INF;
    localMoveIndexScore[0]          = INF;
    localMoveHistory[0]             = BOARD[QBBLAST];
    localCrHistory[0]               = BOARD[QBBPMVD];
    localHashHistory[0]             = BOARD[QBBHASH];
    localAlphaBetaScores[sd*2+ALPHA] =-INF;
    localAlphaBetaScores[sd*2+BETA]  = INF;
    localMoveIndexScore[sd]          = INF;
    localMoveHistory[sd]             = MOVENONE;
    localCrHistory[sd]               = BBEMPTY;
    localHashHistory[sd]             = BBEMPTY;
    // zeroed on hosts
//    COUNTERS[gid*64+0]              = 0;              // movecount, return
//    COUNTERS[gid*64+1]              = (u64)-INF;      // best score, return
//    COUNTERS[gid*64+2]              = MOVENONE;       // best move, return
//    COUNTERS[gid*64+3]              = 0;              // tthits, return
//    COUNTERS[gid*64+4]              = 0;              // depth reached, return
  }
  barrier(CLK_LOCAL_MEM_FENCE);
//  barrier(CLK_GLOBAL_MEM_FENCE);
  // ################################
  // ####       main loop        ####
  // ################################
  while(mode!=EXIT) // node count based termination
  {
    // ################################
    // ####     movegenerator x64  ####
    // ################################

    // resets
    if (lid==0)
    {
      movecount = 0;
      lscore = -INF;
      lmove = MOVENONE;
      bbAttacks = BBEMPTY;
      bbCheckers  = BBEMPTY;
    }

    bbPinned = BBEMPTY;

    n = 0;
    qs = (sd>search_depth)?true:false; // enter quiescence search?

    bbBlockers  = board[1]|board[2]|board[3];
    bbMe        =  (stm)?board[0]:(board[0]^bbBlockers);
    bbOpp       = (!stm)?board[0]:(board[0]^bbBlockers);

    // get colored king
    bbTemp = bbMe&board[QBBP1]&board[QBBP2]&~board[QBBP3];
    // get king square
    sqking = first1(bbTemp);

    // calc superking and get pinned pieces
    // get superking, rooks n queens
    bbWork = rook_attacks(BBEMPTY, sqking) & ((bbOpp&(board[QBBP1]&~board[QBBP2]&board[QBBP3])) | (bbOpp&(~board[QBBP1]&board[QBBP2]&board[QBBP3])));
    // get superking, bishops n queems
    bbWork|= bishop_attacks(BBEMPTY, sqking) & ((bbOpp&(~board[QBBP1]&~board[QBBP2]&board[QBBP3])) | (bbOpp&(~board[QBBP1]&board[QBBP2]&board[QBBP3])));
    // get pinned pieces
    while (bbWork)
    {
      sqfrom = popfirst1(&bbWork);
      bbTemp = bbInBetween[sqfrom*64+sqking]&bbBlockers;
      if (count1s(bbTemp)==1)
        bbPinned |= bbTemp;
    }
    // generate own moves and opposite attacks
    pfrom   = GETPIECE(board, lid);
    kic     = GETCOLOR(pfrom);
    // get koggestone wraps
    // generator and propagator (piece and empty squares)
    bbGen4  = (ulong4)bbBlockers&SETMASKBB(lid);
    bbPro4  = (ulong4)(~bbBlockers);
    bbPro4 ^= (kic==stm)?BBEMPTY:SETMASKBB(sqking);
    // kogge stone shift left via ulong4 vector
    bbPro4 &= wraps4[0];
    bbGen4 |= bbPro4    & (bbGen4 << shift4);
    bbPro4 &=             (bbPro4 << shift4);
    bbGen4 |= bbPro4    & (bbGen4 << 2*shift4);
    bbPro4 &=             (bbPro4 << 2*shift4);
    bbGen4 |= bbPro4    & (bbGen4 << 4*shift4);
    bbGen4  = wraps4[0] & (bbGen4 << shift4);
    bbTemp  = bbGen4.s0|bbGen4.s1|bbGen4.s2|bbGen4.s3; // collect vector moves
    // get koggestone wraps
    // set generator and propagator (piece and empty squares)
    bbGen4  = (ulong4)bbBlockers&SETMASKBB(lid);
    bbPro4  = (ulong4)(~bbBlockers);
    bbPro4 ^= (kic==stm)?BBEMPTY:SETMASKBB(sqking);
    // kogge stone shift right via ulong4 vector
    bbPro4 &= wraps4[1];
    bbGen4 |= bbPro4    & (bbGen4 >> shift4);
    bbPro4 &=             (bbPro4 >> shift4);
    bbGen4 |= bbPro4    & (bbGen4 >> 2*shift4);
    bbPro4 &=             (bbPro4 >> 2*shift4);
    bbGen4 |= bbPro4    & (bbGen4 >> 4*shift4);
    bbGen4  = wraps4[1] & (bbGen4 >> shift4);
    bbTemp |= bbGen4.s0|bbGen4.s1|bbGen4.s2|bbGen4.s3; // collect vector moves
    // consider knights
    bbTemp  = (GETPTYPE(pfrom)==KNIGHT)?BBFULL:bbTemp;
    // verify captures
    n       = (kic==stm)?(s32)stm:(s32)!stm;
    n       = (GETPTYPE(pfrom)==PAWN)?n:GETPTYPE(pfrom);
    bbMask  = AttackTables[n*64+lid];
    bbMoves = (kic==stm)?(bbMask&bbTemp&bbOpp):(bbMask&bbTemp);
    // verify non captures
    bbMask  = (GETPTYPE(pfrom)==PAWN)?(AttackTablesPawnPushes[stm*64+lid]):bbMask;
    bbMoves|= (kic==stm&&!qs)?(bbMask&bbTemp&~bbBlockers):BBEMPTY; 

    // collect opp attacks
    barrier(CLK_LOCAL_MEM_FENCE);
    if (kic!=stm)
      atom_or(&bbAttacks, bbMoves);
    // get king checkers
    if (bbMoves&SETMASKBB(sqking))
    {
      sqchecker = lid;
      atom_or(&bbCheckers, SETMASKBB(lid));
    }
    barrier(CLK_LOCAL_MEM_FENCE);

    rootkic = (bbCheckers)?true:false;

    // extract only own moves
    bbMoves = (kic==stm)?bbMoves:BBEMPTY;

    n = count1s(bbCheckers);

    // double check, king moves only
    tmpb = (n>=2&&GETPTYPE(pfrom)!=KING)?true:false;
    bbMoves = (tmpb)?BBEMPTY:bbMoves;

    // consider pinned pieces
    tmpb = (SETMASKBB(lid)&bbPinned)?true:false;
    bbMoves &= (tmpb)?bbLine[lid*64+sqking]:BBFULL;

    // consider king and opp attacks
    tmpb = (GETPTYPE(pfrom)==KING)?true:false;
    bbMoves &= (tmpb)?~bbAttacks:BBFULL;

    // consider single checker
    tmpb = (n==1&&GETPTYPE(pfrom)!=KING)?true:false;
    bbMoves &= (tmpb)?(bbInBetween[sqchecker*64+sqking]|bbCheckers):BBFULL;

    // gen en passant moves, TODO: reimplement, x64?
    bbTemp = BBEMPTY;
    sqep   = GETSQEP(board[QBBLAST]); 
    if (sqep)
    {
      bbMask  = bbMe&(board[QBBP1]&~board[QBBP2]&~board[QBBP3]); // get our pawns
      bbMask &= (stm)?0xFF000000UL:0xFF00000000UL;
      bbTemp  = bbMask&(SETMASKBB(sqep+1)|SETMASKBB(sqep-1));
    }
    // check for en passant pawns
    if (bbTemp&SETMASKBB(lid))
    {
      pto     = pfrom;
      sqcpt   = sqep;
      pcpt    = GETPIECE(board, sqcpt);
      sqto    = (stm)? sqep-8:sqep+8;
      // pack move into 64 bits, considering castle rights and halfmovecounter and score
      move    = MAKEMOVE((Move)lid, (Move)sqto, (Move)sqcpt, (Move)pfrom, (Move)pto, (Move)pcpt, 0x0UL, 0x0UL, 0x0UL);
      // legal moves only
      domovequick(board, move);
      kic = squareunderattack(board, !stm, sqking);
      undomovequick(board, move);
      if (!kic)
      {
        bbMoves |= SETMASKBB(sqto);
      }
    }
    // TODO: speedup
    // gen castle moves queenside
    tmpb = (lid==sqking&&!qs&&(board[QBBPMVD]&SMCRALL)&&((stm&&(((~board[QBBPMVD])&SMCRBLACKQ)==SMCRBLACKQ))||(!stm&&(((~board[QBBPMVD])&SMCRWHITEQ)==SMCRWHITEQ))))?true:false;
    if (tmpb)
    { 
      // get king square
      sqto    = lid-2;
      // rook present
      bbTemp  = (GETPIECE(board, lid-4)==MAKEPIECE(ROOK,GETCOLOR(pfrom)))?true:false;
      // check for empty squares
      bbMask  = ((bbBlockers&SETMASKBB(lid-1))|(bbBlockers&SETMASKBB(lid-2))|(bbBlockers&SETMASKBB(lid-3)));
      // check for king and empty squares in check
      bbWork =  (bbAttacks&SETMASKBB(lid))|(bbAttacks&SETMASKBB(lid-1))|(bbAttacks&SETMASKBB(lid-2));
      // store move
      if (bbTemp&&!bbMask&&!bbWork)
      {
        bbMoves |= SETMASKBB(sqto);
      }
    }
    // gen castle moves kingside
    tmpb =  (lid==sqking&&!qs&&(board[QBBPMVD]&SMCRALL)&&((stm&&(((~board[QBBPMVD])&SMCRBLACKK)==SMCRBLACKK))||(!stm&&(((~board[QBBPMVD])&SMCRWHITEK)==SMCRWHITEK))))?true:false;
    if (tmpb)
    {
      sqto    = lid+2;
      // rook present
      bbTemp  = (GETPIECE(board, lid+3)==MAKEPIECE(ROOK,GETCOLOR(pfrom)))?true:false;
      // check for empty squares
      bbMask  = ((bbBlockers&SETMASKBB(lid+1))|(bbBlockers&SETMASKBB(lid+2)));
      // check for king and empty squares in check
      bbWork =  (bbAttacks&SETMASKBB(lid))|(bbAttacks&SETMASKBB(lid+1))|(bbAttacks&SETMASKBB(lid+2));
      // store move
      if (bbTemp&&!bbMask&&!bbWork)
      {
        bbMoves |= SETMASKBB(sqto);
      }
    }

    // ################################
    // ####     movepicker x64     ####
    // ################################
    // move picker, extract moves x64 parallel
    n       = 0;
    score   = -INF;
    // get move from hash table
    move = board[QBBHASH]&(ttindex-1);
    ttmove = ((TT[move].hash==(board[QBBHASH]^TT[move].bestmove))&&TT[move].flag>FAILLOW)?(Move)((TT[move].bestmove)&SMTTMOVE):MOVENONE;
    move    = MOVENONE;

    while(bbMoves)
    {
      sqto  = popfirst1(&bbMoves);
      sqcpt = sqto; 
      // set en passant target square
      sqep  = (GETPTYPE(pfrom)==PAWN&&GETRRANK(sqto,stm)-GETRRANK(lid,stm)==2)?sqto:0x0; 
      // get piece captured
      pcpt  = GETPIECE(board, sqcpt);
      // check for en passant capture square
      if (GETPTYPE(pfrom)==PAWN&&stm&&lid-sqto!=8&&lid-sqto!=16&&pcpt==PNONE)
      {
        sqcpt = (stm)? sqto+8:sqto-8;
      }
      if (GETPTYPE(pfrom)==PAWN&&!stm&&sqto-lid!=8&&sqto-lid!=16&&pcpt==PNONE)
      {
        sqcpt = (stm)? sqto+8:sqto-8;
      }
      pcpt  = GETPIECE(board, sqcpt);
      pto   = pfrom;
      // set pawn prommotion, queen
      pto   = (GETPTYPE(pfrom)==PAWN&&GETRRANK(sqto,stm)==RANK_8)?MAKEPIECE(QUEEN,GETCOLOR(pfrom)):pfrom;

      // make move
      tmpmove  = MAKEMOVE((Move)lid, (Move)sqto, (Move)sqcpt, (Move)pfrom, (Move)pto, (Move)pcpt, (Move)sqep, (u64)GETHMC(board[QBBLAST]), 0x0UL);
      tmpmove |= (GETPTYPE(pfrom)==KING&&lid-sqto==2)?MOVEISCRQ:MOVENONE;
      tmpmove |= (GETPTYPE(pfrom)==KING&&sqto-lid==2)?MOVEISCRK:MOVENONE;

      atom_inc(&movecount);
      n++;
      // eval move
      // wood count and piece square tables, pto-pfrom   
      tmpscore = EvalPieceValues[GETPTYPE(pto)]+EvalTable[GETPTYPE(pto)*64+((stm)?sqto:FLIPFLOP(sqto))]+EvalControl[((stm)?sqto:FLIPFLOP(sqto))];
      tmpscore-= EvalPieceValues[GETPTYPE(pfrom)]+EvalTable[GETPTYPE(pfrom)*64+((stm)?lid:FLIPFLOP(lid))]+EvalControl[((stm)?lid:FLIPFLOP(lid))];
      // MVV-LVA
      tmpscore = (pcpt!=PNONE)?EvalPieceValues[GETPTYPE(pcpt)]*16-EvalPieceValues[GETPTYPE(pto)]:tmpscore;
      tmpscore = tmpscore*1000+lid*64+n;

      // set hash table move score
      if (JUSTMOVE(ttmove)==JUSTMOVE(tmpmove))
        tmpscore = INF-100;
      // ignore moves already searched
      if (tmpscore>=localMoveIndexScore[sd])
        continue;
      // get move with highest score
      if (tmpscore<=score)
        continue;
      score = tmpscore;
      move = tmpmove;
    }

    // get sorted next move and store to local memory
    barrier(CLK_LOCAL_MEM_FENCE);
    // get sorted next move and store to local memory
    atom_max(&lscore, score);
    barrier(CLK_LOCAL_MEM_FENCE);
    tmpscore = atom_cmpxchg(&lscore, score, score);
    if (tmpscore==score&&move!=MOVENONE)
    {
      lmove = move;
      localMoveIndexScore[sd] = score;
      // TT hit counter
      if (ttmove!=MOVENONE&&JUSTMOVE(ttmove)==JUSTMOVE(lmove))
        COUNTERS[gid*64+3]++;
    }
    barrier(CLK_LOCAL_MEM_FENCE);
    // ################################
    // ####     evaluation x64      ###
    // ################################
    lscore  = 0;
    pfrom   = GETPIECE(board, lid);
    kic     = GETCOLOR(pfrom); // get color to work on
    pfrom   = GETPTYPE(pfrom);
    bbBlockers = board[1]|board[2]|board[3];
    bbMask  = board[QBBP1]&~board[QBBP2]&~board[QBBP3]; // get all pawns
    bbMe    =  (kic)?board[QBBBLACK]:board[QBBBLACK]^bbBlockers;
    bbOpp   = (!kic)?board[QBBBLACK]:board[QBBBLACK]^bbBlockers;
    tmpscore= 0;
    // piece bonus
    tmpscore+= (pfrom!=PNONE)?(kic)?-10:10:0;
    // wood count
    tmpscore+= (pfrom!=PNONE)?(kic)?-EvalPieceValues[pfrom]:EvalPieceValues[pfrom]:0;
    // piece square tables
    tmpscore+= (pfrom!=PNONE)?(kic)?-EvalTable[pfrom*64+lid]:EvalTable[pfrom*64+FLIPFLOP(lid)]:0;
    // square control table
    tmpscore+= (pfrom!=PNONE)?(kic)?-EvalControl[lid]:EvalControl[FLIPFLOP(lid)]:0;
    // simple pawn structure white
    if (pfrom==PAWN&&kic==WHITE)
    {
      // blocked
      tmpscore-=(GETRANK(lid)<RANK_8&&(bbOpp&SETMASKBB(lid+8)))?15:0;
        // chain
      tmpscore+=(GETFILE(lid)<FILE_H&&(bbMask&bbMe&SETMASKBB(lid-7)))?10:0;
      tmpscore+=(GETFILE(lid)>FILE_A&&(bbMask&bbMe&SETMASKBB(lid-9)))?10:0;
      // column, TODO: popcount based
      for(sqto=lid-8;sqto>7;sqto-=8)
        tmpscore-=(bbMask&bbMe&SETMASKBB(sqto))?30:0;
    }
    // simple pawn structure black
    if (pfrom==PAWN&&kic==BLACK)
    {
      // blocked
      tmpscore+=(GETRANK(lid)>RANK_1&&(bbOpp&SETMASKBB(lid-8)))?15:0;
        // chain
      tmpscore-=(GETFILE(lid)>FILE_A&&(bbMask&bbMe&SETMASKBB(lid+7)))?10:0;
      tmpscore-=(GETFILE(lid)<FILE_H&&(bbMask&bbMe&SETMASKBB(lid+9)))?10:0;
      // column, TODO: popcount based
      for(sqto=lid+8;sqto<56;sqto+=8)
        tmpscore+=(bbMask&bbMe&SETMASKBB(sqto))?30:0;
    }
    // duble bishop
    if (lid==0)
    {
      tmpscore-= (count1s(board[QBBBLACK]&(~board[QBBP1]&~board[QBBP2]&board[QBBP3]))==2)?25:0;
      tmpscore+= (count1s((board[QBBBLACK]^bbBlockers)&(~board[QBBP1]&~board[QBBP2]&board[QBBP3]))==2)?25:0;
    }
    // store scores in local memory
    barrier(CLK_LOCAL_MEM_FENCE);
    atom_add(&lscore, tmpscore);
    barrier(CLK_LOCAL_MEM_FENCE);
    score = lscore;
    // negamaxed scores
    score = (stm)?-score:score;
    // checkmate
    score = (!qs&&rootkic&&movecount==0)?-INF+sd:score;
    // stalemate
    score = (!qs&&!rootkic&&movecount==0)?STALEMATESCORE:score;

    // draw by 3 fold repetition, x1
    for (n=ply+ply_init-2;lid==0&&n>=ply+ply_init-(s32)GETHMC(board[QBBLAST])&&!qs&&sd>1;n-=2)
    {
      if (board[QBBHASH]==HashHistory[gid*MAXGAMEPLY+n])
      {
        movecount = 0;
        lmove = MOVENONE;
        score = DRAWSCORE;
        break;
      }
    }
    // #################################
    // ####      alphabeta flow  x1  ###
    // #################################
    if (lid==0)
    {
      // check bounds
      if (sd>=MAXPLY)
      {
        movecount = 0;
        mode = MOVEDOWN;
      }
      // nodecounter
      if (mode==MOVEUP)
        COUNTERS[gid*64+0]++;
      // leaf node
      if (mode==MOVEUP&&movecount==0)
      {
        localAlphaBetaScores[sd*2+ALPHA] = score;
        mode = MOVEDOWN;
      }
      // last child node
      else if (mode==MOVEUP&&lmove==MOVENONE&&movecount>0)
      {
        movecount = 0;
        mode = MOVEDOWN;
      }
      // stand pat in qsearch
      // return beta
      if (mode==MOVEUP&&qs&&!rootkic&&score>=localAlphaBetaScores[sd*2+BETA])
      {
  //      localAlphaBetaScores[sd*2+ALPHA] = localAlphaBetaScores[sd*2+BETA]; // fail hard
        localAlphaBetaScores[sd*2+ALPHA] = score; // fail soft
      }
      // stand pat in qsearch
      // set alpha
      if (mode==MOVEUP&&qs&&!rootkic)
      {
        if (score>localAlphaBetaScores[sd*2+ALPHA])
          localAlphaBetaScores[sd*2+ALPHA]=score;
		  }
      // apply alphabeta pruning
      if (localAlphaBetaScores[sd*2+ALPHA]>=localAlphaBetaScores[sd*2+BETA])
      {
        movecount = 0;
			  mode = MOVEDOWN;
      }
    }
    barrier(CLK_LOCAL_MEM_FENCE);
    // ################################
    // ####         moveup         ####
    // ################################
    // move up in tree
    if (lid==0&&mode==MOVEUP)
    {
      // set history
      localMoveHistory[sd]  = lmove;
      localCrHistory[sd]    = board[QBBPMVD];
      localHashHistory[sd]  = board[QBBHASH];
      HashHistory[gid*MAXGAMEPLY+ply+ply_init] = board[QBBHASH];
    }
    // domove x64
    if (mode==MOVEUP)
    {
      domove(board, lmove);
      stm = !stm; // switch site to move
      sd++;       // increase depth counter
      ply++;      // increase ply counter
    }
    if (lid==0&&mode==MOVEUP)
    {
      // set values for next depth
      localAlphaBetaScores[sd*2+ALPHA]  = -localAlphaBetaScores[(sd-1)*2+BETA];
      localAlphaBetaScores[sd*2+BETA]   = -localAlphaBetaScores[(sd-1)*2+ALPHA];
      localMoveIndexScore[sd]           = INF;
    }
    // ################################
    // ####        movedown        ####
    // ################################
    // undomove x64
    if (mode==MOVEDOWN)
    {
      sd--;
      ply--;
      stm = !stm; // switch site to move

      undomove( board, 
                localMoveHistory[sd],
                localMoveHistory[sd-1],
                localCrHistory[sd], 
                localHashHistory[sd]
              );
    }
    // do negamax scoring and hash table
    if (lid==0&&mode==MOVEDOWN)
    {

      u8 flag = FAILLOW; // hash table flag;

      score = -localAlphaBetaScores[(sd+1)*2+ALPHA];

      // do alphabeta negamax scoring
      if (score>localAlphaBetaScores[sd*2+ALPHA]&&!ISINF(score))
      {

        flag = EXACTSCORE; // hash table flag

        localAlphaBetaScores[sd*2+ALPHA]=score;
        // get bestmove, TODO: via upcoming hashtable, collect PV
        if (sd==1&&!ISINF(score))
        {
          COUNTERS[gid*64+1] = (u64)score;
          COUNTERS[gid*64+2] = localMoveHistory[sd];
        }
      }
      if (score>=localAlphaBetaScores[sd*2+BETA])
        flag = FAILHIGH; // hash table flag 

      // save to hash table
      if (!qs&&flag>FAILLOW) // no qsearch
      {
        tmpmove = board[QBBHASH]&(ttindex-1);
        move  = (TTMove)(localMoveHistory[sd]&SMTTMOVE);
        // one bucket, depth replace
        if ((u8)search_depth>TT[tmpmove].depth)
        {
          TT[tmpmove].hash      = board[QBBHASH]^move;
          TT[tmpmove].bestmove  = move;
          TT[tmpmove].score     = (TTScore)score;
          TT[tmpmove].flag      = EXACTSCORE;
          TT[tmpmove].depth     = (u8)search_depth;
        }
      }
    }
    barrier(CLK_LOCAL_MEM_FENCE);
    if (lid==0)
    {
      // root node finished, exit
      mode = (sd<1)?EXIT:MOVEUP;
      // node count based termination
      mode = (COUNTERS[0]>max_nodes)?EXIT:mode;
    }
    barrier(CLK_LOCAL_MEM_FENCE);
  } // end main loop
//  COUNTERS[gid*64+0] = *NODECOUNTER;
}

