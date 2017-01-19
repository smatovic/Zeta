/*
  Name:         Zeta
  Description:  Experimental chess engine written in OpenCL.
  Author:       Srdja Matovic <s.matovic@app26.de>
  Created at:   2011-01-15
  Updated at:   2017
  License:      GPL >= v2

  Copyright (C) 2011-2017 Srdja Matovic

  Zeta is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 2 of the License, or
  (at your option) any later version.

  Zeta is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.
*/

#ifndef TYPES_H_INCLUDED
#define TYPES_H_INCLUDED

#include <inttypes.h>   // for nice u64 printf 
 
#include "CL/cl.h"    // for OpenCL data types etc.

// OpenCL data types to own
typedef cl_ulong u64;
typedef cl_long s64;
typedef cl_uint u32;
typedef cl_int s32;
typedef cl_short s16;
typedef cl_uchar u8;
typedef cl_bool bool;
// boolean val
#define true  1
#define false 0

typedef u64 Move;
typedef u64 Bitboard;
typedef u64 Cr;
typedef u64 Hash;

typedef u32     TTMove;
typedef s32     MoveScore;
typedef s16     Score;
typedef s16     TTScore;
typedef u8      Square;
typedef u8      Piece;

typedef u8 File;
typedef u8 Rank;

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
#define MAXPLY      64      // max internal search ply
#define MAXGAMEPLY  1024    // max ply a game can reach
#define MAXMOVES    256     // max amount of legal moves per position
#define TIMESPARE   100     // 100 milliseconds spare
#define MINDEVICEMB 64ULL   // min memory of OpenCl device in MB
#define MAXDEVICEMB 1024ULL // max memory for OpenCL devices in MB
#define MAXSLOTS    4       // max memory slots for OpenCL devices
// colors
#define BLACK               1
#define WHITE               0
// scores
#define INF                 32000
#define MATESCORE           30000
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
#define MOVEISCR            0x0000003000000000ULL
#define MOVEISCRK           0x0000001000000000ULL
#define MOVEISCRQ           0x0000002000000000ULL
// bitboard masks, computation prefered over lookup
#define SETMASKBB(sq)       (1ULL<<(sq))
#define CLRMASKBB(sq)       (~(1ULL<<(sq)))
// u64 defaults
#define BBEMPTY             0x0000000000000000ULL
#define BBFULL              0xFFFFFFFFFFFFFFFFULL
#define MOVENONE            0x0000000000000000ULL
#define NULLMOVE            0x0000000000000041ULL
#define HASHNONE            0x0000000000000000ULL
#define CRNONE              0x0000000000000000ULL
#define SCORENONE           0x0000000000000000ULL
// set masks
#define SMMOVE              0x0000003FFFFFFFFFULL
#define SMSQEP              0x0000000FC0000000ULL
#define SMHMC               0x0000FF0000000000ULL
#define SMCRALL             0x8900000000000091ULL
#define SMSCORE             0xFFFF000000000000ULL
#define SMTTMOVE            0x000000003FFFFFFFULL
// clear masks
#define CMMOVE              0xFFFFFFC000000000ULL
#define CMSQEP              0xFFFFFFF03FFFFFFFULL
#define CMHMC               0xFFFF00FFFFFFFFFFULL
#define CMCRALL             0x76FFFFFFFFFFFF6EULL
#define CMSCORE             0x0000FFFFFFFFFFFFULL
#define CMTTMOVE            0xFFFFFFFFC0000000ULL
// castle right masks
#define SMCRWHITE           0x0000000000000091ULL
#define SMCRWHITEQ          0x0000000000000011ULL
#define SMCRWHITEK          0x0000000000000090ULL
#define SMCRBLACK           0x9100000000000000ULL
#define SMCRBLACKQ          0x1100000000000000ULL
#define SMCRBLACKK          0x9000000000000000ULL
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
#define BBFILEA             0x0101010101010101ULL
#define BBFILEB             0x0202020202020202ULL
#define BBFILEC             0x0404040404040404ULL
#define BBFILED             0x0808080808080808ULL
#define BBFILEE             0x1010101010101010ULL
#define BBFILEF             0x2020202020202020ULL
#define BBFILEG             0x4040404040404040ULL
#define BBFILEH             0x8080808080808080ULL
#define BBNOTHFILE          0x7F7F7F7F7F7F7F7FULL
#define BBNOTAFILE          0xFEFEFEFEFEFEFEFEULL
// rank enumeration
enum Ranks
{
  RANK_1, RANK_2, RANK_3, RANK_4, RANK_5, RANK_6, RANK_7, RANK_8, RANK_NONE
};
#define BBRANK7             0x00FF000000000000ULL
#define BBRANK5             0x000000FF00000000ULL
#define BBRANK4             0x00000000FF000000ULL
#define BBRANK2             0x000000000000FF00ULL
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
// is score a draw, unprecise
#define ISDRAW(val) ((val==DRAWSCORE)?true:false)
// is score a mate in n
#define ISMATE(val) \
((((val)>MATESCORE&&(val)<INF)||((val)<-MATESCORE&&(val)>-INF))?true:false)
// is score default inf
#define ISINF(val) \
(((val)==INF||(val)==-INF)?true:false)
// node type flags

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
#define EXACTSCORE      2
#define FAILHIGH        1
#define FAILLOW         0

#endif // TYPES_H_INCLUDED

