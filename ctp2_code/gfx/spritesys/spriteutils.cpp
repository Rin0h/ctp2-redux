//----------------------------------------------------------------------------
//
// Project      : Call To Power 2
// File type    : C++ source
// Description  : Tile utilities
// Id           : $Id$
//
//----------------------------------------------------------------------------
//
// Disclaimer
//
// THIS FILE IS NOT GENERATED OR SUPPORTED BY ACTIVISION.
//
// This material has been developed at apolyton.net by the Apolyton CtP2
// Source Code Project. Contact the authors at ctp2source@apolyton.net.
//
//----------------------------------------------------------------------------
//
// Compiler flags
//
// CLEAN_INSTEAD_OF_CONVERT
//
//----------------------------------------------------------------------------
//
// Modifications from the original Activision code:
//
// - Removed unused local variables. (Sep 9th 2005 Martin Gühmann)
// - Repaired memory leaks.
//
//----------------------------------------------------------------------------

#include "c3.h"

#include <algorithm>
#include <map>
#include <vector>

#include "pixelutils.h"
#include "spriteutils.h"
#include "CivPaths.h"                  // g_civPaths

extern sint32 g_is565Format;

void spriteutils_EncodeShadowRun(Pixel32 **inBuf, sint32 *pos, sint32 width, Pixel16 **outBufPtr)
{
	Pixel16         pix16;
	uint8           alpha;
	sint32          runLen = 0;
	Pixel16         footer=0;
	Pixel16         shadowPixel;

	if (g_is565Format) shadowPixel = k_SHADOW_PIXEL_565;
	else shadowPixel = k_SHADOW_PIXEL_555;

	RGB32Info(**inBuf, &pix16, &alpha);
	while (pix16 == shadowPixel && (*pos < width)) {

		(*inBuf)++;

		(*pos)++;

		runLen++;

		RGB32Info(**inBuf, &pix16, &alpha);
	}

	footer = (Pixel16)(k_SHADOW_RUN_ID << 8 | runLen);

	if (*pos >= width) footer |= k_EOLN_ID << 8;

	**outBufPtr = footer;
	(*outBufPtr)++;
}

void spriteutils_EncodeCopyRun(Pixel32 **inBuf, sint32 *pos, sint32 width, Pixel16 **outBufPtr)
{
	Pixel16         pix16;
	uint8           alpha;
	sint32          runLen = 0;
	Pixel16         footer=0;
	Pixel16         *headerPtr;
	Pixel16         shadowPixel;

	if (g_is565Format) {
		shadowPixel = k_SHADOW_PIXEL_565;
	} else {
		shadowPixel = k_SHADOW_PIXEL_555;
	}

	headerPtr = *outBufPtr;
	(*outBufPtr)++;

	RGB32Info(**inBuf, &pix16, &alpha);

	while (pix16 != shadowPixel && alpha == k_ALL_ALPHA && (*pos < width)) {

		if (pix16 == 0x0000) pix16 = 0x0001;

		**outBufPtr = pix16;

		(*outBufPtr)++;

		(*inBuf)++;

		(*pos)++;

		runLen++;

		RGB32Info(**inBuf, &pix16, &alpha);
	}

	footer = (Pixel16) (k_COPY_RUN_ID << 8 | runLen);

	if (*pos >= width) footer |= k_EOLN_ID << 8;

	*headerPtr = footer;
}

char spriteutils_EncodeChromakeyRun(Pixel32 **inBuf, sint32 *pos, sint32 width, Pixel16 **outBufPtr)
{
	Pixel16         pix16;
	uint8           alpha;
	sint32          runLen = 0;
	Pixel16         footer=0;

	RGB32Info(**inBuf, &pix16, &alpha);
	while (pix16 == k_CHROMAKEY_PIXEL && alpha == k_NO_ALPHA && (*pos < width)) {

		(*inBuf)++;

		(*pos)++;

		runLen++;

		RGB32Info(**inBuf, &pix16, &alpha);
	}

	if (runLen < width) {

		footer = (Pixel16)(k_CHROMAKEY_RUN_ID << 8 | runLen);

		if (*pos >= width) footer |= k_EOLN_ID << 8;

		**outBufPtr = footer;
		(*outBufPtr)++;
	} else {

		return TRUE;
	}

	return FALSE;
}

