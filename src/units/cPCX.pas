unit cPCX;

{ 20261114 class version }

{$MODE OBJFPC}

interface

uses os2def, pmwin, pmgpi, pmbitmap, mmbase, dive, divext, ccanvas, cBitmapPainter;

type
  USHORT = word;
type
  LONG = longint;
  PULONG = ^ULONG;
  // ERRORSTATUS = USHORT; // word;
  
  
{ i PCX_hpp_hdr.pas}

type
  PcxPainter = class(BitmapPainter)
  
  private
  
    usBytesPerLine: USHORT;

    // private, internal functions
{
    VOID UnpackBuffer
      (
      VOID
      );

    VOID ReadPcxLine8
      (
      PBYTE             pbyLine,
      USHORT            usCanvasWidth
      );}
      
    procedure UnpackBuffer;
    procedure ReadPcxLine8(pbyLine: PBYTE; usCanvasWidth: USHORT);  
    procedure ReadPcxLine1(pbyLine: PBYTE; usCanvasWidth: USHORT);
    function  PackPcxFile: ERRORSTATUS;
    function  WritePcxLine8(pbyLine: PBYTE; usLineWidth: USHORT): ERRORSTATUS;

  public

    // Constructors
    constructor PcxCreate;
    constructor PcxCreate (pbyPcxIn: PBYTE; ulBufferSizeIn: ULONG); overload; //???
    constructor PcxCreate (pbyPcxIn: PBYTE; ulBufferSizeIn: ULONG; pcnvCanvasIn: pCanvas); overload; //???
    // Destructor
    destructor Destroy; override;

    // Member functions

    // functions required by BitmapPainter
    function AssociateBuffer
      (           pbyBufferIn: PBYTE;
                  ulBufferSizeIn: ULONG
      ): ERRORSTATUS; reintroduce; // override;

    function PaintCanvas: ERRORSTATUS; reintroduce; // override;

    function EncodeCanvas
      (          pbyPalette: PBYTE;
                 // ppbyBufferOut: PBYTE * ;
                 ppbyBufferOut: PBYTE; // array of ?
                 pulBufferSizeOut: PULONG
      ): ERRORSTATUS; reintroduce; // override;

    function QueryBitmapStats(pbmsStatsOut: PBITMAPSTATS): ERRORSTATUS; reintroduce; // override;
  
{
function PcxPainter_AssociateBuffer
  (              pbyBufferIn:PBYTE;
                 ulBufferSizeIn: ULONG
  ): ERRORSTATUS;
function PcxPainter_PaintCanvas: ERRORSTATUS;

function PcxPainter_EncodeCanvas
  (              pbyPalette: PBYTE;
                 ppbyBufferOut: PBYTE; // * ???
                 pulBufferSizeOut: PULONG
  ): ERRORSTATUS;
}

end; {class type def}


implementation

const ERR_GEN                   = 1200;
const ERR_GEN_ALLOC_FAILURE     = (1 + ERR_GEN);
const ERR_GEN_BAD_PARAM         = (2 + ERR_GEN);
const ERR_GEN_MISSING_PARAMS    = (3 + ERR_GEN);

//#ifndef ERR_CNV
const ERR_CNV                   = 1220;
//#endif
const ERR_CNV_CREATE            = (1 + ERR_CNV);
const ERR_CNV_BAD_CANVAS        = (2 + ERR_CNV);

//#ifndef ERR_PAL
const ERR_PAL                   = 1225;
//#endif
const ERR_PAL_DATA_CORRUPTED    = (1 + ERR_PAL);

//#ifndef ERR_PCX
const ERR_PCX                   = 1235;
// #endif
const ERR_PCX_BAD_FORMAT        = (2 + ERR_PCX);
const ERR_PCX_NOT_PCX           = (3 + ERR_PCX);
const ERR_PCX_EMPTY_BUFFER      = (4 + ERR_PCX);

