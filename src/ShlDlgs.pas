//
// https://github.com/showcode
//

unit ShlDlgs;

interface

uses
  Windows, SysUtils, Controls;

function SelectDirectory(const Prompt: string; const Root: string; var Directory: string; ParentWindow: TWinControl): Boolean;

implementation

uses
  Forms, ShlObj, ActiveX;

function SelectDirectory(const Prompt: string; const Root: string; var Directory: string; ParentWindow: TWinControl): Boolean;

  function BrowseCallbackProc(hWnd: HWND; uMsg: UINT; lParam, lpData: LPARAM): Integer; stdcall;
  var
    EnableButton: Boolean;
    Path: array[0..MAX_PATH - 1] of Char;
  begin
    Result := 0;
    case uMsg of
      BFFM_INITIALIZED:
      begin
        SendMessage(hWnd, BFFM_SETSELECTION, Ord(True), lpData);
      end;

      BFFM_SELCHANGED:
      begin
        if lParam <> 0 then
        begin
          Path[0] := #0;
          EnableButton := SHGetPathFromIDList(PItemIDList(lParam), Path);
          SendMessage(hwnd, BFFM_ENABLEOK, 0, Integer(EnableButton));
          SendMessage(hwnd, BFFM_SETSTATUSTEXT, 0, Integer(@Path));
        end;
      end;
    end;//case
  end;

const
  BIF_NEWDIALOGSTYLE = $00000040;
var
  WindowList: Pointer;
  BrowseInfo: TBrowseInfo;
  Buffer: PChar;
  RootItemIDList, ItemIDList: PItemIDList;
  ShellMalloc: IMalloc;
  IDesktopFolder: IShellFolder;
  Eaten, Flags: Cardinal;
begin
  Result := False;
  FillChar(BrowseInfo, SizeOf(BrowseInfo), 0);
  if (ShGetMalloc(ShellMalloc) = S_OK) and (ShellMalloc <> nil) then
  begin
    Buffer := ShellMalloc.Alloc(MAX_PATH);
    try
      RootItemIDList := nil;
      if Root <> '' then
      begin
        SHGetDesktopFolder(IDesktopFolder);
        IDesktopFolder.ParseDisplayName(Application.Handle, nil,
          StringToOleStr(Root), Eaten, RootItemIDList, Flags);
      end;

      with BrowseInfo do
      begin
        if ParentWindow <> nil then
          hwndOwner := ParentWindow.Handle
        else
          hwndOwner := Application.Handle;
        pidlRoot := RootItemIDList;
        pszDisplayName := Buffer;
        lpszTitle := PChar(Prompt);
        lpfn := @BrowseCallbackProc;
        lParam := Integer(PChar(Directory));
        ulFlags := BIF_RETURNONLYFSDIRS or BIF_NEWDIALOGSTYLE;
      end;

      WindowList := DisableTaskWindows(0);
      try
        ItemIDList := ShBrowseForFolder(BrowseInfo);
      finally
        EnableTaskWindows(WindowList);
      end;

      Result := ItemIDList <> nil;
      if Result then
      begin
        ShGetPathFromIDList(ItemIDList, Buffer);
        ShellMalloc.Free(ItemIDList);
        Directory := Buffer;
      end;
    finally
      ShellMalloc.Free(Buffer);
    end;
  end;
end;

end.