char spriteutils_EncodeChromakeyWshadowRun(Pixel32 **inBuf, sint32 *pos, sint32 width, Pixel16 **outBufPtr)
{
	Pixel16         pix16;
	uint8           alpha;
	sint32          runLen = 0;
	Pixel16         footer=0;

	RGB32Info(**inBuf, &pix16, &alpha);
	while ( ((pix16 == k_CHROMAKEY_PIXEL && alpha == k_NO_ALPHA) ||  (pix16 == k_SHADOWBACKGD_PIXEL))  && (*pos < width) ) {

		(*inBuf)++;

		(*pos)++;

		runLen++;

		RGB32Info(**inBuf, &pix16, &alpha);
	}

	if (runLen < width) {

		footer = (Pixel16)(k_CHROMAKEY_RUN_ID << 8 | runLen);

		if (*pos >= width) footer |= k_EOLN_ID << 8;

		**outBufPtr = footer;
		(*outBufPtr)++;
	} else {

		return TRUE;
	}

	return FALSE;
}

void spriteutils_EncodeFeatheredRun(Pixel32 **inBuf, sint32 *pos, sint32 width, Pixel16 **outBufPtr)
{
	Pixel16         pix16;
	Pixel16         footer=0;
	uint8           alpha;

	RGB32Info(**inBuf, &pix16, &alpha);

	if (pix16 == 0x0000) pix16 = 0x0001;

	(*inBuf)++;
	(*pos)++;

	footer = (k_FEATHERED_RUN_ID << 8) | alpha;

	if (*pos >= width)
		footer |= k_EOLN_ID << 8;

	**outBufPtr = footer;
	(*outBufPtr)++;

	**outBufPtr = pix16;
	(*outBufPtr)++;

}

char spriteutils_EncodeScanline(Pixel32 *scanline, sint32 width, Pixel16 **outBufPtr)
{
	Pixel16         pix16;
	Pixel32         pix32;
	Pixel32         *scanPtr = scanline;
	uint8           alpha;
	sint32          pos;
	BOOL            empty = FALSE;
	Pixel16         shadowPixel;

	if (g_is565Format) {
		shadowPixel = k_SHADOW_PIXEL_565; // 0xF81F
	} else {
		shadowPixel = k_SHADOW_PIXEL_555; // 0x7C1F
	}

	pos = 0;

	while (scanPtr < (scanline + width))
	{
		pix32 = *scanPtr;

		empty = FALSE;

		RGB32Info(pix32, &pix16, &alpha);






		// k_CHROMAKEY_PIXEL  0x0000   k_NO_ALPHA  0x00   k_ALL_ALPHA  0xFF
		if ((pix16 == k_CHROMAKEY_PIXEL)&&(alpha == k_NO_ALPHA))

		{

			empty = spriteutils_EncodeChromakeyRun(&scanPtr, &pos, width, outBufPtr);
		}
		else
		if (pix16 == shadowPixel) // i.e. pix32 == 0x..FF00FF (magenta)
		{

			spriteutils_EncodeShadowRun(&scanPtr, &pos, width, outBufPtr);
		}
		else
		if ((alpha!=k_NO_ALPHA) && (alpha!=k_ALL_ALPHA)) // 0x00   0xFF
		{

			spriteutils_EncodeFeatheredRun(&scanPtr, &pos, width, outBufPtr);
		}
		else {

			if (alpha == k_ALL_ALPHA) // 0xFF
				spriteutils_EncodeCopyRun(&scanPtr, &pos, width, outBufPtr);
			else
			{

				printf("\nError in bitmap data.  Pixel with no associated alpha.\n");
			        fprintf(stderr, "%s L%d: pix32: %08X pix16: %04X alpha: %02X \n", __FILE__, __LINE__, pix32, pix16, alpha);
				printf("\nMake sure to assign black to fully transparent pixels!\n");
				printf("\nUse e.g. ImageMagick: mogrify -background black -alpha Background -type TrueColorMatte *.TIF\n");

				exit(-1);
			}
		}
	}

	return empty;
}

