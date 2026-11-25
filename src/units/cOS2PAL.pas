unit cOS2PAL;

{ 20261108 created       }
{ 20261114 class version }

{$MODE OBJFPC}

interface

uses os2def, pmwin, pmgpi, pmbitmap, mmbase, dive, ccanvas; //, cBitmapPainter;

type
  HPAL = cardinal;
  HDC  = cardinal;
  PULONG = ^ULONG;
  
type  
  OS2Palette = class
  
  private
    usLastErrorCode: USHORT;
    
    abyData: array [0..1024-1] of BYTE;
    usCurrentFormat: USHORT;
    byFlag: BYTE;

    // OS/2 specific variables.
    h_ab : HAB;
    h_dc : HDC;
    h_ps : HPS;
    h_wnd : HWND;
    h_pal : HPAL;
    
  public
  
    // 
    constructor OS2PALCreate;
    constructor OS2PALCreate (habIn  : HAB;
                hwndIn : HWND;
                hdcIn  : HDC;
                hpsIn  : HPS
          ); overload;
    
    // destructor
    destructor Destroy; override; // ~OS2Palette
    
    // members/nethods
    procedure Default16;
    procedure Convert(ulFormat: ULONG);
    procedure InitSystemPalette
      (             habIn: HAB;
                hwndIn:HWND;
                hdcIn: HDC;
                hpsIn: HPS
     );
    procedure UninitSystemPalette;
    procedure SuspendSystemPalette;
    procedure RestoreSystemPalette;
    procedure SetAsDiveSource(h_dive: HDIVE);
    procedure SetAsDiveDestination(h_dive: HDIVE);
    procedure LoadActualPalette(hpsIn: HPS);
    procedure SetValuesFromRaw8
     (           pbyValuesIn: PBYTE;
              ulStart: ULONG;
              ulNumber: ULONG
     );
    function  PaletteFromBlock (pbyBlock: PBYTE; ulBlockSize: ULONG): ERRORSTATUS;
    
    function  RequestSaveBlock (ppbyBlockOut: {*} PBYTE; pulSizeOut : PULONG): ERRORSTATUS;
    
    function  ReleaseSaveBlock (ppbyBlockOut: PBYTE): ERRORSTATUS;
    
    function  QueryFlag: BYTE;
    procedure SetFlag (byFlagIn: byte);
    function  QueryPaletteArray: PBYTE;
    
  end; {class type def}

// ***********************************************************************
// OS2PAL.HPP
// ***********************************************************************
//
// Written by Michael T. Duffy
//
// Object derived from palette object for handling palettes under OS/2
//
// ***********************************************************************

// ***********************************************************************
//  Constant Definitions
// ***********************************************************************

const        PAL_FMT_UNKNOWN{:USHORT}        = 0;
const        PAL_FMT_8BIT{:USHORT}           = 1;
const        PAL_FMT_OS2{:USHORT}            = 2;

// These color definitions are for the first 16 colors in a standard VGA
//  palette.

//#ifndef COLOR_DEFS
//#define COLOR_DEFS
const {BYTE}      BLACK        = 0;
const {BYTE}      BLUE         = 1;
const {BYTE}      GREEN        = 2;
const {BYTE}      CYAN         = 3;
const {BYTE}      RED          = 4;
const {BYTE}      MAGENTA      = 5;
const {BYTE}      BROWN        = 6;
const {BYTE}      LIGHTGRAY    = 7;
const {BYTE}      DARKGRAY     = 8;
const {BYTE}      LIGHTBLUE    = 9;
const {BYTE}      LIGHTGREEN   = 10;
const {BYTE}      LIGHTCYAN    = 11;
const {BYTE}      LIGHTRED     = 12;
const {BYTE}      LIGHTMAGENTA = 13;
const {BYTE}      YELLOW       = 14;
const {BYTE}      WHITE        = 15;
// #endif



