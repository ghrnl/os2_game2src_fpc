{ --------------------------------------------------------------------
      This is the main OS/2 shell from which the game will be hung.
   Almost all other modules should be OS inspecific, with the exception
   of the input modules.

     Sample code for the article "Gearing Up For Games" in EDM/2.

                 Article and code by Michael T. Duffy

-------------------------------------------------------------------- }

{ 2026 port to fpc 3.2.2 G.H. Renkema                                }

program game2;

{$APPTYPE GUI}
{$R GAME2.RC}

uses os2def, pmwin, pmgpi, mmbase, dive, divext, ccanvas,
  cPCX,
  cOS2PAL,
  //cBitmapPainter,  // NOT NEEDED HERE
  sysutils;
  
{$i pmgpi.inc}

const
  NULLHANDLE = 0;

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


type
  HDC   = cardinal;
  LONG  = longint;
  BOOL  = longbool;
  HWND  = cardinal;
  SHORT = integer;
  // this is the CLASS version of GAME2 using ccanvas
  
const
  ID_APPMAIN                =    1;
  IDM_QUIT                  =    5;
  IDS_ERR_CREATE_DIVEBUFFER = 1001;
  
  FOURCC_SCRN               =    0;
  
// Note: You can see what happens when the palette is not suspended or
//       restored upon the WM_ACTIVATE message by commenting out the
//       following $define

{ DEFINE ADJUST_PALETTE_ON_FOCUS}

// ***********************************************************************
//  Variables
// ***********************************************************************

var
  // OS/2 environment variables.
  h_ab          : HAB;
  h_wndFrame, h_wndClient: HWND;
  szTitle       : array[0..255] of char;
  bAppIsActive  : BOOL = FALSE;
  h_dcClientHDC : HDC  = NULLHANDLE;
  h_psMainHPS   : HPS  = NULLHANDLE;

const
  szClientClass: pChar = 'CLIENT'; // CHAR

var  
  lTotalWidth : LONG = 320;
  lTotalHeight: LONG = 200;

  // Dive variables
  DiveCaps   : TDIVE_CAPS; // = {0};
  fccFormats : array [0..100-1] of FOURCC; // = {0};
  h_Dive     : HDIVE          = NULLHANDLE;
  bDiveHaveBuffer   : boolean  = FALSE;
  ulDiveBufferNumber: ULONG = 0;
  
  // Canvas variables
  pcnvMainCanvas: pCanvas = nil;
  
  // Palette objects
  pal2Real : OS2Palette;
  pal2Image: OS2Palette;
  
const
  ulIMAGE_WIDTH  = 320;
  ulIMAGE_HEIGHT = 200;

{$i ..\inc\errdisp.pas}
{$i ..\inc\SHORT1FROMMP.pas}

// ***********************************************************************
//  Code
// ***********************************************************************


//........................................................................
function InitializeDive: ERRORSTATUS;
//........................................................................
var
  dummybuffer: pointer;
  
begin
  // Get the screen capabilities, and if the system supports only 16 colors
  //  the program should be terminated.
  
  DiveCaps.pFormatData    := @fccFormats;
  DiveCaps.ulFormatLength := 100;
  DiveCaps.ulStructLen    := sizeof(TDIVE_CAPS);

  if ( DiveQueryCaps ( @DiveCaps, DIVE_BUFFER_SCREEN ) >0 ) then
   begin
   WinMessageBox( HWND_DESKTOP, HWND_DESKTOP,
       'Error: DIVE routines cannot function in this system environment.',
       '   This program is unable to run.', 0, MB_OK or MB_INFORMATION );
   InitializeDive := ES_ERROR;
   exit;
   end;

  if ( DiveCaps.ulDepth < 8 ) then
   begin
   WinMessageBox( HWND_DESKTOP, HWND_DESKTOP,
       'Error: Not enough screen colors to run DIVE.  Must be at least 256 colors.',
       '   This program is unable to run.', 0, MB_OK or MB_INFORMATION );
   InitializeDive := ES_ERROR;
   exit;
   end;

  // Get an instance of DIVE APIs.
  dummybuffer := nil;
  if ( DiveOpen ( h_Dive, 0 {FALSE},  dummybuffer {nil} ) >0 ) then
   begin
   WinMessageBox( HWND_DESKTOP, HWND_DESKTOP,
       'Error: Unable to open an instance of DIVE.',
       '   This program is unable to run.', 0, MB_OK or MB_INFORMATION );
   InitializeDive := ES_ERROR;
   exit;
   end;

  InitializeDive := ES_NO_ERROR;
