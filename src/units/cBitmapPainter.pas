unit cBitmapPainter;

{ 20261108 created }
{ 20261114 class version }

interface

{$MODE OBJFPC}

uses os2def, pmwin, pmgpi, pmbitmap, mmbase, dive, divext, ccanvas;

// ***********************************************************************
// BITMAP.HPP
// ***********************************************************************
//
// Written by Michael T. Duffy
//
// Base object for bitmap codecs
//
// ***********************************************************************

// ***********************************************************************
//  Encoding constants
// ***********************************************************************

const BMP_WORK_BUFFER_SIZE     =   30000;
const BMP_WORK_BUFF_INCREMENT  =    5000;

// ***********************************************************************
//  Structures
// ***********************************************************************

{
typedef struct _BITMAPSTATS
 /
  SHORT            sWidth;
  SHORT            sHeight;
  BYTE             byBitDepth;
  / BITMAPSTATS;
typedef BITMAPSTATS *  PBITMAPSTATS;
}

type 
  BITMAPSTATS = record
    sWidth : SHORT;
    sHeight: SHORT;
    byBitDepth: BYTE;
  end;
  PBITMAPSTATS = ^BITMAPSTATS;

// ***********************************************************************
//  Class Definition
// ***********************************************************************

//class BitmapPainter
// 
//  protected:

//  public:
    // Constructor
    {
    BitmapPainter (VOID);
    ~BitmapPainter (VOID);
    ERRORSTATUS AssociateCanvas
      (
      PCANVAS      pcnvCanvasIn
      );
    VOID DissociateCanvas
      (
      VOID
      );
    ERRORSTATUS InitializeEncodeBuffer
      (
      VOID
      );
    ERRORSTATUS AssureEncodeMemory
      (
      ULONG            ulAmount
      );
    ERRORSTATUS TrimEncodeBuffer
      (
      VOID
      );
    ERRORSTATUS FreeEncodeBuffer
      (
      VOID
      );
}

type
  PULONG = ^ULONG;
  
  BitmapPainter = class
  private
  
  protected
  
  usLastErrorCode: USHORT;
  ulPainterType: ULONG;
  byWhite: BYTE;
  byBlack: BYTE;
  abyPalette: array [0..1024-1] of BYTE;
  pbySourceBuffer: PBYTE;
  ulBufferSize: ULONG;
  ulBufferOffset: ULONG;
  pcnvDestCanvas: pCanvas; 
  
  pbyEncodeBuffer: PBYTE;
  ulEncBufferSize: ULONG;
  ulEncBufferOffset: ULONG;

  public

    // Constructor
    constructor Create; // BitmapPainter_BitmapPainter;
    
    // destructor
    destructor Destroy; override; // BitmapPainter_Destroy
    
    // function  AssociateBuffer (pbyBufferIn: PBYTE; ulBufferSizeIn: ULONG) : ERRORSTATUS;
    // procedure DissociateBuffer;
    function  AssociateCanvas (pcnvCanvasIn: PCANVAS) : ERRORSTATUS;
    procedure DissociateCanvas;
    function  InitializeEncodeBuffer : ERRORSTATUS;
    function  AssureEncodeMemory (ulAmount : ULONG) : ERRORSTATUS;
    function  TrimEncodeBuffer: ERRORSTATUS;
    function  FreeEncodeBuffer : ERRORSTATUS;
    
    // virtual functions
    {
    virtual ERRORSTATUS PaintCanvas
      (
      VOID
      ) = 0;
    virtual ERRORSTATUS EncodeCanvas
      (
      PBYTE        pbyPalette,
      PBYTE *      ppbyBufferOut,
      PULONG       pulBufferSizeOut
      ) = 0;
    virtual ERRORSTATUS AssociateBuffer
      (
      PBYTE        pbyBufferIn,
      ULONG        ulBufferSizeIn
      );
    virtual VOID DissociateBuffer
      (
      VOID
      );
    virtual ERRORSTATUS QueryBitmapStats
      (
      PBITMAPSTATS     pbmsStatsOut
      ) = 0;
    }
    function  PaintCanvas: ERRORSTATUS; virtual;
    function  EncodeCanvas(pbyPalette: PBYTE; ppbyBufferOut: array of byte; pulBufferSizeOut: PULONG): ERRORSTATUS; virtual;
    function  AssociateBuffer(pbyBufferIn: PBYTE; ulBufferSizeIn: ULONG): ERRORSTATUS; virtual;
    procedure DissociateBuffer; virtual;
    function  QueryBitmapStats(pbmsStatsOut: PBITMAPSTATS): ERRORSTATUS; virtual;
    
    // inline functions

    procedure MonoSetWhite(byWhiteIn: BYTE);
    // {byWhite = byWhiteIn;};

    procedure MonoSetBlack(byBlackIn: BYTE);
     // {byBlack = byBlackIn;};

    function QueryType: ULONG;
     // {return (ulPainterType);};

    procedure SetType(ulType: ULONG);
     // {ulPainterType = ulType;};

    function QueryPaletteBuffer: PBYTE;
     // {return (abyPalette);};

    function QueryLastErrorCode: USHORT;
     // {return (usLastErrorCode);};

  end; {class def}