char spriteutils_EncodeScanlineWshadow(Pixel32 *scanline, sint32 width, Pixel16 **outBufPtr)
{
	Pixel16         pix16;
	Pixel32         pix32;
	Pixel32         *scanPtr = scanline;
	uint8           alpha;
	sint32          pos;
	BOOL            empty = FALSE;
	Pixel16         shadowPixel;

	if (g_is565Format) {
		shadowPixel = k_SHADOW_PIXEL_565;
	} else {
		shadowPixel = k_SHADOW_PIXEL_555;
	}

	pos = 0;

	while (scanPtr < (scanline + width)) {
		pix32 = *scanPtr;

		empty = FALSE;

		RGB32Info(pix32, &pix16, &alpha);

		if ( (pix16 == k_CHROMAKEY_PIXEL  && alpha == k_NO_ALPHA) ||  (pix16 == k_SHADOWBACKGD_PIXEL) )
		{

			empty = spriteutils_EncodeChromakeyWshadowRun(&scanPtr, &pos, width, outBufPtr);
		}
		else
		if (pix16 == shadowPixel) {

			spriteutils_EncodeShadowRun(&scanPtr, &pos, width, outBufPtr);
		}
		else
		if (alpha != k_NO_ALPHA && alpha != k_ALL_ALPHA) {

			spriteutils_EncodeFeatheredRun(&scanPtr, &pos, width, outBufPtr);
		}
		else {

			if (alpha == k_ALL_ALPHA)
				spriteutils_EncodeCopyRun(&scanPtr, &pos, width, outBufPtr);
			else {
				printf("\nError in bitmap data.  Pixel with no associated alpha.\n");
			        fprintf(stderr, "%s L%d: pix32: %08X pix16: %04X alpha: %02X \n", __FILE__, __LINE__, pix32, pix16, alpha);
				printf("\nMake sure to assign black to fully transparent pixels!\n");
				printf("\nUse e.g. ImageMagick: mogrify -background black -alpha Background -type TrueColorMatte *.TIF\n");
				exit(-1);
			}
		}
	}

	return empty;
}

void spriteutils_MergeShadowMap(Pixel32 *buf, Pixel32 *shadowBuf, uint16 width, uint16 height)
{
	Pixel32     *pixPtr, pix;
	Pixel32     *shadowPixPtr, shadowPix;


	BOOL        whiteBackground = FALSE;
	if ((*shadowBuf & 0x00FFFFFF) == 0x00FFFFFF) { // only first pixel (disregarding alpha) in shadow image is used to determin bg!
		whiteBackground = TRUE;
	} else {
		if ((*shadowBuf & 0x00FFFFFF) != 0x00000000) { // first pixel in shadow must be black (disregarding alpha)!
			printf("\nShadow file is in invalid format.\n");
			exit(-1);
		}
	}

	for (sint32 j=0; j<height; j++) {
		for (sint32 i=0; i<width; i++) {
			pixPtr = buf + j*width + i;
			shadowPixPtr = shadowBuf + j*width + i;

			pix = *pixPtr;
			shadowPix = *shadowPixPtr;
			shadowPix = shadowPix & 0x00FFFFFF; // mask away alpha value, keep only the color

			if (whiteBackground) {

				if (shadowPix != 0x00FFFFFF) { // if shadowPix is not white

					Pixel16     r, g, b, a;

					RGB32Components(pix, &r, &g, &b, &a); // get alpha of image pixel (not shadow)

					if (a != 0xFF) { // if pix is not fully opaque
						*pixPtr = 0x00FF00FF; // assign magenta to pix, for which RGB32Info yields 0xF81F (k_SHADOW_PIXEL_565)
					}
				}
			} else { // black bg

				if (shadowPix) { // if shadowPix is not black

					Pixel16     r, g, b, a;

					RGB32Components(pix, &r, &g, &b, &a); // get alpha of image pixel (not shadow)

					if (a != 0xFF) { // if pix is not fully opaque
						*pixPtr = shadowPix; // assign color from shadow pixel
					}
				}
			}
		}
	}
}