{$i memcpy.pas}
{ -----------------------------------------------------------------
                                 PCX.CPP

     This code sits on top of the Bitmap class structure, and
  provides services for encoding and decoding PCX files.

     Sample code for the article "Gearing Up For Games" in EDM/2.

                 Article and code by Michael T. Duffy

   ----------------------------------------------------------------- }

// ***********************************************************************
//  Header Files
// ***********************************************************************

{
#include "newtypes.hpp"
#include "canvas.hpp"
#include "pcx.hpp"
#include "errcodes.hpp"
}

type PCXHEADER = record
             byManufacturer: BYTE;
             byVersion : BYTE;
             byEncoding: BYTE;
             byBitsPerPixel: BYTE;
             usXmin: USHORT;
             usYmin: USHORT;
             usXmax: USHORT;
             usYmax: USHORT;
             usHres: USHORT;
             usVres: USHORT;
             abyPalette: array [0..48-1] of BYTE;
             byReserved: BYTE;
             byColorPlanes: BYTE;
             usBytesPerLine: USHORT;
             usPaletteType: USHORT;
             abyFiller: array [0..58-1] of BYTE;
  end; // PCXHEADER;
               
type
  PPCXHEADER  = ^PCXHEADER;

const
  ulPcxType:ULONG = $20584350;  // FOURCC code for "PCX "

// ***********************************************************************
//  Code
// ***********************************************************************

//........................................................................
constructor PcxPainter.PcxCreate; // PcxPainter;
//........................................................................
begin
  SetType (ulPcxType);
end;

//........................................................................
destructor PcxPainter.Destroy; // ~PcxPainter
//........................................................................
begin
  DissociateBuffer;
  DissociateCanvas;
end;

//........................................................................
constructor PcxPainter.PcxCreate // PcxPainter
  ( pbyPcxIn: PBYTE;
    ulBufferSizeIn: ULONG
  ); overload;
//........................................................................
begin
  SetType (ulPcxType);
  AssociateBuffer (pbyPcxIn, ulBufferSizeIn);
end;

//........................................................................
constructor PcxPainter.PcxCreate // PcxPainter
  (     pbyPcxIn: PBYTE;
        ulBufferSizeIn: ULONG;
        pcnvCanvasIn: PCANVAS
  ); overload;
//........................................................................
begin
  AssociateBuffer (pbyPcxIn, ulBufferSizeIn);
  AssociateCanvas (pcnvCanvasIn);
end;

//........................................................................
function PcxPainter.AssociateBuffer
  (              pbyBufferIn:PBYTE;
                 ulBufferSizeIn: ULONG
  ): ERRORSTATUS;
//........................................................................
// Note:  This function replaces the AssociateBuffer routine in the
//   BitmapPainter object.  It does this in order to add the ability to
//   determine whether or not the buffer contains valid information before
//   it accepts it.
var
  ppcxhdr: PPCXHEADER;
begin 
  // Make sure the buffer is of a valid size
  if (ulBufferSizeIn <= sizeof (PCXHEADER)) then
  begin
  usLastErrorCode := ERR_PCX_EMPTY_BUFFER;
  AssociateBuffer := ES_ERROR;
  exit;
  end;
  
  // Test the header of the buffer, to check if the encoded image is in a
  //  format that the decoder understands.
  ppcxhdr := PPCXHEADER(pbyBufferIn);

  if (ppcxhdr^.byManufacturer = $0a) then
  begin
  // make sure the picture is the right version and color depth
  //  (i.e. 256 color PCX file)
  if ((ppcxhdr^.byVersion <= 5) and
      ((ppcxhdr^.byBitsPerPixel = 8) or (ppcxhdr^.byBitsPerPixel = 1))) then
    begin
    // The header info is valid.
    // Extract needed info from the header
    usBytesPerLine  := ppcxhdr^.usBytesPerLine;

    // Accept the buffer and store it in needed internal variables.
    pbySourceBuffer := pbyBufferIn;
    ulBufferSize    := ulBufferSizeIn;
    ulBufferOffset  := sizeof (PCXHEADER);
    AssociateBuffer := ES_NO_ERROR;
    exit;
    end
  else
    begin
    usLastErrorCode := ERR_PCX_BAD_FORMAT;
    AssociateBuffer := ES_ERROR;
    exit;
    end;
  end