end; {InitializeDive}

//........................................................................
function DrawTestPcx: ERRORSTATUS;
//........................................................................

const
  ofRead        = $0000;     {Open for reading}
  ofWrite       = $0001;     {Open for writing}
  
var
  p_pcxPainter: PcxPainter;
  ulFileSize: ULONG;
  pbyBlock: PBYTE;
  pbyPalette: PBYTE;
  // FILE *             fp;
  fp: THandle; // file // see CH14 HEAD

begin

  // init needed or not
  fillchar(p_pcxPainter,sizeof(p_pcxPainter),0);
  p_pcxPainter := PcxPainter.PcxCreate; // ???
  
  // Load the sample PCX file
  
  // Open the file.
  // if ((fp := fopen ('test1.pcx', 'rb')) = nil) then
  fp := FileOpen ('test1.pcx', ofRead);
  if (fp = feInvalidHandle) then
  begin
  DrawTestPcx := ES_ERROR;
  exit;
  end;
  
  // Get it's total size
  ulFileSize := FileSeek (fp, 0, fsFromEnd); // ??? See rtl.pdf FileSeek
  
  // fseek (fp, 0, SEEK_SET);
  FileSeek (fp, 0, fsFromBeginning);
  
  // Allocate memory for the file
  getmem (pbyBlock, ulFileSize);
  if (pbyBlock = nil) then
  begin
  DrawTestPcx := ES_ERROR;
  exit;
  end;
  
  // Read the entire file.
  if (FileRead (fp, pbyBlock^, ulFileSize) <> ulFileSize) then
  begin
  // Unable to read the entire file.
  DrawTestPcx := ES_ERROR;
  exit;
  end;
  
  // fclose (fp);
  FileClose (fp);
  
  // Tell the painter object which buffer to use as input.
  if (p_pcxPainter.AssociateBuffer (pbyBlock, ulFileSize) = ES_ERROR) then
  begin
  PostError (h_ab, h_wndFrame, p_pcxPainter.QueryLastErrorCode);
  DrawTestPcx := ES_ERROR;
  exit;
  end;
  
  // Tell the painter object which canvas to use as output.
  if (p_pcxPainter.AssociateCanvas (pcnvMainCanvas) = ES_ERROR) then
  begin
  PostError (h_ab, h_wndFrame,p_pcxPainter.QueryLastErrorCode);
  DrawTestPcx := ES_ERROR;
  exit;
  end;
  
  // Draw the PCX file to the main canvas
  if (p_pcxPainter.PaintCanvas = ES_ERROR) then
  begin
  PostError (h_ab, h_wndFrame, p_pcxPainter.QueryLastErrorCode);
  DrawTestPcx := ES_ERROR;
  exit;
  end;
  
  p_pcxPainter.DissociateBuffer;
  p_pcxPainter.DissociateCanvas;
  
  // Set the source palette to the PCX palette
  
  // Get a pointer to the palette.
  pbyPalette := p_pcxPainter.QueryPaletteBuffer;
  
  // Initialize the palette object from the PCX's palette.
  pal2Image.SetValuesFromRaw8 (pbyPalette, 0, 256);
  
  // Set the system palette
  pal2Image.InitSystemPalette (h_ab, h_wndClient, h_dcClientHDC, h_psMainHPS);
  
  // Tell DIVE what the source image's palette is.
  pal2Image.SetAsDiveSource (h_Dive);
  
  // Set the DIVE destination palette to the new system palette
  pal2Real.LoadActualPalette (h_psMainHPS);
  pal2Real.SetAsDiveDestination (h_Dive);
  
  // or you can use:
  //DiveSetDestinationPalette (h_Dive, 0, 256, 0 );
  
  // freemem(pbyBlock); // ???
  
  DrawTestPcx := ES_NO_ERROR;
end; {DrawTestPcx}

//........................................................................
procedure Snap1_1;
//........................................................................
var
  lBorderWidth   : LONG;
  lBorderHeight  : LONG;
  lTitlebarHeight: LONG;
  lMenuHeight    : LONG;

