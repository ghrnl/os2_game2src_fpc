//........................................................................
// USHORT APIENTRY PostError
function PostError(h_ab:HAB; h_wnd: HWND; usErrorID: USHORT): USHORT; cdecl; export;
//........................................................................

const
  MAX_BUFF =  128;  

var
  // static char        szMsgBuffer[MAX_BUFF];
  // both are OK here: // pChar; // array [0..MAX_BUFF-1] of char;
  // but where does its value come from ? from usErrorID I guess; OK, so we can ignore static here
  szMsgBuffer  : array [0..MAX_BUFF-1] of char; 
  
var
  h_wndSavedWin: HWND;
  usResult     : USHORT;
  
begin
  h_wndSavedWin := WinQueryCapture (HWND_DESKTOP);
  WinSetCapture (HWND_DESKTOP, NULLHANDLE);
  WinLoadString (h_ab, 0, usErrorID, MAX_BUFF, szMsgBuffer);
  usResult := WinMessageBox (HWND_DESKTOP,
                             h_wnd,
                             szMsgBuffer,
                             'Error!',
                             0,
                             MB_OK or MB_WARNING or MB_APPLMODAL);
  WinSetCapture (HWND_DESKTOP, h_wndSavedWin);
  PostError := usResult;
end; {PostError}