else
  begin
  usLastErrorCode := ERR_PCX_NOT_PCX;
  AssociateBuffer := ES_ERROR;
  exit;
  end; {if} 
end;

//........................................................................
function PcxPainter.PaintCanvas: ERRORSTATUS;
//........................................................................
begin
  // Make sure that the Canvas exists, and that the buffer pointer is valid
  if ((pbySourceBuffer = nil) {||} or (pcnvDestCanvas = nil)) then
  begin
  usLastErrorCode := ERR_GEN_MISSING_PARAMS;
  PaintCanvas := ES_ERROR;
  exit;
  end;
  
  if (pcnvDestCanvas^.Validate = FALSE) then
  begin
  usLastErrorCode := ERR_CNV_BAD_CANVAS;
  PaintCanvas := ES_ERROR;
  end;
  
  // Clear the canvas so you also erase the areas of the canvas that the
  //   PCX does not overwrite.
  pcnvDestCanvas^.Clear (0);
  
  // Decode the buffer to the canvas.
  UnpackBuffer;
  
  // If the bits per pixel equals 8, then a 256 color palette should be
  //   tacked onto the end of the PCX data
  if ({(PPCXHEADER)} PPCXHEADER(pbySourceBuffer)^.byBitsPerPixel = 8) then
  begin
  // Make sure the palette is where it should be.
  if (pbySourceBuffer [ulBufferSize - 769] = $0c) then
    begin
    // Copy the palette to the internal palette array
    
    fillchar (abyPalette, sizeof (abyPalette), 0);
    memcpy (abyPalette,
            pbySourceBuffer + ulBufferSize - 768,
            768);
    end; {if}
  end; {if}
  
  PaintCanvas := ES_NO_ERROR;
end;

//........................................................................
procedure PcxPainter.UnpackBuffer;
//........................................................................
var
  lRow: LONG;
  usImageHeight: USHORT;
  pbyLineAddr: PBYTE;
  ppcxhdr: PPCXHEADER;
  usCanvasWidth: USHORT;
  lCanvasRowIncrement: LONG;

begin
  // Set a pointer to the PCX header.
  ppcxhdr := PPCXHEADER(pbySourceBuffer);
  
  // Find the height of the PCX
  usImageHeight := {(USHORT)} (ppcxhdr^.usYmax - ppcxhdr^.usYmin + 1);
  
  // Restrict the height of the PCX to the height of the canvas
  usImageHeight := min (usImageHeight, pcnvDestCanvas^.QueryHeight);

  // Move some Canvas variables local for speed and convenience.
  usCanvasWidth       := pcnvDestCanvas^.QueryWidth;
  pbyLineAddr         := pcnvDestCanvas^.QueryRowAddress (0);
  lCanvasRowIncrement := pcnvDestCanvas^.QueryRowIncrement;
  
  // Set the buffer index to the start of the data, just past the header.
  ulBufferOffset      := sizeof (PCXHEADER);
  
  // Step through each row of the canvas....
  for lRow := 0 to usImageHeight-1 do
  begin
  // And decode one line depending on it's format
  if (ppcxhdr^.byBitsPerPixel = 8) then
    begin
    ReadPcxLine8 (pbyLineAddr, usCanvasWidth);
    end
  else if (ppcxhdr^.byBitsPerPixel = 1) then
    begin
    ReadPcxLine1 (pbyLineAddr, usCanvasWidth);
    end; {if}

  // Move to the next row of the canvas.
  pbyLineAddr := pbyLineAddr + lCanvasRowIncrement;
  end; {for}
end;