// ***********************************************************************
//  Internal Structures
// ***********************************************************************

{
typedef struct _PALLIBHDR
  /
  USHORT           usFormat;
  BYTE             byFlag;
  / PALLIBHDR;
typedef PALLIBHDR *  PPALLIBHDR;
}

type
  PALLIBHDR = record
    usFormat: USHORT;
    byFlag: byte;
  end;
  PPALLIBHDR = ^PALLIBHDR;

// ***********************************************************************
//  Class Definition
// ***********************************************************************


implementation

{$i memcpy.pas}

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

{ i OS2PAL_hpp_hdr.pas}
// ***********************************************************************
// OS2PAL.HPP
// ***********************************************************************

    // Inline functions
    procedure OS2Palette.SetFlag (byFlagIn: byte);
      begin
        byFlag := byFlagIn
      end;

    function OS2Palette.QueryFlag: BYTE;
      begin 
        QueryFlag := byFlag
      end;

    function OS2Palette.QueryPaletteArray: PBYTE;
      begin
        QueryPaletteArray := abyData
      end;

   // function QueryLastErrorCode: USHORT;
   //   begin
   //     QueryLastErrorCode := (usLastErrorCode)
   //  end;

// end // OS2PAL.HPP


const
  NULLHANDLE = 0;
type
  PLONG  = ^LONG;
  
{ -----------------------------------------------------------------
                               OS2PAL.CPP
     This class is for manipulation of the OS/2 palette.

     Sample code for the article "Gearing Up For Games" in EDM/2.

                 Article and code by Michael T. Duffy

   ----------------------------------------------------------------- }

// ***********************************************************************
//  Header Files
// ***********************************************************************

{
#include "newtypes.hpp"
#include "os2pal.hpp"
#include "errcodes.hpp"
}


// ***********************************************************************
//  Constant Palette Definitions
// ***********************************************************************

// Note that OS2 palettes are stored with their colors in the order
//  Blue, Greeen, Red, whereas palettes normally used with VGA from DOS
//  (such as PCX palettes) are stored as Red, Green, Blue.

var               abyOS2Default16Palette: array [0..64-1] of byte =
//                                    begin
//  B    G    R       O           B    G    R       O
(
    0,   0,   0, PC_RESERVED,   171,   0,   0, PC_RESERVED,
    0, 171,   0, PC_RESERVED,   171, 171,   0, PC_RESERVED,
    0,   0, 171, PC_RESERVED,   171,   0, 171, PC_RESERVED,
    0,  85, 171, PC_RESERVED,   171, 171, 171, PC_RESERVED,
   85,  85,  85, PC_RESERVED,   255,  85,  85, PC_RESERVED,
   85, 255,  85, PC_RESERVED,   255, 255,  85, PC_RESERVED,
   85,  85, 255, PC_RESERVED,   255,  85, 255, PC_RESERVED,
   85, 255, 255, PC_RESERVED,   255, 255, 255, PC_RESERVED);
   

// const BYTE         abyDefault16Palette[] =
const         abyDefault16Palette: array [0..48-1] of byte =
//                                    begin
//   R    G   B          R     G    B
(
     0,   0,  0,         0,    0, 171,
     0, 171,  0,         0,  171, 171,
   171,   0,  0,       171,    0, 171,
   171,  85,  0,       171,  171, 171,
    85,  85, 85,        85,   85, 255,
    85, 255, 85,        85,  255, 255,
   255,  85, 85,       255,   85, 255,
   255, 255, 85,       255,  255, 255);
   
// ***********************************************************************
//  Code
// ***********************************************************************

//........................................................................
constructor OS2Palette.OS2PALCreate;
//........................................................................
begin
  usLastErrorCode  := 0;
  usCurrentFormat  := PAL_FMT_UNKNOWN;
  SetFlag (0);
  
  h_ab  := NULLHANDLE;
  h_dc  := NULLHANDLE;
  h_ps  := NULLHANDLE;
  h_wnd := NULLHANDLE;
  h_pal := NULLHANDLE;