Pixel16 * spriteutils_RGB32ToEncoded(Pixel32 *buf, Pixel32 *shadowBuf, uint16 width, uint16 height, size_t *size)
{
	Pixel32             *srcPixel = buf;

	Pixel16             *outBuf = new Pixel16[(1+height+width*height)*8];
	Pixel16             *returnBuf = NULL;
	uint16              *table = (uint16 *)outBuf;
	Pixel16             *startOfData;
	Pixel16             *dataPtr, *startDataPtr;
	BOOL                empty;


	if (shadowBuf != NULL)
		spriteutils_MergeShadowMap(buf, shadowBuf, width, height);

	*table++ = (uint16)height;

	startOfData = outBuf + 1 + height;
	dataPtr = startOfData;

	for(sint32 y=0; y<height; y++)
	{
		srcPixel = buf + width * y;

		startDataPtr = dataPtr;

		empty = spriteutils_EncodeScanline(srcPixel, width, &dataPtr);
		if (empty) {
			*table++ = k_EMPTY_TABLE_ENTRY;
		} else {

			*table++ = static_cast<uint16>(startDataPtr - startOfData);
		}
	}

	size_t resultSize = (dataPtr - outBuf);

	returnBuf = new Pixel16[resultSize];

	memcpy(returnBuf, outBuf, resultSize * sizeof(Pixel16));
	delete[] outBuf;
	if (size)
		*size = resultSize * sizeof(Pixel16);

	return returnBuf;
}

Pixel16 * spriteutils_RGB32ToEncoded(Pixel32 *buf, uint16 width, uint16 height, size_t *size)
{
	Pixel32             *srcPixel = buf;

	Pixel16             *outBuf = new Pixel16[(1+height+width*height)*8];
	Pixel16             *returnBuf = NULL;
	uint16              *table = (uint16 *)outBuf;
	Pixel16             *startOfData;
	Pixel16             *dataPtr, *startDataPtr;
	BOOL                empty;


	*table++ = (uint16)height;

	startOfData = outBuf + 1 + height;
	dataPtr = startOfData;

	for(sint32 y=0; y<height; y++) {

		srcPixel = buf + width * y;

		startDataPtr = dataPtr;

		empty = spriteutils_EncodeScanlineWshadow(srcPixel, width, &dataPtr);
		if (empty) {
			*table++ = k_EMPTY_TABLE_ENTRY;
		} else {

			*table++ = static_cast<uint16>(startDataPtr - startOfData);
		}
	}

	size_t resultSize = (dataPtr - outBuf);

	returnBuf = new Pixel16[resultSize];

	memcpy(returnBuf, outBuf, resultSize * sizeof(Pixel16));
	delete[] outBuf;
	if (size)
		*size = resultSize * sizeof(Pixel16);

	return returnBuf;
}

void spriteutils_DecodeToBuffer(Pixel16 *data, sint32 width, sint32 height)
{
	uint32    blendRgbMask = pixelutils_GetBlend16RGBMask();
	uint32    shadowRgbMask = pixelutils_GetShadow16RGBMask();
	Pixel16 * table = data+1;
	Pixel16 * dataStart = table + height * 2;
	Pixel16 * outBuf = (Pixel16 *)malloc(width * height * 8);
	Pixel16 * destPixel = outBuf;

	for(sint32 j=0; j<height; j++) {
		if (table[j*2] != k_EMPTY_TABLE_ENTRY) {
			Pixel16     *rowData;
			Pixel16     tag;

			rowData = dataStart + table[j*2+1];

			tag = *rowData--;

			tag = tag & 0x0FFF;

			while ((tag & 0xF000) == 0) {
				switch ((tag & 0x0F00) >> 8) {
					case k_CHROMAKEY_RUN_ID :
						destPixel += (tag & 0x00FF);
						break;
					case k_COPY_RUN_ID:
						{
							short len = (tag & 0x00FF);

							for (short i=0; i<len; i++) {
								*destPixel++ = *rowData--;
							}

							tag = *rowData--;
						}
						break;
					case k_SHADOW_RUN_ID:
						{
							short len = (tag & 0x00FF);

							for (short i=0; i<len; i++) {
								*destPixel = pixelutils_Shadow16(*destPixel, shadowRgbMask);
								destPixel++;
							}

							tag = *rowData--;
						}
						break;
					case k_FEATHERED_RUN_ID:
						if (TRUE) { // ???
								uint8 alpha = (tag & 0xFF);

								*destPixel = pixelutils_Blend16(*destPixel, *rowData, alpha, blendRgbMask);
								destPixel++;
								rowData--;
						} else {
							*destPixel++ = *rowData--;
						}
						tag = *rowData--;
						break;
					default:
						Assert(FALSE);
				}
				tag = *rowData--;
			}
		}
	}
}

