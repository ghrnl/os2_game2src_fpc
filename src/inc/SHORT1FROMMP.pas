function SHORT1FROMMP(MP: pointer): word;
{ map C name SHORT1... on fpc name integer1... }
{ pmwin.pas:    function Integer1FromMP (MP: pointer): word; cdecl; }
begin
  SHORT1FROMMP:=integer1frommp(mp)
end;