begin
  lBorderWidth    := WinQuerySysValue (HWND_DESKTOP, SV_CXDLGFRAME);
  lBorderHeight   := WinQuerySysValue (HWND_DESKTOP, SV_CYDLGFRAME);
  lTitlebarHeight := WinQuerySysValue (HWND_DESKTOP, SV_CYTITLEBAR);
  lMenuHeight     := WinQuerySysValue (HWND_DESKTOP, SV_CYMENU);
  
  lTotalWidth  := ulIMAGE_WIDTH + lBorderWidth * 2;
  lTotalHeight := ulIMAGE_HEIGHT + (lBorderHeight * 2) + lTitlebarHeight +
                 lMenuHeight;
                 
  // Set the window size.
  WinSetWindowPos (h_wndFrame,
                 HWND_TOP,
                 0, 0, lTotalWidth, lTotalHeight,
                 SWP_SIZE or SWP_SHOW or SWP_ACTIVATE);
end; {Snap1_1}

//........................................................................
procedure CenterWindow;
//........................................................................
var
  lcxWindowPos: LONG;
  lcyWindowPos: LONG;

begin
  lcxWindowPos   := ( WinQuerySysValue(HWND_DESKTOP, SV_CXSCREEN)
                     - lTotalWidth ) div 2;                 
  lcyWindowPos   := ( WinQuerySysValue(HWND_DESKTOP, SV_CYSCREEN)
                     - lTotalHeight ) div 2;

  // Set the window position.
  WinSetWindowPos (h_wndFrame,
                 HWND_TOP,
                 lcxWindowPos, lcyWindowPos, 0, 0,
                 SWP_MOVE or SWP_SHOW or SWP_ACTIVATE);
end; {CenterWindow}


//........................................................................
function InitializeAppWindow: ERRORSTATUS;
//........................................................................
var
  pbySurface: PBYTE;
  ulWidth: ULONG;
  usLastError: USHORT;
  
begin
  ulDiveBufferNumber := 0;
  bDiveHaveBuffer := FALSE;
  
  // Create your display canvas.  Make it a bottom up canvas for use with DIVE
  new(pcnvMainCanvas);
  pcnvMainCanvas^ := tCanvas.Create (ulIMAGE_WIDTH,
                                ulIMAGE_HEIGHT,
                                FALSE);
  usLastError := pcnvMainCanvas^.QueryLastErrorCode;
  if (usLastError <> 0) then
  begin
  PostError (h_ab, h_wndFrame, usLastError);
  InitializeAppWindow := ES_ERROR;
  exit;
  end;
  
  pbySurface := pcnvMainCanvas^.QuerySurface;
  ulWidth    := pcnvMainCanvas^.QueryWidth;
  
  // Associate the canvas with a DIVE handle
  if (DiveAllocImageBuffer (h_Dive, ulDiveBufferNumber, FOURCC_LUT8,
                          ulIMAGE_WIDTH, ulIMAGE_HEIGHT,
                          ulWidth,  pbySurface) = ES_ERROR) then
  begin
  // post error message here.
  PostError (h_ab, h_wndFrame, IDS_ERR_CREATE_DIVEBUFFER);
  InitializeAppWindow := ES_ERROR;
  exit;
  end;
  
  bDiveHaveBuffer := TRUE;
  
  // Turn on visible region notification.
  WinSetVisibleRegionNotify (h_wndClient, TRUE);

  // Send an invalidation message to the client.
  WinPostMsg (h_wndFrame, WM_VRNENABLED, nil, nil );
  
  InitializeAppWindow := ES_NO_ERROR;
end; {InitializeAppWindow}

//........................................................................
function ClientWndProc(h_wnd: cardinal; msg: cardinal; mp1,mp2: pointer): pointer; cdecl; export;
//........................................................................
var
  _pointl: POINTL;         // Point to offset from Desktop
  _swp   : SWP;            // Window position
  h_rgn  : HRGN;           // Region handle
  rcls   : array [0..50-1] of RECTL;       // Rectangle coordinates
  rgnCtl : RGNRECT;         // Processing control structure
  SetupBlitter: TSETUP_BLITTER;   // structure for DiveSetupBlitter
  sizl   : SIZEL;
  