implementation

//#ifndef ERRCODES_HPP
//#define  ERRCODES_HPP

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

// #endif // ERRCODES_HPP

    // virtual functions
{
    virtual ERRORSTATUS PaintCanvas
      (
      VOID
      ) = 0;
    virtual ERRORSTATUS EncodeCanvas
      (
      PBYTE        pbyPalette,
      PBYTE *      ppbyBufferOut,
      PULONG       pulBufferSizeOut
      ) = 0;
    virtual ERRORSTATUS AssociateBuffer
      (
      PBYTE        pbyBufferIn,
      ULONG        ulBufferSizeIn
      );
    virtual VOID DissociateBuffer
      (
      VOID
      );
    virtual ERRORSTATUS QueryBitmapStats
      (
      PBITMAPSTATS     pbmsStatsOut
      ) := 0;
}

    // inline functions

    procedure BitmapPainter.MonoSetWhite(byWhiteIn: byte);
      begin
        byWhite := byWhiteIn;
      end;

    procedure BitmapPainter.MonoSetBlack(byBlackIn: byte);
      begin
        byBlack := byBlackIn;
      end;

    function BitmapPainter.QueryType: ULONG;
      begin
        QueryType := (ulPainterType);
      end;

    procedure BitmapPainter.SetType(ulType: ULONG);
      begin
        ulPainterType := ulType;
      end;

    function BitmapPainter.QueryPaletteBuffer: PBYTE;
      begin
        QueryPaletteBuffer := (abyPalette)
      end;

    function BitmapPainter.QueryLastErrorCode: USHORT;
      begin
        QueryLastErrorCode := (usLastErrorCode)
     end;

{$i memcpy.pas}
{ -----------------------------------------------------------------
                               BITMAP.CPP

     This is the base class from which bitmap decompressors will be
  derived.  It should provide all the basic functionality so that
  new compression/decompression methods may be added without affecting
  the main code.

     BitmapPainter is an abstract class, so only derived types may be
  created and used.

     A BitmapPainter will take a buffer which holds the compressed
  graphic information, and write the decompressed image to a Canvas.

     Sample code for the article "Gearing Up For Games" in EDM/2.

                 Article and code by Michael T. Duffy

   ----------------------------------------------------------------- }

// ***********************************************************************
//  Header Files
// ***********************************************************************

{
#include "newtypes"
#include "canvas.hpp"
#include "bitmap.hpp"
#include "errcodes.hpp"

}

// ***********************************************************************
//  Error Codes
// ***********************************************************************


// ***********************************************************************
//  Code
// ***********************************************************************

//........................................................................
constructor BitmapPainter.Create; // BitmapPainter;
//........................................................................
begin
  MonoSetWhite ($ff);
  MonoSetBlack ($00);
  fillchar(abyPalette,768,0);
  pbySourceBuffer   := nil;
  pcnvDestCanvas    := nil;
  ulBufferSize      := 0;
  ulBufferOffset    := 0;
  usLastErrorCode   := 0;
  ulPainterType     := 0;

  pbyEncodeBuffer   := nil;
  
  ulEncBufferSize   := 0;
  ulEncBufferOffset := 0;
end;

//........................................................................
destructor BitmapPainter.Destroy; // ~BitmapPainter
//........................................................................
begin
end;

//........................................................................
function BitmapPainter.AssociateBuffer (pbyBufferIn: PBYTE; ulBufferSizeIn: ULONG) : ERRORSTATUS;
//........................................................................
begin

  // Make sure the buffer is of a valid size
  if (ulBufferSizeIn = 0) then
  begin
  usLastErrorCode := ERR_GEN_BAD_PARAM;
  AssociateBuffer := (ES_ERROR);
  end;
  
  // Set internal variables to work on the requested buffer.
  pbySourceBuffer := pbyBufferIn;
  ulBufferSize    := ulBufferSizeIn;
  ulBufferOffset  := 0;
  AssociateBuffer := (ES_NO_ERROR);
end;

//........................................................................
procedure BitmapPainter.DissociateBuffer;
//........................................................................
begin

  // Clear internal variables that point to any existing buffer.
  pbySourceBuffer := nil;
  ulBufferSize    := 0;
  ulBufferOffset  := 0;
end;

//........................................................................
function BitmapPainter.AssociateCanvas (pcnvCanvasIn: PCANVAS) : ERRORSTATUS;
//........................................................................
begin
  // Canvases should not be assigned a nil value with this function.
  //  Use DissociateCanvas
  if (pcnvCanvasIn = nil) then
  begin
  usLastErrorCode := ERR_GEN_BAD_PARAM;
  AssociateCanvas := (ES_ERROR);
  end;
  
  pcnvDestCanvas := pcnvCanvasIn;
  AssociateCanvas := (ES_NO_ERROR);