end;

//........................................................................
constructor OS2Palette.OS2PALCreate (habIn  : HAB;
                hwndIn : HWND;
                hdcIn  : HDC;
                hpsIn  : HPS
          ); overload;
//........................................................................
begin
  SetFlag (0);
  
  h_ab  := habIn;
  h_dc  := hdcIn;
  h_ps  := hpsIn;
  h_wnd := hwndIn;
  h_pal := NULLHANDLE;
  
  InitSystemPalette (habIn, hwndIn, hdcIn, hpsIn);
end;

//........................................................................
destructor OS2Palette.Destroy; // ~OS2Palette
//........................................................................
begin
  UninitSystemPalette;
  
  SetFlag (0);
  
  h_ab  := NULLHANDLE;
  h_dc  := NULLHANDLE;
  h_ps  := NULLHANDLE;
  h_wnd := NULLHANDLE;
end;

//........................................................................
procedure  OS2Palette.Default16;
//........................................................................
begin
  memcpy (abyData, abyDefault16Palette, sizeof (abyDefault16Palette));
  usCurrentFormat := PAL_FMT_8BIT;
end;

//........................................................................
procedure  OS2Palette.Convert(ulFormat: ULONG);
//........................................................................
var
  lIndex: LONG;
  byRed : BYTE;
  byBlue: BYTE;
  byGreen:BYTE;

begin
  case (ulFormat) of
  PAL_FMT_8BIT:
    begin
    if (usCurrentFormat = PAL_FMT_OS2) then
      begin
      lIndex := 0;
       while (lIndex < 256) do
        begin
        byRed   := abyData [(lIndex * 4) + 2];
        byGreen := abyData [(lIndex * 4) + 1];
        byBlue  := abyData [(lIndex * 4) + 0];

        abyData [(lIndex * 3) + 0] := byRed;
        abyData [(lIndex * 3) + 1] := byGreen;
        abyData [(lIndex * 3) + 2] := byBlue;

        lIndex := lIndex +1;
        end; // while (lIndex < 256);
      usCurrentFormat := PAL_FMT_8BIT;
      end; {if}
    end;
  PAL_FMT_OS2:
    begin
    if (usCurrentFormat = PAL_FMT_8BIT) then
      begin
      lIndex := 255;
      while (lIndex >= 0) do
        begin
        byRed   := abyData [(lIndex * 3) + 0];
        byGreen := abyData [(lIndex * 3) + 1];
        byBlue  := abyData [(lIndex * 3) + 2];

        abyData [(lIndex * 4) + 3] := byFlag;
        abyData [(lIndex * 4) + 2] := byRed;
        abyData [(lIndex * 4) + 1] := byGreen;
        abyData [(lIndex * 4) + 0] := byBlue;

        lIndex := lIndex -1;
        end; // while (lIndex >= 0);
      usCurrentFormat := PAL_FMT_OS2;
      end {if}
    else if (usCurrentFormat = PAL_FMT_OS2) then
      begin
      // Just duplicate the flag into all the flag bytes.
      lIndex := 255;
      while (lIndex >= 0) do
        begin
        abyData [(lIndex * 4) + 3] := byFlag;
        lIndex := lIndex -1;
        end; // while (lIndex >= 0);
      end; {if}
    end;
  PAL_FMT_UNKNOWN:
    begin
    // Can't convert an unknown format (blank) palette to anything, so just
    //  don't do anything.
    end;
  otherwise
    begin
    // Bad format.  Possibly signal error here.
    end;
  end; {case}
end;

//........................................................................
procedure  OS2Palette.InitSystemPalette
  (             habIn: HAB;
                hwndIn:HWND;
                hdcIn: HDC;
                hpsIn: HPS
  );