begin

  ClientWndProc:=nil;

  case (msg) of
  
  WM_CREATE: begin
       sizl.cx := 0;
       sizl.cy := 0;
       h_dcClientHDC := WinOpenWindowDC (h_wnd);
       h_psMainHPS := GpiCreatePS (h_ab, h_dcClientHDC, sizl,
                           PU_PELS or GPIF_DEFAULT or GPIT_MICRO or GPIA_ASSOC);

       // Code differs from game1.cpp starting here.

       // Set the palette to the default 16 palette

       pal2Image.Default16         ;
       pal2Image.SetFlag           (PC_RESERVED);
       pal2Image.Convert           (PAL_FMT_OS2);
       pal2Image.InitSystemPalette (h_ab, h_wnd, h_dcClientHDC, h_psMainHPS);
       pal2Image.SetAsDiveSource   (h_Dive);

       pal2Real.LoadActualPalette    (h_psMainHPS);
       pal2Real.SetAsDiveDestination (h_Dive);

       // Alternatively, if you don't need to look at the specific colors
       //   of the real palette, the above pal2Real code can be replaced
       //   with the single line:
       // DiveSetDestinationPalette (h_Dive, 0, 256, nil {0} );

       end;

  WM_DESTROY: begin
       pal2Image.UninitSystemPalette;
       if (h_psMainHPS <> NULLHANDLE) then
       begin
       GpiDestroyPS (h_psMainHPS);
       end;
       end;

{$IFDEF ADJUST_PALETTE_ON_FOCUS}

  WM_ACTIVATE: begin
       bAppIsActive := (SHORT1FROMMP(mp1)>0);

       if (bAppIsActive) then
         begin
         // Set the palette like you want it.
         pal2Image.RestoreSystemPalette;

         // Repaint the image
         WinInvalidateRect (h_wndClient, nil, TRUE);
         end
       else
         begin
         // Release the palette
         pal2Image.SuspendSystemPalette;
         end;
       ClientWndProc:=nil;
       exit;
       end;

{$ENDIF ADJUST_PALETTE_ON_FOCUS}

   WM_PAINT: begin
       // Notice here that the HPS created during the WM_CREATE message
       //   is used for both WinBeginPaint() and WinEndPaint().  This saves
       //   resources since WinBeginPaint() doesn't have to create a new HPS.

       // h_psMainHPS :=  // ???
       WinBeginPaint (h_wnd, h_psMainHPS, nil);

       // blit Dive buffer to screen.
       DiveBlitImage (h_Dive,
                      ulDiveBufferNumber,
                      DIVE_BUFFER_SCREEN );

       WinEndPaint (h_psMainHPS);
       ClientWndProc:=nil;
       exit;
       end;

   WM_COMMAND: begin
       case (SHORT1FROMMP(mp1)) of
       
         IDM_QUIT: begin
           WinPostMsg(h_wndClient, WM_CLOSE, nil, nil);
           ClientWndProc:=nil;
           exit;
           end;
         end; {case SHORT1FROMMP}
       end;

   WM_REALIZEPALETTE: begin
       // This tells DIVE that the physical palette may have changed.
       DiveSetDestinationPalette (h_Dive, 0, 256, nil );
       end;

   WM_VRNDISABLED: begin
       DiveSetupBlitter (h_Dive, nil);
       end;

   WM_VRNENABLED: begin
       if ( h_psMainHPS = 0 ) then
       begin
          // break;
          exit;
       end;
       h_rgn := GpiCreateRegion ( h_psMainHPS, 0, nil );
       if ( h_rgn> 0 ) then
          begin
          // NOTE: If mp1 is zero, then this was just a move message.
          // Illustrate the visible region on a WM_VRNENABLE.
          
          WinQueryVisibleRegion ( h_wnd, h_rgn );
          rgnCtl.ircStart     := 0;
          rgnCtl.crc          := 50;
          rgnCtl.ulDirection  := 1;

          // Get the all ORed rectangles
          if ( GpiQueryRegionRects ( h_psMainHPS, h_rgn, nil, rgnCtl, rcls[0]) ) then
             begin
             // Now find the window position and size, relative to parent.
             WinQueryWindowPos (h_wndClient, _swp );

             // Convert the point to offset from desktop lower left.
             _pointl.x := _swp.x;
             _pointl.y := _swp.y;
             WinMapWindowPoints ( h_wndFrame, HWND_DESKTOP, _pointl, 1 );

             // Tell DIVE about the new settings.
             SetupBlitter.ulStructLen := sizeof ( TSETUP_BLITTER );
             SetupBlitter.fccSrcColorFormat := FOURCC_LUT8;
             SetupBlitter.ulSrcWidth   := ulIMAGE_WIDTH;
             SetupBlitter.ulSrcHeight  := ulIMAGE_HEIGHT;
             SetupBlitter.ulSrcPosX    := 0;
             SetupBlitter.ulSrcPosY    := 0;
             SetupBlitter.fInvert      := 1; // TRUE;
             SetupBlitter.ulDitherType := 1;

             SetupBlitter.fccDstColorFormat := FOURCC_SCRN;
             SetupBlitter.ulDstWidth        := _swp.cx;
             SetupBlitter.ulDstHeight       := _swp.cy;
             SetupBlitter.lDstPosX          := 0;
             SetupBlitter.lDstPosY          := 0;
             SetupBlitter.lScreenPosX       := _pointl.x;
             SetupBlitter.lScreenPosY       := _pointl.y;
             SetupBlitter.ulNumDstRects     := rgnCtl.crcReturned;
             SetupBlitter.pVisDstRects      := rcls;
             DiveSetupBlitter (h_Dive, @SetupBlitter);
             end
          else
             DiveSetupBlitter (h_Dive, nil);

          GpiDestroyRegion (h_psMainHPS, h_rgn);
          end
       end;  {WM_VRNENABLED}
       
  end; // case switch (msg)

  ClientWndProc := WinDefWindowProc(h_wnd, msg, mp1, mp2);
