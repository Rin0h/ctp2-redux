#ifdef HAVE_PRAGMA_ONCE
#pragma once
#endif
#ifndef _NET_UTIL_H_
#define _NET_UTIL_H_

#include <string.h>     // memcpy
#include "gstypes.h"    // k_MAX_PLAYERS

#if defined(WIN32) || !defined(WORDS_BIGENDIAN)
#define NET_UTIL_LITTLE_ENDIAN
#endif

#ifdef NET_UTIL_LITTLE_ENDIAN
inline sint8 getbyte(uint8 *b)
{
	return *(sint8*)b;
}

inline sint16 getshort(uint8* b)
{
	return *(sint16*)b;
}

inline sint32 getlong(uint8* b)
{
	return *(sint32*)b;
}

inline sint64 getlong64(uint8* b)
{
	return *(sint64*)b;
}

inline double getdouble(uint8* b)
{
	return *(double*)b;
}

inline void putbyte(uint8* b, sint8 by)
{
	*b = by;
}

inline void putshort(uint8* b, sint16 s)
{
	*(sint16*)b = s;
}

inline void putlong(uint8* b, sint32 l)
{
	*(sint32*)b = l;
}

inline void putlong64(uint8* b, sint64 l)
{
	*(sint64*)b = l;
}
inline void putdouble(uint8* b, double l)
{
	*(double*)b = l;
}

#define NET_STRLEN(x)   static_cast<uint16>(strlen(x))

#define PUSHBYTE(x)    {buf[size++] = static_cast<uint8>(x);}
#define PUSHSHORT(x)  {putshort(&buf[size], static_cast<uint16>(x)); size += sizeof(uint16);}
#define PUSHLONG(x)   {putlong(&buf[size], static_cast<uint32>(x)); size += sizeof(uint32);}
#define PUSHLONG64(x) {putlong64(&buf[size], static_cast<uint64>(x)); size += sizeof(uint64);}
#define PUSHDOUBLE(x) {putdouble(&buf[size], (x)); size += sizeof(double);}
#define PUSHID(x) {buf[size++] = ((x) >> 8); buf[size++] = ((x) & 0xff); }
#define PUSHSTRING(x) { uint16 l = ((x) ? (NET_STRLEN(x)) : 0); PUSHSHORT(l); if(l > 0) {memcpy(&buf[size], x, l); size += l;}}

// ctp2-redux: every PULL macro checks its read against `size`, the length of
// the packet (or of the map file chunk). A packet whose contents run past
// its end is broken or forged: the read throws NetPacketError and the packet
// is thrown away as a whole (caught in Network::PacketReady and
// MapFile::LoadMap) instead of being read on behind the buffer. Strings are
// cut to their target array; before, they were copied with the length the
// packet gave, onto the stack. NET_CHECK and NET_PLAYER do the same for
// values from a packet that are used as counts or array indices.
struct NetPacketError {};

inline void net_Need(sint32 pos, sint32 count, sint32 size)
{
	if(pos < 0 || count < 0 || pos > size - count)
		throw NetPacketError();
}

#define NET_CHECK(cond) { if(!(cond)) throw NetPacketError(); }

// a player index from a packet
inline sint32 net_PlayerIndex(sint32 index)
{
	if(index < 0 || index >= k_MAX_PLAYERS)
		throw NetPacketError();
	return index;
}
#define NET_PLAYER(x) net_PlayerIndex(static_cast<sint32>(x))

// an index from a packet into a list of count entries (database records,
// enum values)
inline sint32 net_Index(sint32 index, sint32 count)
{
	if(index < 0 || index >= count)
		throw NetPacketError();
	return index;
}
#define NET_INDEX(x, count) net_Index(static_cast<sint32>(x), static_cast<sint32>(count))

// a map position from a packet (needs MapPoint.h): on the map, or the
// "no position" (-1,-1) where the game uses that
#define NET_POS(p) NET_CHECK((p).IsValid())
#define NET_POS_OR_NONE(p) NET_CHECK((p).IsValid() || ((p).x == -1 && (p).y == -1))

// names from a packet: no real one is longer (the input fields allow 23 and
// 50 characters), and the game copies names into buffers of 256 and less
#define k_NET_MAX_NAME 64
inline void net_Cut(char *s, size_t length)
{
	if(strlen(s) > length)
		s[length] = 0;
}

// a string into a fixed array (a pointer as target does not compile)
template <typename T, size_t N>
inline sint32 net_PullString(T (&target)[N], uint8 *buf, sint32 pos, sint32 size)
{
	net_Need(pos, sizeof(uint16), size);
	uint16 const len = static_cast<uint16>(getshort(&buf[pos]));
	pos += sizeof(uint16);
	net_Need(pos, len, size);
	size_t const kept = len < N ? len : N - 1;
	memcpy(target, &buf[pos], kept);
	target[kept] = 0;
	return pos + len;
}

#define PULLBYTE(x)   {net_Need(pos, 1, size); x = buf[pos++];}
#define PULLBYTETYPE(x,ty) {net_Need(pos, 1, size); x = (ty)buf[pos++];}
#define PULLSHORT(x)  {net_Need(pos, sizeof(uint16), size); x = getshort(&buf[pos]); pos += sizeof(uint16);}
#define PULLSHORTTYPE(x, ty)  {net_Need(pos, sizeof(uint16), size); x = (ty)getshort(&buf[pos]); pos += sizeof(uint16);}
#define PULLLONG(x)   {net_Need(pos, sizeof(uint32), size); x = getlong(&buf[pos]); pos += sizeof(uint32);}
#define PULLLONGTYPE(x,ty) {net_Need(pos, sizeof(uint32), size); x = (ty)getlong(&buf[pos]); pos += sizeof(uint32);}
#define PULLLONG64(x) {net_Need(pos, sizeof(uint64), size); x = getlong64(&buf[pos]); pos += sizeof(uint64);}
#define PULLDOUBLE(x) {net_Need(pos, sizeof(double), size); x = getdouble(&buf[pos]); pos += sizeof(double);}
#define PULLID(x) {net_Need(pos, 2, size); x = (buf[pos] << 8) | (buf[pos+1]); pos += 2;}
#define PULLSTRING(x) { pos = net_PullString(x, buf, pos, size); }
#define PULLNEWSTRING(x) { uint16 l; PULLSHORT(l); if(l > 0) {net_Need(pos, l, size); x = new char[l + 1]; memcpy(x, &buf[pos], l); (x)[l] = 0; pos += l;} else { x = NULL; }}

#else

#error "Little endian byte order not implemented"

#endif

#endif