//........................................................................
procedure PcxPainter.ReadPcxLine8
  (          pbyLine: PBYTE;
             usCanvasWidth: USHORT
  );
//........................................................................
// Decode a line of an 8-bit (256 color) PCX file
var
  lDestIndex   : LONG;
  byCodeIn     : BYTE;
  byRunCounter : BYTE;
  
begin

  // Prepare to write to the beginning of the target row.
  lDestIndex := 0;
  
  // loop while there are bytes left to write.
  // Decode both bytes that are written and bytes that are off the right edge
  //   of the canvas so that the offset into the encoded buffer is moved
  //   through the entire current line, and thus to the beginning of the next.
  
  while (lDestIndex < usBytesPerLine) do
  begin
  // get a key byte
  byCodeIn := pbySourceBuffer [ulBufferOffset];
  ulBufferOffset := ulBufferOffset+1; // post-inc ???

  // if it's a run of bytes field
  if ((byCodeIn and $c0) = $c0) then
    begin
    // and off the high bits
    byRunCounter := {(BYTE)} (byCodeIn and $3f);

    // get the run byte
    // byCodeIn := pbySourceBuffer [ulBufferOffset++];
    byCodeIn := pbySourceBuffer [ulBufferOffset];
    ulBufferOffset := ulBufferOffset+1; // post-inc

    // run the byte
    // while (byRunCounter--) do
    while (byRunCounter>0) do
      begin
      byRunCounter := byRunCounter-1; // post-dec
      // Make sure the byte is in bounds of the canvas
      if (lDestIndex < usCanvasWidth) then
        begin
        // Write each byte
        // pbyLine[lDestIndex++] := byCodeIn;
        pbyLine[lDestIndex] := byCodeIn;
        lDestIndex := lDestIndex+1; // post-inc
        end;
      end;
    end
  else
    begin
    // It is a single byte to be written.

    // Make sure the byte is in bounds of the canvas
    if (lDestIndex < usCanvasWidth) then
      begin
      // Write the byte
      // pbyLine[lDestIndex++] := byCodeIn;
      pbyLine[lDestIndex] := byCodeIn;
      lDestIndex := lDestIndex+1; // post-inc
      end; {if}
    end;
  end; // while (lDestIndex < usBytesPerLine);
end;

//........................................................................
procedure PcxPainter.ReadPcxLine1
  (                pbyLine: PBYTE;
                   usCanvasWidth: USHORT
  );
//........................................................................
// Decode a line of a 1-bit (monochrome) PCX file
//
// Warning!  Because black and white PCX files are stored with their width
//  as an increment of 8 (since there are 8 pixels per byte), this routine
//  can only write to canvases that have a width that is either a multiple
//  of 8, or is wider than the PCX width.  The code could be altered to
//  avoid this limitation, but it would require a bounds check for _every_
//  pixel, and the slowdown in unacceptable.
var
  lDestIndex: LONG;
  byCodeIn: BYTE;
  byRunCounter: BYTE;
  ulBytesProcessed: ULONG = 0;

