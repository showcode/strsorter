//
// https://github.com/showcode
//

unit MainFrm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ActnList, Spin, Buttons, ComCtrls;

type
  TMainForm = class(TForm)
    btnStartStop: TButton;
    ActionList: TActionList;
    acStart: TAction;
    acStop: TAction;
    sbSelectSource: TSpeedButton;
    sbSelectDestination: TSpeedButton;
    Label1: TLabel;
    Label2: TLabel;
    Label4: TLabel;
    edtMaxLineCount: TSpinEdit;
    edtSource: TEdit;
    edtDest: TEdit;
    gbxOptions: TGroupBox;
    gbxProgress: TGroupBox;
    ProgressBar: TProgressBar;
    lblStatus: TLabel;
    sbResetMaxCount: TSpeedButton;
    procedure acStartExecute(Sender: TObject);
    procedure acStopExecute(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure sbSelectSourceClick(Sender: TObject);
    procedure sbSelectDestinationClick(Sender: TObject);
    procedure sbResetMaxCountClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    procedure WorkerTerminate(Sender: TObject);
    procedure LockUI(Lock: Boolean);
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

uses
  StrUtils, Math, TimeSpan,
  ShlDlgs, AppUtils, BTree;

resourcestring
  StrSelectSourceDir = 'Директория с файлами-источниками';
  StrIndexing = 'Индексирование: ';
  StrWrite = 'Запись: ';
  StrReady = 'Готово';
  StrSorting = 'Сортировка: ';
  StrMerge_uu = 'Слияние: %u из %u';
  StrSplit_uu = 'Разбивка: %u из %u';
  StrVeryLongString = 'A very long string: ';

const
  MAX_USAGE: Integer = 500 * 1024 * 1024; // memory usage param
  LineEnd: AnsiString = #$D#$A;

type

  TWorkThread = class(TThread)
  private type
    PItem = ^TItem;
    TItem = packed record
      Data: TBytes;
    end;
  private
    FFiles: TStringList;
    FCompareList: TBTree;
    FSourcePath: string;
    FDestFileName: string;
    FTempFileNameFmt: string;
    FTempFileCount: Integer;
    FMaxLineCount: Integer;
    FTotalLines: Integer;
    FWorkTime: Cardinal;
  protected
    function StrComparer(const Str1, Str2: TBytes): Integer;
    function ItemComparer(Value1, Value2: Pointer): Integer;
    function AddFile(const FileName: string): Integer;
    function AddItem(const Str1: TBytes): Boolean;
    procedure FreeItems;
    procedure ScanPath(const Path: string);
    procedure Execute; override;
    procedure Sort;
    procedure PourList;
    procedure Merge;
    procedure Split;
  public
    constructor Create;
    destructor Destroy; override;
    property SourcePath: string read FSourcePath write FSourcePath;
    property DestFile: string read FDestFileName write FDestFileName;
    property MaxLineCount: Integer read FMaxLineCount write FMaxLineCount;
    property IndexTime: Cardinal read FWorkTime;
    property TotalLines: Integer read FTotalLines;
    property Tree: TBTree read FCompareList;
  end;

var
  Worker: TWorkThread = nil;

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
begin
  edtSource.Text := ExpandFileName('.\');
  edtDest.Text := ExpandFileName('.\out.txt');
//    edtSource.Text := ExpandFileName('..\FILES\');
//    edtDest.Text := ExpandFileName('..\out.txt');
  edtMaxLineCount.MinValue := 1;
  edtMaxLineCount.MaxValue := MaxInt;
  edtMaxLineCount.Value := edtMaxLineCount.MaxValue;
  lblStatus.Caption := '';
end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if Assigned(Worker) then
    Worker.Terminate;
end;

procedure TMainForm.LockUI(Lock: Boolean);
begin
  edtSource.Enabled := not Lock;
  edtDest.Enabled := not Lock;
  edtMaxLineCount.Enabled := not Lock;
  sbSelectSource.Enabled := not Lock;
  sbSelectDestination.Enabled := not Lock;
  sbResetMaxCount.Enabled := not Lock;
end;

procedure TMainForm.sbSelectSourceClick(Sender: TObject);
var
  SourceDir: string;
begin
  SourceDir := edtSource.Text;
  if SelectDirectory(StrSelectSourceDir, '', SourceDir, Self) then
    edtSource.Text := IncludeTrailingPathDelimiter(SourceDir);
end;

procedure TMainForm.sbResetMaxCountClick(Sender: TObject);
begin
  edtMaxLineCount.Value := edtMaxLineCount.MaxValue;
end;

procedure TMainForm.sbSelectDestinationClick(Sender: TObject);
begin
  with TSaveDialog.Create(Self) do
    try
      DefaultExt := '.txt';
      Filter := 'Text Files (*.txt)|*.txt|Any Files (*.*)|*.*';
      FileName := edtDest.Text;
      if Execute(Self.Handle) then
        edtDest.Text := FileName;
    finally
      Free;
    end;
end;

procedure TMainForm.acStartExecute(Sender: TObject);
var
  SourcePath, DestFileName: string;
begin
  LockUI(True);
  try
    SourcePath := IncludeTrailingPathDelimiter(ExpandFileName(edtSource.Text));
    DestFileName := ExpandFileName(edtDest.Text);

    Worker := TWorkThread.Create;
    Worker.SourcePath := SourcePath;
    Worker.DestFile := DestFileName;
    Worker.MaxLineCount := edtMaxLineCount.Value;
    Worker.OnTerminate := WorkerTerminate;
    Worker.Start;
    btnStartStop.Action := acStop;
  except
    LockUI(False);
    raise;
  end;
end;

procedure TMainForm.acStopExecute(Sender: TObject);
begin
  Worker.Terminate;
end;

procedure TMainForm.WorkerTerminate(Sender: TObject);
var
  Time: TTimeSpan;
  STime: string;
begin
  ProgressBar.Style := pbstNormal;
  ProgressBar.Position := 0;
  Time := TTimeSpan.FromMilliseconds(Worker.IndexTime);
  STime := Format(' (%.2u:%.2u:%.2u)', [Time.Hours, Time.Minutes, Time.Seconds]);
  lblStatus.Caption := IfThen(not Worker.Terminated, StrReady + STime);

  Worker := nil;
  btnStartStop.Action := acStart;
  LockUI(False);
end;

{ TWorkThread }

constructor TWorkThread.Create;
begin
  inherited Create(True);
  FFiles := TStringList.Create;
  FCompareList := TBTree.Create;
  FCompareList.Comparer := ItemComparer;
  FTotalLines := 0;
  FTempFileCount := 0;
  FreeOnTerminate := True;
end;

destructor TWorkThread.Destroy;
var
  I: Integer;
begin
  if Assigned(FFiles) then
    for I  := 0 to FFiles.Count - 1 do
      FFiles[I] := '';
  FFiles.Free;

  FreeItems;
  FCompareList.Free;

  while FTempFileCount > 0 do
  begin
    Dec(FTempFileCount);
    DeleteFile(Format(FTempFileNameFmt, [FTempFileCount]));
  end;

  inherited;
end;

procedure TWorkThread.FreeItems;
var
  Item, Temp: PItem;
begin
  if Assigned(FCompareList) then
  begin
    for Item in FCompareList do
    begin
      Temp := Item;
      Temp.Data := nil;
      Dispose(Temp);
    end;
    FCompareList.Clear;
  end;
end;

function TWorkThread.AddFile(const FileName: string): Integer;
begin
  Result := FFiles.Add(FileName);
end;

function TWorkThread.ItemComparer(Value1, Value2: Pointer): Integer;
var
  BytesToCompare: Integer;
  Item1, Item2: PItem;
begin
  Item1 := Value1;
  Item2 := Value2;
  BytesToCompare := Min(Length(Item1.Data), Length(Item2.Data));
  Result := StrLComp(PAnsiChar(Item1.Data), PAnsiChar(Item2.Data), BytesToCompare);
  if Result = 0 then
    Result := Length(Item1.Data) - Length(Item2.Data);
end;

function TWorkThread.StrComparer(const Str1, Str2: TBytes): Integer;
var
  BytesToCompare: Integer;
begin
  BytesToCompare := Min(Length(Str1), Length(Str2));
  Result := StrLComp(PAnsiChar(Str1), PAnsiChar(Str2), BytesToCompare);
  if Result = 0 then
    Result := Length(Str1) - Length(Str2);
end;

function TWorkThread.AddItem(const Str1: TBytes): Boolean;
var
  Item: PItem;
begin
  New(Item);
  Item.Data := Str1;
  Result := FCompareList.Add(Item);
  if not Result then
    Dispose(Item);
end;

procedure TWorkThread.Execute;
var
  ErrStr: string;
begin
  FTempFileNameFmt := ExtractFilePath(FDestFileName) + 'temp%u.tmp';
  try
    ScanPath(FSourcePath);
    if Terminated or (FFiles.Count = 0) then
      Exit;

    FWorkTime := GetTickCount;

    Sort;
    if Terminated then
      Exit;

    Merge;
    if Terminated then
      Exit;

    Split;
    if Terminated then
      Exit;

    FWorkTime := GetTickCount - FWorkTime;
  except
    on E: Exception do
    begin
      ErrStr := E.Message;
      Synchronize(procedure begin MessageDlg(ErrStr, mtError, [mbOK], 0) end);
    end;
  end;
end;

procedure TWorkThread.Merge;
var
  SrcFileName1, SrcFileName2, MergeFileName: string;
  Reader1, Reader2: TTextFileReader;
  I: Integer;
  Str1, Str2: TBytes;
  Comp: Integer;
  Writer: TTextFileWriter;

  procedure WriteLine(const Bytes: TBytes);
  begin
    Writer.Write(Pointer(Bytes)^, Length(Bytes));
    Writer.Write(Pointer(LineEnd)^, Length(LineEnd));
    Inc(FTotalLines);
  end;

begin
  Synchronize(procedure begin
    MainForm.ProgressBar.Style := pbstNormal;
    MainForm.ProgressBar.Position := 0;
    MainForm.ProgressBar.Min := 0;
    MainForm.ProgressBar.Max := Ceil(Math.Log2(FTempFileCount));
    MainForm.ProgressBar.Step := 1;
    MainForm.lblStatus.Caption := Format(StrMerge_uu,
      [MainForm.ProgressBar.Position + 1, MainForm.ProgressBar.Max]);
  end);

  MergeFileName := ExtractFilePath(FTempFileNameFmt) + 'merge';
  while FTempFileCount > 1 do
  begin
    FTotalLines := 0;
    for I := 0 to FTempFileCount div 2 - 1 do
    begin
      SrcFileName1 := Format(FTempFileNameFmt, [I * 2]);
      SrcFileName2 := Format(FTempFileNameFmt, [(I * 2) + 1]);

      Reader1 := TTextFileReader.Create(SrcFileName1);
      try
        Reader2 := TTextFileReader.Create(SrcFileName2);
        try
          Writer := TTextFileWriter.Create(MergeFileName);
          try
            if not Reader1.EndOfFile and not Reader2.EndOfFile then
            begin
              Str1 := Reader1.ReadLine;
              Str2 := Reader2.ReadLine;
              while True do
              begin
                if Terminated then
                  Exit;
                Comp := StrComparer(Str1, Str2);
                if Comp < 0 then
                begin
                  WriteLine(Str1);
                  if Reader1.EndOfFile then
                  begin
                    WriteLine(Str2);
                    Break;
                  end;
                  Str1 := Reader1.ReadLine;
                end
                else if Comp > 0 then
                begin
                  WriteLine(Str2);
                  if Reader2.EndOfFile then
                  begin
                    WriteLine(Str1);
                    Break;
                  end;
                  Str2 := Reader2.ReadLine;
                end
                else
                begin
                  WriteLine(Str1);
                  if Reader1.EndOfFile or Reader2.EndOfFile then
                    Break;
                  Str1 := Reader1.ReadLine;
                  Str2 := Reader2.ReadLine;
                end;
              end;//while
            end;

            while not Reader1.EndOfFile do
            begin
              Str1 := Reader1.ReadLine;
              WriteLine(Str1);
            end;

            while not Reader2.EndOfFile do
            begin
              Str2 := Reader2.ReadLine;
              WriteLine(Str2);
            end;

          finally
            Writer.Free;
          end;
        finally
          Reader2.Free;
        end;
      finally
        Reader1.Free;
      end;

      if not DeleteFile(SrcFileName1) then
        RaiseLastOSError;
      if not DeleteFile(SrcFileName2) then
        RaiseLastOSError;
      if not RenameFile(MergeFileName, Format(FTempFileNameFmt, [I])) then
        RaiseLastOSError;
    end;//for

    if (FTempFileCount mod 2) <> 0 then
    begin
      if not RenameFile(
        Format(FTempFileNameFmt, [FTempFileCount - 1]),
        Format(FTempFileNameFmt, [(FTempFileCount div 2)])) then
        RaiseLastOSError;
    end;
    FTempFileCount := (FTempFileCount div 2) + (FTempFileCount mod 2);
    Synchronize(procedure begin
      MainForm.ProgressBar.StepIt;
      MainForm.lblStatus.Caption := Format(StrMerge_uu,
        [MainForm.ProgressBar.Position + 1, MainForm.ProgressBar.Max]);
    end);
  end;//while
end;

procedure TWorkThread.Sort;
var
  Reader: TTextFileReader;
  Bytes: TBytes;
  Usage: Integer;
  Progress, Step: Double;
  Steps: Integer;
  FileName: string;
begin
  Usage := 0;
  FreeItems;
  for FileName in FFiles do
  begin
    Synchronize(procedure begin
      MainForm.ProgressBar.Style := pbstNormal;
      MainForm.ProgressBar.Position := 0;
      MainForm.ProgressBar.Min := 0;
      MainForm.ProgressBar.Max := 100;
      MainForm.ProgressBar.Step := 1;
      MainForm.lblStatus.Caption := StrSorting + ExtractFileName(FileName);
    end);

    Reader := TTextFileReader.Create(FileName);
    try
      Progress := 0;
      Step := Reader.Size / 100;
      while not Reader.EndOfFile and not Terminated do
      begin
        Bytes := Reader.ReadLine;

        if Length(Bytes) > MAX_USAGE div 3 then
          raise Exception.Create(StrVeryLongString + IntToStr(Length(Bytes)));

        if (Length(Bytes) > 0) and AddItem(Bytes) then
        begin
          Inc(Usage, Length(Bytes) + SizeOf(Integer) + SizeOf(TItem));
          if Usage + (FCompareList.NodeCount * SizeOf(TBNode)) > MAX_USAGE then
          begin
            PourList;
            FreeItems;
            Usage := 0;
          end;
        end;

        Progress := Progress + Length(Bytes) + 2;
        if Progress > Step then
        begin
          Steps := Trunc(Progress / Step);
          Synchronize(procedure begin
            MainForm.ProgressBar.StepBy(Steps);
          end);
          Progress := Progress - (Steps * Step);
        end;
      end;//while
    finally
      Reader.Free;
    end;
  end;//for

  if (FCompareList.NodeCount > 0) and not Terminated then
  begin
    PourList;
    FreeItems;
  end;
end;

procedure TWorkThread.Split;
var
  Err: Cardinal;
  Reader: TTextFileReader;
  Writer: TTextFileWriter;
  PartFileNameFmt: string;
  PartIndex, LineWritten: Integer;
  Bytes: TBytes;
  ReadFileName: string;
begin
  if FTempFileCount > 0 then
  begin
    ReadFileName := Format(FTempFileNameFmt, [0]);
    if FTotalLines <= FMaxLineCount then
    begin
      if not DeleteFile(FDestFileName) then
      begin
        Err := GetLastError;
        if Err <> ERROR_FILE_NOT_FOUND then
          RaiseLastOSError(Err);
      end;
      if not RenameFile(ReadFileName, FDestFileName) then
        RaiseLastOSError;
    end
    else
    begin
      Synchronize(procedure begin
        MainForm.ProgressBar.Style := pbstNormal;
        MainForm.ProgressBar.Position := 0;
        MainForm.ProgressBar.Min := 0;
        MainForm.ProgressBar.Max := Ceil(FTotalLines / FMaxLineCount);
        MainForm.ProgressBar.Step := 1;
        MainForm.lblStatus.Caption := Format(StrSplit_uu,
          [MainForm.ProgressBar.Position + 1, MainForm.ProgressBar.Max]);
      end);

      PartFileNameFmt := ChangeFileExt(FDestFileName, '') + '-%u' + ExtractFileExt(FDestFileName);
      PartIndex := 0;

      Reader := TTextFileReader.Create(ReadFileName);
      try
        FDestFileName := Format(PartFileNameFmt, [PartIndex]);
        Inc(PartIndex);
        Writer := TTextFileWriter.Create(FDestFileName);
        try
          LineWritten := 0;
          while not Reader.EndOfFile and not Terminated do
          begin
            Bytes := Reader.ReadLine;
            Writer.Write(Pointer(Bytes)^, Length(Bytes));
            Writer.Write(Pointer(LineEnd)^, Length(LineEnd));
            Inc(LineWritten);
            if LineWritten >= FMaxLineCount then
            begin
              FreeAndNil(Writer);
              Synchronize(procedure begin
                MainForm.ProgressBar.StepIt;
                MainForm.lblStatus.Caption := Format(StrSplit_uu,
                  [MainForm.ProgressBar.Position + 1, MainForm.ProgressBar.Max]);
              end);
              FDestFileName := Format(PartFileNameFmt, [PartIndex]);
              Inc(PartIndex);
              Writer := TTextFileWriter.Create(FDestFileName);
              LineWritten := 0;
            end;
          end;
        finally
          Writer.Free;
        end;
      finally
        Reader.Free;
      end;

      if not DeleteFile(ReadFileName) then
        RaiseLastOSError;
    end;
  end;
end;

procedure TWorkThread.PourList;
var
  Item: PItem;
  FileName: string;
  Writer: TTextFileWriter;
  Bytes: TBytes;
begin
  FileName := Format(FTempFileNameFmt, [FTempFileCount]);
  Inc(FTempFileCount);

  FTotalLines := 0;
  Writer := TTextFileWriter.Create(FileName);
  try
    for Item in FCompareList do
    begin
      if Terminated then
        Break;
      Bytes := Item^.Data;
      Writer.Write(Pointer(Bytes)^, Length(Bytes));
      Writer.Write(Pointer(LineEnd)^, Length(LineEnd));
      Inc(FTotalLines);
    end;
    Writer.Flush;
  finally
    Writer.Free;
  end;
end;


procedure TWorkThread.ScanPath(const Path: string);
var
  SR: TSearchRec;
begin
  Synchronize(procedure begin
    MainForm.ProgressBar.Style := pbstMarquee;
    MainForm.lblStatus.Caption := StrIndexing;
  end);
  if FindFirst(Path + '*.*', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if (SR.Attr and faDirectory) <> 0 then
        begin
          if (SR.Name <> '.') and (SR.Name <> '..') then
          begin
            ScanPath(Path + SR.Name + PathDelim);
          end;
        end
        else
        begin
          FFiles.Add(Path + SR.Name)
        end;
      until Terminated or (FindNext(SR) <> 0);
    finally
      FindClose(SR);
    end;
  end;
end;

end.