Pixel32	spriteutils_AveragePixel32(Pixel32 pixel1, Pixel32 pixel2, Pixel32 pixel3, Pixel32 pixel4)
{
	Pixel16     r1, r2, r3, r4;
	Pixel16     g1, g2, g3, g4;
	Pixel16     b1, b2, b3, b4;
	Pixel16     a1, a2, a3, a4;
	Pixel32     r, g, b, a;
	Pixel32     result;

	RGB32Components(pixel1, &r1, &g1, &b1, &a1);
	RGB32Components(pixel2, &r2, &g2, &b2, &a2);
	RGB32Components(pixel3, &r3, &g3, &b3, &a3);
	RGB32Components(pixel4, &r4, &g4, &b4, &a4);

	r = (Pixel32)ceil((r1 + r2 + r3 + r4) / 4.0);
	g = (Pixel32)ceil((g1 + g2 + g3 + g4) / 4.0);
	b = (Pixel32)ceil((b1 + b2 + b3 + b4) / 4.0);
	a = (Pixel32)ceil((a1 + a2 + a3 + a4) / 4.0);

	result =  ( r | (g << 8) | (b << 16) | (a << 24));

	return result;
}

void spriteutils_CreateQuarterSize(Pixel32 *srcBuf, sint32 srcWidth, sint32 srcHeight, Pixel32 **destBuf, BOOL aa)
{
	sint32      destWidth = srcWidth / 2;
	sint32      destHeight = srcHeight / 2;
	sint32      i,j;
	Pixel32     pixel, pixel1, pixel2, pixel3, pixel4;
	Pixel32     *outBuf;

	outBuf = (Pixel32 *)malloc(destWidth * destHeight * sizeof(Pixel32) );

	for (i=0; i<destHeight; i++) {
		for (j=0; j<destWidth; j++) {
			pixel1 = srcBuf[(i * 2) * srcWidth + (j * 2)];

			if (aa) {
				pixel2 = srcBuf[(i * 2) * srcWidth + (j * 2) + 1];
				pixel3 = srcBuf[((i * 2) + 1) * srcWidth + (j * 2)];
				pixel4 = srcBuf[((i * 2) + 1) * srcWidth + (j * 2) + 1];

				pixel = spriteutils_AveragePixel32(pixel1, pixel2, pixel3, pixel4);
			} else {
				pixel = pixel1;
			}

			outBuf[i*destWidth + j] = pixel;
		}
	}

	*destBuf = outBuf;
}


void spriteutils_ConvertPixelFormat(Pixel16 *frame, sint32 width, sint32 height, const MBCHAR * filename)
{
	Pixel16     *table = frame+1;
	Pixel16     *dataStart = table + height;

	for(sint32 j=0; j<height; j++) {
		if (table[j] != k_EMPTY_TABLE_ENTRY) {
			Pixel16     *rowData;
			Pixel16     tag;

			rowData = dataStart + table[j];

			tag = *rowData++;

			tag = tag & 0x0FFF;

			while ((tag & 0xF000) == 0) {
				switch ((tag & 0x0F00) >> 8) {
					case k_CHROMAKEY_RUN_ID :
						break;
					case k_COPY_RUN_ID      : {
							short len = (tag & 0x00FF);
							for (short i=0; i<len; i++) {
#ifdef CLEAN_INSTEAD_OF_CONVERT
								if (*rowData == 0x0000)
									*rowData = 0x0001;
#else
								*rowData = pixelutils_Convert565to555(*rowData);
								if (!*rowData)
									*rowData = 1;
#endif
								rowData++;
							}
						}
						break;
					case k_SHADOW_RUN_ID    :

						break;
					case k_FEATHERED_RUN_ID :
#ifdef CLEAN_INSTEAD_OF_CONVERT
							if (*rowData == 0x0000)
								*rowData = 0x0001;
#else
							*rowData = pixelutils_Convert565to555(*rowData);
							if (!*rowData)
								*rowData = 1;
#endif
							rowData++;
						break;
					default:
						// A tag byte outside the known run-IDs means the
						// pixel payload itself is corrupt (not a container/
						// size problem) - log which sprite file so other
						// bad assets can be identified the same way GU059.SPR
						// (UNIT_SEA_ENGINEER) was.
						DPRINTF(k_DBG_FIX,
							("spriteutils_ConvertPixelFormat: unrecognized run tag 0x%x at row %d - file %s, %dx%d\n",
							 tag, j, filename ? filename : "?", width, height));
						Assert(FALSE);
						return; // With this return it does not crash, to land here something must have gone wrong before
				}
				tag = *rowData++;
			}
		}
	}
}




