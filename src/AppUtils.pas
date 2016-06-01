//
// https://github.com/showcode
//

unit AppUtils;

interface

uses
  Windows, SysUtils, Classes, Contnrs;

type
  TTextFileReader = class
  private
  const
    BuffSize = 256 * 1024;
  private
    FFileName: string;
    FHandle: THandle;
    FSize: Int64;
    FBuff: TBytes;
    FCapacity: Integer;
    FOffset: Int64;
    FPointer: Integer;
    function GetPosition: Int64;
    procedure CheckOSError(RetVal: Boolean);
  public
    constructor Create(const AFileName: string);
    destructor Destroy; override;
    function ReadLine: TBytes;
    function EndOfFile: Boolean;
    property Position: Int64 read GetPosition;
    property Size: Int64 read FSize;
  end;

  TTextFileWriter = class
  private
  const
    BuffSize = 256 * 1024;
  private
    FFileName: string;
    FHandle: THandle;
    FSize: Int64;
    FBuff: TBytes;
    FPointer: Integer;
    procedure CheckOSError(RetVal: Boolean);
  public
    constructor Create(const AFileName: string);
    destructor Destroy; override;
    procedure Write(const Data; Count: Integer); overload;
    procedure Write(const Bytes: TBytes); overload;
    procedure Flush;
    property Size: Int64 read FSize;
  end;

function GetFileSizeEx(hFile: THandle; var lpFileSize: TLargeInteger): BOOL; stdcall;
function SetFilePointerEx(hFile: THandle; const liDistanceToMove: TLargeInteger; var lpNewFilePointer: TLargeInteger;
  dwMoveMethod: DWORD): BOOL; stdcall;

implementation

function GetFileSizeEx; external kernel32 Name 'GetFileSizeEx';
function SetFilePointerEx; external kernel32 Name 'SetFilePointerEx';

{ TTextFileReader }

constructor TTextFileReader.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := AFileName;
  FCapacity := 0;
  FOffset := 0;
  FPointer := 0;
  FHandle := CreateFile(PChar(FFileName), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN, 0);
  CheckOSError(FHandle <> INVALID_HANDLE_VALUE);
  CheckOSError(GetFileSizeEx(FHandle, FSize));
  SetLength(FBuff, BuffSize);
end;

destructor TTextFileReader.Destroy;
begin
  CloseHandle(FHandle);
  SetLength(FBuff, 0);
  inherited;
end;

function TTextFileReader.GetPosition: Int64;
begin
  Result := FOffset + Int64(FPointer);
end;

function TTextFileReader.EndOfFile: Boolean;
begin
  Result := (Position >= FSize);
end;

procedure TTextFileReader.CheckOSError(RetVal: Boolean);
begin
  if not RetVal then
    try
      RaiseLastOSError;
    except
      on E: Exception do
      begin
        E.Message := E.Message + sLineBreak + FFileName;
        raise;
      end;
    end;
end;

function TTextFileReader.ReadLine: TBytes;
var
  Start, Len: Integer;
  Count: Integer;
  LineBreakLen: Integer;
begin
  Result := nil;

  if EndOfFile then
    Exit;

  // наполняем буффер, если он пустой
  if FPointer = FCapacity then
  begin
    Inc(FOffset, FCapacity);
    FPointer := 0;
    CheckOSError(ReadFile(FHandle, FBuff[0], Length(FBuff), Cardinal(FCapacity), nil));
    if FCapacity = 0 then
      Exit;
  end;

  while True do
  begin
    Start := FPointer;
    while FPointer < FCapacity - 1 do
    begin
      if FBuff[FPointer] = $D then
      begin
        LineBreakLen := 1;
        if FBuff[FPointer + 1] = $A then
          LineBreakLen := 2;
      end
      else if FBuff[FPointer] = $A then
        LineBreakLen := 1
      else
        LineBreakLen := 0;

      if LineBreakLen > 0 then
      begin
        // нашли разделитель строк, дополняем результат
        // просканированными байтами и выходим
        Count := FPointer - Start;
        if Count > 0 then
        begin
          Len := Length(Result);
          SetLength(Result, Len + Count);
          Move(FBuff[Start], Result[Len], Count);
        end;
        Inc(FPointer, LineBreakLen); // пропускаем разделитель строк
        Exit;
      end;
      Inc(FPointer);
    end;//while

    // дополняем результат просканированными байтами
    Count := FPointer - Start; // сколько байт просканировали
    if Count > 0 then
    begin
      Len := Length(Result);
      SetLength(Result, Len + Count);
      Move(FBuff[Start], Result[Len], Count);
    end;
    // сдвигаем непросканированные байты в начало буффера
    Inc(FOffset, FPointer); // корректируем файловый указатель
    Count := FCapacity - FPointer; // сколько байт в буффере
    if Count > 0 then
      Move(FBuff[FPointer], FBuff[0], Count);
    FPointer := 0;
    FCapacity := Count;
    // дочитываем буффер
    Count := Length(FBuff) - FCapacity; // сколько в буффере места
    CheckOSError(ReadFile(FHandle, FBuff[FCapacity], Count, Cardinal(Count), nil));
    Inc(FCapacity, Count);

    // если в буффере меньше байт чем в разделителе строк
    if FCapacity < 2 then
    begin
      if (FCapacity = 1) and ((FBuff[0] = $D) or (FBuff[0] = $A)) then
      begin
        Dec(FCapacity, 1);
        Inc(FPointer, 1);
      end;
      // дополняем результат остатком из буффера и выходим
      Count := FCapacity;
      if Count > 0 then
      begin
        Len := Length(Result);
        SetLength(Result, Len + Count);
        Move(FBuff[0], Result[Len], Count);
      end;
      Inc(FPointer, Count);
      Exit;
    end;//if

  end;//while
end;

{ TTextFileWriter }

constructor TTextFileWriter.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := AFileName;
  FPointer := 0;
  FSize := 0;
  FHandle := CreateFile(PChar(FFileName), GENERIC_WRITE, FILE_SHARE_READ, nil, CREATE_ALWAYS, 0, 0);
  CheckOSError(FHandle <> INVALID_HANDLE_VALUE);
  SetLength(FBuff, BuffSize);
end;

destructor TTextFileWriter.Destroy;
begin
  if FPointer > 0 then
    Flush;
  FBuff := nil;
  CloseHandle(FHandle);
  inherited;
end;

procedure TTextFileWriter.CheckOSError(RetVal: Boolean);
begin
  if not RetVal then
    try
      RaiseLastOSError;
    except
      on E: Exception do
      begin
        E.Message := E.Message + sLineBreak + FFileName;
        raise;
      end;
    end;
end;

procedure TTextFileWriter.Flush;
var
  BytesWritten: Cardinal;
begin
  CheckOSError(WriteFile(FHandle, Pointer(FBuff)^, FPointer, BytesWritten, nil));
  FPointer := 0;
end;

procedure TTextFileWriter.Write(const Data; Count: Integer);
begin
  if Count > BuffSize - FPointer then
    Flush;
  Move(Data, PByteArray(FBuff)[FPointer], Count);
  Inc(FPointer, Count);
  Inc(FSize, Count);
end;

procedure TTextFileWriter.Write(const Bytes: TBytes);
begin
  Write(Pointer(Bytes)^, Length(Bytes));
end;

end.