end; {ClientWndProc}

//........................................................................
// int main
//........................................................................
var
  h_mq: HMQ;
  q_msg: QMSG;
  flFrameFlags: ULONG;

begin
  { some inits }
  fillchar(DiveCaps,sizeof(DiveCaps),0);
  fillchar(fccFormats,sizeof(fccFormats),0);
  { some more inits, needed !!! }
  // Palette objects
  pal2image := OS2Palette.OS2PALCreate;
  pal2Real  := OS2Palette.OS2PALCreate;
  
  { go }
  h_ab := WinInitialize (0);
  h_mq := WinCreateMsgQueue (h_ab, 0);

  WinRegisterClass (h_ab, szClientClass, @ClientWndProc, CS_SIZEREDRAW, 0);

  if (InitializeDive = NO_ERROR) then
    begin
    // Ready variables for main window creation.
    WinLoadString (h_ab, 0, ID_APPMAIN, sizeof(szTitle), szTitle);
    
    flFrameFlags := FCF_TITLEBAR      or FCF_DLGBORDER  or  FCF_MINBUTTON or 
                   FCF_SHELLPOSITION or FCF_TASKLIST   or  FCF_ICON      or 
                   FCF_SYSMENU       or FCF_MENU;

    // Create the main window
    h_wndFrame := WinCreateStdWindow (HWND_DESKTOP, WS_VISIBLE,
                                    @flFrameFlags, szClientClass, szTitle,
                                    0, 0, ID_APPMAIN, @h_wndClient);

    if (InitializeAppWindow = ES_ERROR) then
      begin
      WinPostMsg(h_wndClient, WM_QUIT, nil, nil);
      end;
    DrawTestPcx;

    // Size the window here.
    Snap1_1;
    CenterWindow;

    WinShowWindow (h_wndFrame, TRUE);
    WinSetActiveWindow (HWND_DESKTOP, h_wndFrame);

    // Process messages while there are some.
    while (WinGetMsg (h_ab, q_msg, 0, 0, 0)) do
        WinDispatchMsg (h_ab, q_msg);

    WinSetVisibleRegionNotify (h_wndClient, FALSE);
    end
    else begin
      writeln('InitializeDive <> NO_ERROR');
    end;

  if (bDiveHaveBuffer) then
    begin
    DiveFreeImageBuffer (h_Dive, ulDiveBufferNumber);
    ulDiveBufferNumber := 0;
    bDiveHaveBuffer := FALSE;
    end;

  if (pcnvMainCanvas <> nil) then
    begin
    pcnvMainCanvas^.Delete;
    pcnvMainCanvas := nil;
    end;

  if (h_Dive <> NULLHANDLE) then DiveClose (h_Dive);

  WinDestroyWindow (h_wndFrame);

  WinDestroyMsgQueue (h_mq);
  WinTerminate (h_ab);
  
  halt (0);
end.