Pixel16 * spriteutils_ScaleFrame(Pixel16 const *frame, sint32 scale, size_t *size)
{
	if (!frame || scale <= 1) return NULL;

	sint32 const    height    = frame[0];
	Pixel16 const * table     = frame + 1;
	Pixel16 const * dataStart = table + height;

	// The rows are encoded once; the table points scale times to each. The
	// draw functions take runs up to the one marked as end of line, which
	// they do not draw (the first one is always drawn); here every row ends
	// with an empty run marked so.
	std::vector<Pixel16> offsets;
	std::vector<Pixel16> runs;
	for (sint32 j = 0; j < height; ++j)
	{
		if (table[j] == k_EMPTY_TABLE_ENTRY)
		{
			offsets.insert(offsets.end(), scale, (Pixel16) k_EMPTY_TABLE_ENTRY);
			continue;
		}
		if (runs.size() >= k_EMPTY_TABLE_ENTRY) return NULL;
		offsets.insert(offsets.end(), scale, (Pixel16) runs.size());

		Pixel16 const * p   = dataStart + table[j];
		Pixel16         tag = *p++ & 0x0FFF;
		while ((tag & 0xF000) == 0)
		{
			sint32 const kind = (tag & 0x0F00) >> 8;
			if (kind == k_FEATHERED_RUN_ID)
			{
				// one pixel with its alpha in the tag
				Pixel16 const pixel = *p++;
				for (sint32 i = 0; i < scale; ++i)
				{
					runs.push_back(tag);
					runs.push_back(pixel);
				}
			}
			else
			{
				sint32 const count = tag & 0x00FF;
				sint32       left  = count * scale;
				sint32       done  = 0;
				while (left > 0)
				{
					// runs are at most 255 long
					sint32 const piece = std::min<sint32>(left, 0xFF);
					runs.push_back(static_cast<Pixel16>((kind << 8) | piece));
					if (kind == k_COPY_RUN_ID)
					{
						for (sint32 i = 0; i < piece; ++i)
							runs.push_back(p[(done + i) / scale]);
					}
					done += piece;
					left -= piece;
				}
				if (kind == k_COPY_RUN_ID) p += count;
			}
			tag = *p++;
		}
		runs.push_back(static_cast<Pixel16>((k_EOLN_ID | k_CHROMAKEY_RUN_ID) << 8));
	}
	if (runs.size() > k_EMPTY_TABLE_ENTRY) return NULL;

	size_t const count  = 1 + offsets.size() + runs.size();
	Pixel16 *    scaled = new Pixel16[count];
	scaled[0] = static_cast<Pixel16>(height * scale);
	std::copy(offsets.begin(), offsets.end(), scaled + 1);
	std::copy(runs.begin(), runs.end(), scaled + 1 + offsets.size());
	if (size) *size = count * sizeof(Pixel16);
	return scaled;
}

MBCHAR const * g_spriteExportDir = NULL;

