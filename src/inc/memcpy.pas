procedure memcpy(dest, srce: PBYTE; count: longint);
// void* memcpy( void* dest, const void* src, size_t count );
var ii: longint;
begin
  for ii:=1 to count do begin
    dest^:=srce^;
    dest:=pointer(cardinal(dest)+1);
    srce:=pointer(cardinal(srce)+1);
  end;
end;