begin
  // Prepare to write to the beginning of the target row.
  lDestIndex := 0;
  
  // loop while there are bytes left to write.
  // Decode both bytes that are written and bytes that are off the right edge
  //   of the canvas so that the offset into the encoded buffer is moved
  //   through the entire current line, and thus to the beginning of the next.

  while (ulBytesProcessed < usBytesPerLine) do
  begin
  // get a key byte
  // byCodeIn := pbySourceBuffer [ulBufferOffset++];
  byCodeIn := pbySourceBuffer [ulBufferOffset];
  ulBufferOffset := ulBufferOffset+1; // post-inc?
  
  // if it's a run of bytes field
  if ((byCodeIn and $c0) = $c0) then
    begin
    // and off the high bits
    byRunCounter := {(BYTE)} (byCodeIn and $3f);

    // get the run byte
    // byCodeIn := pbySourceBuffer [ulBufferOffset++];
    byCodeIn := pbySourceBuffer [ulBufferOffset];
    ulBufferOffset := ulBufferOffset+1; // post-inc???

    // run the byte
    // while (byRunCounter--)
    while (byRunCounter>0) do
      begin
      byRunCounter := byRunCounter-1; // post-dec
      // Make sure the bytes are in bounds of the canvas
      if (lDestIndex < usCanvasWidth) then
        begin
        // Extract and write each pixel in the byte
        // pbyLine [lDestIndex] := (byCodeIn and $80) ? byWhite : byBlack;
        pbyLine [lDestIndex] := byBlack;
        if (byCodeIn and $80)>0 then pbyLine [lDestIndex] := byWhite;
        lDestIndex := lDestIndex+1;
        // pbyLine [lDestIndex] := (byCodeIn and $40) ? byWhite : byBlack;
        pbyLine [lDestIndex] := byBlack;
        if (byCodeIn and $40)>0 then pbyLine [lDestIndex] := byWhite;
        lDestIndex := lDestIndex+1;
        // pbyLine [lDestIndex] := (byCodeIn and $20) ? byWhite : byBlack;
        pbyLine [lDestIndex] := byBlack;
        if (byCodeIn and $20)>0 then pbyLine [lDestIndex] := byWhite;
        lDestIndex := lDestIndex+1;
        // pbyLine [lDestIndex] := (byCodeIn and $10) ? byWhite : byBlack;
        pbyLine [lDestIndex] := byBlack;
        if (byCodeIn and $10)>0 then pbyLine [lDestIndex] := byWhite;
        lDestIndex := lDestIndex+1;
        // pbyLine [lDestIndex] := (byCodeIn and $08) ? byWhite : byBlack;
        pbyLine [lDestIndex] := byBlack;
        if (byCodeIn and $08)>0 then pbyLine [lDestIndex] := byWhite;
        lDestIndex := lDestIndex+1;
        // pbyLine [lDestIndex] := (byCodeIn and $04) ? byWhite : byBlack;
        pbyLine [lDestIndex] := byBlack;
        if (byCodeIn and $04)>0 then pbyLine [lDestIndex] := byWhite;
        lDestIndex := lDestIndex+1;
        // pbyLine [lDestIndex] := (byCodeIn and $02) ? byWhite : byBlack;
        pbyLine [lDestIndex] := byBlack;
        if (byCodeIn and $02)>0 then pbyLine [lDestIndex] := byWhite;
        lDestIndex := lDestIndex+1;
        // pbyLine [lDestIndex] := (byCodeIn and $01) ? byWhite : byBlack;
        pbyLine [lDestIndex] := byBlack;
        if (byCodeIn and $01)>0 then pbyLine [lDestIndex] := byWhite;
        lDestIndex := lDestIndex+1;
        end;
      // ++ulBytesProcessed;
      ulBytesProcessed := ulBytesProcessed+1; // ???
      end;
    end
  else
    begin
    // Make sure the bytes are in bounds of the canvas
    if (lDestIndex < usCanvasWidth) then
      begin
      // Extract and write each pixel in the byte
        pbyLine [lDestIndex] := byBlack;
        if (byCodeIn and $80)>0 then pbyLine [lDestIndex] := byWhite;
        lDestIndex := lDestIndex+1;
        // pbyLine [lDestIndex] := (byCodeIn and $40) ? byWhite : byBlack;
        pbyLine [lDestIndex] := byBlack;
        if (byCodeIn and $40)>0 then pbyLine [lDestIndex] := byWhite;
        lDestIndex := lDestIndex+1;
        // pbyLine [lDestIndex] := (byCodeIn and $20) ? byWhite : byBlack;
        pbyLine [lDestIndex] := byBlack;
        if (byCodeIn and $20)>0 then pbyLine [lDestIndex] := byWhite;
        lDestIndex := lDestIndex+1;
        // pbyLine [lDestIndex] := (byCodeIn and $10) ? byWhite : byBlack;
        pbyLine [lDestIndex] := byBlack;
        if (byCodeIn and $10)>0 then pbyLine [lDestIndex] := byWhite;
        lDestIndex := lDestIndex+1;
        // pbyLine [lDestIndex] := (byCodeIn and $08) ? byWhite : byBlack;
        pbyLine [lDestIndex] := byBlack;
        if (byCodeIn and $08)>0 then pbyLine [lDestIndex] := byWhite;
        lDestIndex := lDestIndex+1;
        // pbyLine [lDestIndex] := (byCodeIn and $04) ? byWhite : byBlack;
        pbyLine [lDestIndex] := byBlack;
        if (byCodeIn and $04)>0 then pbyLine [lDestIndex] := byWhite;
        lDestIndex := lDestIndex+1;
        // pbyLine [lDestIndex] := (byCodeIn and $02) ? byWhite : byBlack;
        pbyLine [lDestIndex] := byBlack;
        if (byCodeIn and $02)>0 then pbyLine [lDestIndex] := byWhite;
        lDestIndex := lDestIndex+1;
        // pbyLine [lDestIndex] := (byCodeIn and $01) ? byWhite : byBlack;
        pbyLine [lDestIndex] := byBlack;
        if (byCodeIn and $01)>0 then pbyLine [lDestIndex] := byWhite;
        lDestIndex := lDestIndex+1;
        end;
      // ++ulBytesProcessed;
      ulBytesProcessed := ulBytesProcessed+1; // ???
    end;
  end; // while (ulBytesProcessed < usBytesPerLine);