//........................................................................
var
  ulcPaletteColors: ULONG = 256;
  // sizl: SIZEL; // unused

begin
  UninitSystemPalette;
  
  if (habIn  <> NULLHANDLE) then h_ab  := habIn;
  if (hdcIn  <> NULLHANDLE) then h_dc  := hdcIn;
  if (hpsIn  <> NULLHANDLE) then h_ps  := hpsIn;
  if (hwndIn <> NULLHANDLE) then h_wnd := hwndIn;

  // sizl.cx := 0;
  // sizl.cy := 0;
  
  Convert (PAL_FMT_OS2);
  
  h_pal := GpiCreatePalette (h_ab, LCOL_PURECOLOR, LCOLF_CONSECRGB,
                           ulcPaletteColors, {(PULONG)} abyData);
                           
  GpiSelectPalette  (h_ps, h_pal);
  WinRealizePalette (h_wnd, h_ps, @ulcPaletteColors);
end;

//........................................................................
procedure  OS2Palette.UninitSystemPalette;
//........................................................................
begin
  if (h_ps  <> NULLHANDLE) then
    GpiSelectPalette (h_ps, NULLHANDLE);
  if (h_pal <> NULLHANDLE) then
    GpiDeletePalette (h_pal);
    
  h_ps  := NULLHANDLE;
  h_wnd := NULLHANDLE;
end;

//........................................................................
procedure  OS2Palette.SuspendSystemPalette;
//.......................................................................
var
  ulcPaletteColors: ULONG = 256;
begin
  GpiSelectPalette  (h_ps, NULLHANDLE);
  WinRealizePalette (h_wnd, h_ps, @ulcPaletteColors);
end;

//........................................................................
procedure  OS2Palette.RestoreSystemPalette;
//........................................................................
var
  ulcPaletteColors: ULONG = 256;           
begin
  GpiSelectPalette  (h_ps, h_pal);
  WinRealizePalette (h_wnd, h_ps, @ulcPaletteColors);
end;

//........................................................................
procedure  OS2Palette.SetAsDiveSource(h_dive: HDIVE);
//........................................................................
begin
  Convert (PAL_FMT_OS2);
  DiveSetSourcePalette (h_dive, 0, 256, {(PBYTE)} @abyData);
end;

//........................................................................
procedure  OS2Palette.SetAsDiveDestination(h_dive: HDIVE);
//........................................................................
begin
  Convert (PAL_FMT_OS2);
  DiveSetDestinationPalette (h_dive, 0, 256, {(PBYTE)} @abyData);
end;

//........................................................................
procedure  OS2Palette.LoadActualPalette(hpsIn: HPS);
//........................................................................

begin
  Convert (PAL_FMT_OS2);
  
  if (hpsIn  <> NULLHANDLE) then h_ps := hpsIn;
  
  fillchar(abyData, sizeof (abyData), 0);
  // GpiQueryRealColors (hps, 0, 0, 256, (PLONG) abyData);
  GpiQueryRealColors (h_ps, 0, 0, 256, {(PLONG)} PLONG(@abyData)^); // ???
  usCurrentFormat := PAL_FMT_OS2;
end;

//........................................................................
procedure  OS2Palette.SetValuesFromRaw8
  (           pbyValuesIn: PBYTE;
              ulStart: ULONG;
              ulNumber: ULONG
  );
//........................................................................
var
  ulSavedFormat: ULONG;
begin
  ulSavedFormat := usCurrentFormat;
  
  // Get ready to receive 8 bit values
  Convert (PAL_FMT_8BIT);
  // Copy over the range of values requested
  memcpy (@abyData [ulStart * 3], pbyValuesIn, ulNumber * 3);
  // return to the original format
   Convert (ulSavedFormat);
end;

//........................................................................
function  OS2Palette.PaletteFromBlock (pbyBlock: PBYTE; ulBlockSize: ULONG): ERRORSTATUS;
//........................................................................
var
  ulDataSize: ULONG;
  ppalhdr: PPALLIBHDR;