end;

//........................................................................
procedure BitmapPainter.DissociateCanvas;
//........................................................................
begin
  pcnvDestCanvas := nil;
end;


//........................................................................
function BitmapPainter.InitializeEncodeBuffer : ERRORSTATUS;
//........................................................................

begin

  // Allocate initial memory for the buffer.
  ulEncBufferSize := BMP_WORK_BUFFER_SIZE;
  // if ((pbyEncodeBuffer := (PBYTE) malloc (ulEncBufferSize)) = nil) then
  // (pbyEncodeBuffer := (PBYTE) malloc (ulEncBufferSize));
  getmem(pbyEncodeBuffer,ulEncBufferSize);
  if pbyEncodeBuffer = nil then 
  begin
  usLastErrorCode := ERR_GEN_ALLOC_FAILURE;
  InitializeEncodeBuffer := (ES_ERROR);
  end;
  ulEncBufferOffset := 0;
  InitializeEncodeBuffer := (ES_NO_ERROR);
end;


//........................................................................
function BitmapPainter.AssureEncodeMemory (ulAmount : ULONG) : ERRORSTATUS;
//........................................................................

// This routine makes sure there is enough memory in the encode buffer for
//   storage of a piece of encoded info.  If there is not enough room in the
//   current buffer, a new buffer is created, the old buffer is copied over,
//   and all internal pointers are updated.  If a new buffer cannot be
//   allocated, this routine returns an error.
var
  pbyNewBuffer: PBYTE;

begin
  if ((ulEncBufferOffset + ulAmount) >= ulEncBufferSize) then
  begin
  // You need a larger encode buffer
  //if ((pbyNewBuffer =
  //  (PBYTE) malloc (ulEncBufferSize + BMP_WORK_BUFF_INCREMENT)) = nil) then
    getmem(pbyNewBuffer,ulEncBufferSize + BMP_WORK_BUFF_INCREMENT);
    if pbyNewBuffer = nil then
    begin
    usLastErrorCode := ERR_GEN_ALLOC_FAILURE;
    AssureEncodeMemory := (ES_ERROR);
    end; {if}

  memcpy (pbyNewBuffer, pbyEncodeBuffer, ulEncBufferSize);
  freemem (pbyEncodeBuffer);
  ulEncBufferSize := ulEncBufferSize + BMP_WORK_BUFF_INCREMENT;
  pbyEncodeBuffer  := pbyNewBuffer;
  end; {if}
  AssureEncodeMemory := (ES_NO_ERROR);
end;

//........................................................................
function BitmapPainter.TrimEncodeBuffer: ERRORSTATUS;
//........................................................................
// This routine reduces the size of the encode buffer to fit the contained
//   data exactly.
var
  pbyNewBuffer: PBYTE;

begin
  // Allocate final buffer the same size as existing information
  // if ((pbyNewBuffer := (PBYTE) malloc (ulEncBufferOffset)) = nil) then
  getmem(pbyNewBuffer,ulEncBufferOffset);
  if pbyNewBuffer = nil then
  begin
  usLastErrorCode := ERR_GEN_ALLOC_FAILURE;
  TrimEncodeBuffer := (ES_ERROR);
  end;
  
  memcpy (pbyNewBuffer, pbyEncodeBuffer, ulEncBufferSize);
  freemem (pbyEncodeBuffer);

  ulEncBufferSize  := ulEncBufferOffset;
  pbyEncodeBuffer  := pbyNewBuffer;
  
  TrimEncodeBuffer := (ES_NO_ERROR);
end;

//........................................................................
function  BitmapPainter.FreeEncodeBuffer : ERRORSTATUS;
//........................................................................

begin

  if (pbyEncodeBuffer = nil) then
  begin
  usLastErrorCode := ERR_GEN_BAD_PARAM;
  FreeEncodeBuffer := (ES_ERROR);
  end;
  
  freemem (pbyEncodeBuffer);
  pbyEncodeBuffer   := nil;
  ulEncBufferOffset := 0;
  ulEncBufferSize   := 0;
  
  FreeEncodeBuffer := (ES_NO_ERROR);
end;

// virtual stuff
// Error: Procedure directive "VIRTUAL" not allowed in implementation section

function  BitmapPainter.PaintCanvas: ERRORSTATUS;
begin
  PaintCanvas:=0
end;

function  BitmapPainter.EncodeCanvas(pbyPalette: PBYTE; ppbyBufferOut: array of byte; pulBufferSizeOut: PULONG): ERRORSTATUS;
begin
  EncodeCanvas:=0
end;

//function  AssociateBuffer(pbyBufferIn: PBYTE; ulBufferSizeIn: ULONG): ERRORSTATUS; virtual;
//procedure DissociateBuffer; virtual;

function  BitmapPainter.QueryBitmapStats(pbmsStatsOut: PBITMAPSTATS): ERRORSTATUS;
begin
  QueryBitmapStats :=0
end;



end.