end;

//........................................................................
function PcxPainter.QueryBitmapStats
  (       pbmsStatsOut: PBITMAPSTATS
  ): ERRORSTATUS;
//........................................................................
var
  ppcxhdr: PPCXHEADER;
begin

  if (pbySourceBuffer = nil) then
  begin
  usLastErrorCode := ERR_GEN_MISSING_PARAMS;
  QueryBitmapStats := ES_ERROR;
  exit;
  end;
  
  // Set a pointer to the bitmap header.
  ppcxhdr := PPCXHEADER(pbySourceBuffer);
  
  // Fill the provided structure with the requested information.
  pbmsStatsOut^.sWidth     := (ppcxhdr^.usXmax - ppcxhdr^.usXmin + 1);
  pbmsStatsOut^.sHeight    := (ppcxhdr^.usYmax - ppcxhdr^.usYmin + 1);
  pbmsStatsOut^.byBitDepth := ppcxhdr^.byBitsPerPixel;
  QueryBitmapStats := ES_NO_ERROR;
end;

//........................................................................
function PcxPainter.EncodeCanvas
  (              pbyPalette: PBYTE;
                 ppbyBufferOut: PBYTE; // * ???
                 pulBufferSizeOut: PULONG
  ): ERRORSTATUS;
//........................................................................
// Returns a buffer with the canvas encoded as a PCX file.
var
  ppcxhdr: PPCXHEADER;