uint64 spriteutils_FrameHash(Pixel16 const *frame, size_t size)
{
	// FNV-1a, 64 bit
	uint8 const * bytes = reinterpret_cast<uint8 const *>(frame);
	uint64        hash  = 14695981039346656037ULL;
	for (size_t i = 0; i < size; ++i)
	{
		hash ^= bytes[i];
		hash *= 1099511628211ULL;
	}
	return hash;
}

bool spriteutils_ExportFrame(Pixel16 const *frame, size_t size, const MBCHAR *dir)
{
	if (!frame || size < 2) return false;

	sint32 const    height    = frame[0];
	Pixel16 const * table     = frame + 1;
	Pixel16 const * dataStart = table + height;
	if (height <= 0 || size < (size_t)(1 + height) * 2) return false;

	// the width: the longest row
	sint32 width = 0;
	for (sint32 pass = 0; pass < 2; ++pass)
	{
		std::vector<uint8> image(pass ? width * height * 4 : 0, 0);
		bool               visible = false;
		for (sint32 j = 0; j < height; ++j)
		{
			if (table[j] == k_EMPTY_TABLE_ENTRY) continue;
			Pixel16 const * p   = dataStart + table[j];
			Pixel16         tag = *p++ & 0x0FFF;
			sint32          x   = 0;
			while ((tag & 0xF000) == 0)
			{
				sint32 const kind = (tag & 0x0F00) >> 8;
				sint32 const len  = (kind == k_FEATHERED_RUN_ID) ? 1 : (tag & 0x00FF);
				for (sint32 i = 0; i < len; ++i, ++x)
				{
					Pixel16 pixel = 0;
					uint8   alpha = 0;
					bool    shadow = false;
					if (kind == k_COPY_RUN_ID)           { pixel = *p++; alpha = 255; }
					else if (kind == k_FEATHERED_RUN_ID) { pixel = *p++; alpha = (uint8)(tag & 0xFF); if (!alpha) alpha = 1; if (alpha == 255) alpha = 254; }
					else if (kind == k_SHADOW_RUN_ID)    { shadow = true; }
					if (!pass || x >= width) continue;
					uint8 * out = &image[((height - 1 - j) * width + x) * 4];
					if (shadow) { out[0] = 255; out[1] = 0; out[2] = 255; out[3] = 0; continue; }
					if (!alpha) continue;
					visible = true;
					sint32 const r = (pixel >> 11) & 0x1F, g = (pixel >> 5) & 0x3F, b = pixel & 0x1F;
					out[0] = (uint8)((b << 3) | (b >> 2));
					out[1] = (uint8)((g << 2) | (g >> 4));
					out[2] = (uint8)((r << 3) | (r >> 2));
					out[3] = alpha;
				}
				tag = *p++;
			}
			if (!pass && x > width) width = x;
		}
		if (!pass)
		{
			if (width <= 0 || width > 0x7FFF) return false;
			continue;
		}
		if (!visible) return false;   // nothing to upscale (shadow frames)

		MBCHAR path[_MAX_PATH];
		snprintf(path, sizeof(path), "%s%s%016llx.tga", dir, FILE_SEP,
		         (unsigned long long) spriteutils_FrameHash(frame, size));
		FILE * file = fopen(path, "wb");
		if (!file) return false;
		uint8 header[18] = { 0 };
		header[2]  = 2;
		header[12] = (uint8)(width & 0xFF);  header[13] = (uint8)(width >> 8);
		header[14] = (uint8)(height & 0xFF); header[15] = (uint8)(height >> 8);
		header[16] = 32;
		header[17] = 8;   // 8 alpha bits, bottom-up
		fwrite(header, 1, sizeof(header), file);
		fwrite(&image[0], 1, image.size(), file);
		fclose(file);
	}
	return true;
}

namespace
{
	// the index of sprites.hd: hash -> place of the HD frame in the file
	struct HDSprites
	{
		sint32                                           scale;
		FILE *                                           file;
		std::map<uint64, std::pair<uint32, uint32> >     index;   // offset, words

		HDSprites() : scale(0), file(NULL) {}
		~HDSprites() { if (file) fclose(file); }

