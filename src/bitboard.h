/*
  Name:         Zeta
  Description:  Experimental chess engine written in OpenCL.
  Author:       Srdja Matovic <s.matovic@app26.de>
  Created at:   2011-01-15
  Updated at:   2018
  License:      GPL >= v2

  Copyright (C) 2011-2018 Srdja Matovic

  Zeta is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 2 of the License, or
  (at your option) any later version.

  Zeta is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.
*/

#ifndef BITBOARD_H_INCLUDED
#define BITBOARD_H_INCLUDED

#include "types.h"

bool squareunderattack(Bitboard *board, bool stm, Square sq);
Square getkingpos(Bitboard *board, bool side);
bool isvalid(Bitboard *board);
void domove(Bitboard *board, Move move);
void undomove(Bitboard *board, Move move, Cr cr, Hash hash, u64 hmc);
Hash computehash(Bitboard *board, bool stm);

#endif /* BITBOARD_H_INCLUDED */