begin
  // Make sure valid variables were passed to the routine
  if ((pcnvDestCanvas   = nil) or 
      (ppbyBufferOut    = nil) or 
      (pulBufferSizeOut = nil)) then
  begin
  usLastErrorCode := ERR_GEN_MISSING_PARAMS;
  EncodeCanvas := ES_ERROR;
  exit;
  end;
  
  // Make sure canvas is ok
  if (pcnvDestCanvas^.Validate  = FALSE) then
  begin
  usLastErrorCode := ERR_CNV_BAD_CANVAS;
  EncodeCanvas := ES_ERROR;
  exit;
  end;
  
  // Setup an encode buffer
  if ({BitmapPainter.}InitializeEncodeBuffer  = ES_ERROR) then
  begin
  // Error code set in InitializeEncodeBuffer
  EncodeCanvas := ES_ERROR;
  exit;
  end;
  
  // Set a pointer to the beginning of the buffer where the header is located
  // ppcxhdr = (PPCXHEADER) &pbyEncodeBuffer [ulEncBufferOffset];
  ppcxhdr := PPCXHEADER(pbyEncodeBuffer [ulEncBufferOffset]);
  
  // Assure the memory before you write to it
  if ({BitmapPainter.}AssureEncodeMemory (sizeof (PCXHEADER)) = ES_ERROR) then
  begin
  // Error code set in AssureEncodeMemory
  EncodeCanvas := ES_ERROR;
  exit;
  end;
  
  // Create the header for the PCX buffer.  Save as 256 color PCX
  // memset (ppcxhdr, 0, sizeof (PCXHEADER));
  fillchar (ppcxhdr, sizeof (PCXHEADER), 0); // ptr or object?
  ppcxhdr^.byManufacturer   := $0a;
  ppcxhdr^.byVersion        := $05;
  ppcxhdr^.byEncoding       := $01;
  ppcxhdr^.byBitsPerPixel   := $08;
  ppcxhdr^.usXmin           := 0;
  ppcxhdr^.usYmin           := 0;
  ppcxhdr^.usXmax           := (pcnvDestCanvas^.QueryWidth - 1);
  ppcxhdr^.usYmax           := (pcnvDestCanvas^.QueryHeight - 1);
  ppcxhdr^.usHres           := 0;
  ppcxhdr^.usVres           := 0;
  ppcxhdr^.byColorPlanes    := 1;
  ppcxhdr^.usBytesPerLine   := pcnvDestCanvas^.QueryWidth;
  ppcxhdr^.usPaletteType    := 2;
  ulEncBufferOffset := ulEncBufferOffset + sizeof (PCXHEADER);
  
  // Encode and write the canvas into the buffer
  if (PackPcxFile  = ES_ERROR) then
  begin
  // Error code set in PackPcxFile
  EncodeCanvas := ES_ERROR;
  exit;
  end;
  
  // Assure the memory before you write to it
  if (AssureEncodeMemory (768 + 1) = ES_ERROR) then
  begin
  // Error code set in AssureEncodeMemory
  EncodeCanvas := ES_ERROR;
  exit;
  end;
  
  // Write out the palette marker.
  pbyEncodeBuffer [ulEncBufferOffset] := $0c;
  // ++ulEncBufferOffset;
  ulEncBufferOffset := ulEncBufferOffset+1;

  // Write out the palette.
  memcpy ( @pbyEncodeBuffer [ulEncBufferOffset], pbyPalette, 768);
  ulEncBufferOffset := ulEncBufferOffset + 768;
  
  // Reduce memory useage to minimum possible
  if (TrimEncodeBuffer = ES_ERROR) then
  begin
  // Error code set in TrimEncodeBuffer
  EncodeCanvas := ES_ERROR;
  exit;
  end;
  
  // Fill out the return values
  {*} ppbyBufferOut^    := pbyEncodeBuffer^; // ??? PCX.pas(570,28) Error: Incompatible types: got "Pointer" expected "Byte"
  {*} pulBufferSizeOut^ := ulEncBufferSize; // ???
  
  EncodeCanvas := ES_NO_ERROR;
end;

//........................................................................
function PcxPainter.PackPcxFile: ERRORSTATUS;
//........................................................................
var
  usRowIndex: USHORT;
  usEncBytesPerLine: USHORT;
  usImageHeight: USHORT;
  pbyLineAddr: PBYTE;
  lRowIncrement:LONG ;