begin
  // Set a pointer to the header information ...
  ppalhdr := PPALLIBHDR(pbyBlock);
  // ... and move the Block pointer to the beginning of the data.
  pbyBlock := pbyBlock + sizeof (PALLIBHDR);
  
  // Data is saved as an 8-bit palette regardless of the format
  usCurrentFormat := PAL_FMT_8BIT;
  
  // if the format is saved as an OS/2 format, set the byte to use as the flag.
  if (ppalhdr^.usFormat = PAL_FMT_OS2) then
  begin
    SetFlag (ppalhdr^.byFlag);
  end
  else
  begin
    SetFlag (0);
  end;
  
  // Get the size of the data.
  ulDataSize := ulBlockSize - sizeof (PALLIBHDR);
  
  // It should be 768 bytes (256 colors at 3 bytes/entry).
  if (ulDataSize <> 768) then
  begin
  usLastErrorCode := ERR_PAL_DATA_CORRUPTED;
  PaletteFromBlock := ES_ERROR;
  end;
  
  // memset (abyData, 0, 1024);
  fillchar(abyData, 1024, 0);
  memcpy (abyData, pbyBlock, ulDataSize);
  
  // Convert the data to the format it was saved as.
  Convert (ppalhdr^.usFormat);
  PaletteFromBlock := ES_NO_ERROR;
end;

//........................................................................
function OS2Palette.RequestSaveBlock (ppbyBlockOut: {*} PBYTE; pulSizeOut : PULONG): ERRORSTATUS;
//........................................................................
var
  ppalhdr: PPALLIBHDR;
  
  pbyBlock: PBYTE;
  usSavedFormat: USHORT;
  ulBlockSize: ULONG;

begin
  ulBlockSize := sizeof (PALLIBHDR) + 768;
  
  // Allocate memory for the block of saved data.
  getmem(pbyBlock,ulBlockSize);
  if (pbyBlock = nil) then
  begin
    usLastErrorCode := ERR_GEN_ALLOC_FAILURE;
    RequestSaveBlock := ES_ERROR;
  end;
  
  // save the current format so you can return to it when you are done.
  usSavedFormat := usCurrentFormat;
  
  // Convert to 8 bit format, because that is how all palettes are to be saved.
  Convert (PAL_FMT_8BIT);
  
  // Set the return values.
  // *ppbyBlockOut    = pbyBlock;
  {*p} ppbyBlockOut^   := pbyBlock^; // ???
  // *pulSizeOut      = ulBlockSize;
  {*} pulSizeOut^      := ulBlockSize; // ???
  
  // set a pointer to the first part of the block.  This will be the header.
  ppalhdr          := PPALLIBHDR(pbyBlock);
  fillchar( ppalhdr, sizeof (PALLIBHDR),  0);
  
  // Fill in and move past header.
  ppalhdr^.usFormat := usSavedFormat;
  ppalhdr^.byFlag   := byFlag;
  pbyBlock := pbyBlock + sizeof (PALLIBHDR);
  
  // Write data.
  memcpy (pbyBlock, abyData, 768);
  
  // restore original format.
  Convert (usSavedFormat);
  
  RequestSaveBlock := ES_NO_ERROR;
end;

//........................................................................
function  OS2Palette.ReleaseSaveBlock (ppbyBlockOut: PBYTE): ERRORSTATUS;
//........................................................................
begin

  if ((ppbyBlockOut <> nil) and ( {*} ppbyBlockOut <> nil)) then // ???
  begin
  freemem (ppbyBlockOut);
  {*} ppbyBlockOut := nil;
  ReleaseSaveBlock := ES_NO_ERROR;
  end
  else
  begin
  usLastErrorCode := ERR_GEN_BAD_PARAM;
  ReleaseSaveBlock := ES_ERROR;
  end;
end;


end.