		void Open(sint32 a_Scale)
		{
			scale = a_Scale;
			MBCHAR path[_MAX_PATH];
			snprintf(path, sizeof(path), "%s%sredux_hires%s%dx%ssprites%ssprites.hd",
			         g_civPaths->GetDataPath(), FILE_SEP, FILE_SEP, a_Scale, FILE_SEP, FILE_SEP);
			file = fopen(path, "rb");
			if (!file) return;
			uint8  head[16];
			sint32 fileScale = 0;
			uint32 count     = 0;
			if (fread(head, 1, 16, file) != 16 || memcmp(head, "CTPHDS1", 7) != 0) { fclose(file); file = NULL; return; }
			memcpy(&fileScale, head + 8, 4);
			memcpy(&count, head + 12, 4);
			if (fileScale != a_Scale) { fclose(file); file = NULL; return; }
			for (uint32 i = 0; i < count; ++i)
			{
				uint8 entry[16];
				if (fread(entry, 1, 16, file) != 16) break;
				uint64 hash   = 0;
				uint32 offset = 0, words = 0;
				memcpy(&hash, entry, 8);
				memcpy(&offset, entry + 8, 4);
				memcpy(&words, entry + 12, 4);
				index[hash] = std::make_pair(offset, words);
			}
		}
	};

	HDSprites s_hdSprites;
}

Pixel16 * spriteutils_HDFrame(Pixel16 const *frame, size_t size, sint32 scale, size_t *hdSize)
{
	if (!frame || !g_civPaths) return NULL;
	if (s_hdSprites.scale != scale) s_hdSprites.Open(scale);
	if (!s_hdSprites.file) return NULL;

	std::map<uint64, std::pair<uint32, uint32> >::const_iterator i =
		s_hdSprites.index.find(spriteutils_FrameHash(frame, size));
	if (i == s_hdSprites.index.end()) return NULL;

	Pixel16 * hd = new Pixel16[i->second.second];
	if (fseek(s_hdSprites.file, (long) i->second.first, SEEK_SET) != 0 ||
	    fread(hd, 2, i->second.second, s_hdSprites.file) != i->second.second)
	{
		delete [] hd;
		return NULL;
	}
	if (hdSize) *hdSize = i->second.second * 2;
	return hd;
}

void spriteutils_ConvertPixelFormatForFile(Pixel16 *frame, sint32 width, sint32 height)
{
	if (g_is565Format) return;

	Pixel16     *table = frame+1;
	Pixel16     *dataStart = table + height;

	for(sint32 j=0; j<height; j++) {
		if (table[j] != k_EMPTY_TABLE_ENTRY) {
			Pixel16     *rowData;
			Pixel16     tag;

			rowData = dataStart + table[j];

			tag = *rowData++;

			tag = tag & 0x0FFF;

			while ((tag & 0xF000) == 0) {
				switch ((tag & 0x0F00) >> 8) {
					case k_CHROMAKEY_RUN_ID :
						break;
					case k_COPY_RUN_ID      : {
							short len = (tag & 0x00FF);
							for (short i=0; i<len; i++) {
#ifdef CLEAN_INSTEAD_OF_CONVERT
								if (*rowData == 0x0000)
									*rowData = 0x0001;
#else
								*rowData = pixelutils_Convert565to555(*rowData);
								if (!*rowData)
									*rowData = 1;
#endif
								rowData++;
							}
						}
						break;
					case k_SHADOW_RUN_ID    :

						break;
					case k_FEATHERED_RUN_ID :
#ifdef CLEAN_INSTEAD_OF_CONVERT
							if (*rowData == 0x0000)
								*rowData = 0x0001;
#else
							*rowData = pixelutils_Convert555to565(*rowData);
							if (!*rowData)
								*rowData = 1;
#endif
							rowData++;
						break;
					default:
						Assert(FALSE);
				}
				tag = *rowData++;
			}
		}
	}
}

sint32 spriteutils_DeltaToFacing(sint32 x, sint32 y)
{
	if (x < 0) {
		if (y < 0) return 7;
		else if (y > 0) return 5;
		else return 6;
	} else {
		if (x > 0) {
			if (y < 0) return 1;
			else if (y > 0) return 3;
			else return 2;
		} else {

			if (y < 0) return 0;
			else if (y > 0) return 4;
			else return 4;
		}
	}
}