begin

  // Load the local variables with the width and height of the PCX
  usImageHeight     := pcnvDestCanvas^.QueryHeight;
  usEncBytesPerLine := pcnvDestCanvas^.QueryWidth;
  
  lRowIncrement := pcnvDestCanvas^.QueryRowIncrement;
  pbyLineAddr := pcnvDestCanvas^.QueryRowAddress (0);
  
  // for (usRowIndex := 0; usRowIndex < usImageHeight; ++usRowIndex) do
  for usRowIndex := 0 to usImageHeight-1 do
  begin
  if (WritePcxLine8 (pbyLineAddr, usEncBytesPerLine) = ES_ERROR) then
    begin
    // Error code set in WritePcxLine8
    PackPcxFile := ES_ERROR;
    exit;
    end;
  pbyLineAddr := pbyLineAddr + lRowIncrement;
  end;
  PackPcxFile := ES_NO_ERROR;
end;

//........................................................................
function PcxPainter.WritePcxLine8
  (                pbyLine: PBYTE;
                   usLineWidth: USHORT
  ): ERRORSTATUS;
//........................................................................
var
  lSourceIndex: LONG;
  byRunCounter: BYTE;
  
begin

  // Prepare to read from the beginning of the row.
  lSourceIndex := 0;
  
  // Step through the row while there are pixels left.
  while (lSourceIndex < usLineWidth) do
  begin
  // Count the number of similar pixels in a row.

  byRunCounter := 0;
  while (((lSourceIndex + byRunCounter) < usLineWidth) and 
         (byRunCounter < 63) and
         (pbyLine [lSourceIndex + byRunCounter] =
          pbyLine [lSourceIndex + byRunCounter + 1])) do
    begin
    // ++byRunCounter;
    byRunCounter := byRunCounter+1;
    end;

  if (byRunCounter > 0) then
    begin
    // You have a run of the same byte.

    // Assure the memory before you write to it
    if (AssureEncodeMemory (2) = ES_ERROR) then
      begin
      // Error code set in AssureEncodeMemory
      WritePcxLine8 := ES_ERROR;
      exit;
      end;

    // Write the run counter/marker
    pbyEncodeBuffer [ulEncBufferOffset] := {(BYTE)} (byRunCounter {|} or $c0);
    // ++ulEncBufferOffset;
    ulEncBufferOffset := ulEncBufferOffset+1;

    // Write the byte to duplicate
    pbyEncodeBuffer [ulEncBufferOffset] := pbyLine [lSourceIndex];
    // ++ulEncBufferOffset;
    ulEncBufferOffset := ulEncBufferOffset+1;

    lSourceIndex := lSourceIndex + byRunCounter;
    end
  else
    begin
    // You have a single pixel to write

    if ((pbyLine [lSourceIndex] and $c0) = $c0) then
      begin
      // data exists in the top two bits, so we must write this byte as a
      //   run length of 1

      // Assure the memory before you write to it
      if (AssureEncodeMemory (2) = ES_ERROR) then
        begin
        // Error code set in AssureEncodeMemory
        WritePcxLine8 := ES_ERROR;
        exit;
        end;

      // Write the run counter/marker
      pbyEncodeBuffer [ulEncBufferOffset] := $c1;
      // ++ulEncBufferOffset;
      ulEncBufferOffset := ulEncBufferOffset+1;

      // Write the byte to duplicate
      pbyEncodeBuffer [ulEncBufferOffset] := pbyLine [lSourceIndex];
      // ++ulEncBufferOffset;
      ulEncBufferOffset := ulEncBufferOffset+1;

      // ++lSourceIndex;
      lSourceIndex := lSourceIndex+1;
      end
    else
      begin
      // Assure the memory before you write to it
      if (AssureEncodeMemory (1) = ES_ERROR) then
        begin
        // Error code set in AssureEncodeMemory
        WritePcxLine8 := ES_ERROR;
        exit;
        end;

      // Write the byte
      pbyEncodeBuffer [ulEncBufferOffset] := pbyLine [lSourceIndex];
      // ++ulEncBufferOffset;
      ulEncBufferOffset := ulEncBufferOffset+1;

      // ++lSourceIndex;
      lSourceIndex := lSourceIndex+1;
      end;
    end;
  end; // while (lSourceIndex < usLineWidth);

  WritePcxLine8 := ES_NO_ERROR;
end;



end.



