//
// https://github.com/showcode
//

unit BTree;

interface

uses
  Contnrs;

const
  ORDER = 7;
  CAPACITY = 2 * ORDER;

type

  PBNode = ^TBNode;

  TBNode = record
    ValueCount: Integer;
    Values: array [0..CAPACITY - 1] of Pointer;
    Childrens: array [0..CAPACITY] of PBNode;
  end;

  TValueComparer = function(Value1, Value2: Pointer): Integer of object;

  TBTree = class;

  TBTreeEnumerator = class
  private
    FTree: TBTree;
    FNode: PBNode;
    FIndex: Integer;
    FParentStack: TStack;
    FIndexStack: TStack;
  public
    constructor Create(ATree: TBTree);
    destructor Destroy; override;
    function GetCurrent: Pointer; inline;
    function MoveNext: Boolean;
    property Current: Pointer read GetCurrent;
  end;

  TBTree = class
  private
    FRoot: PBNode;
    FDeep: Integer;
    FNodeCount: Integer;
    FComparer: TValueComparer;
    function Insert(var Owner: PBNode; var Value: Pointer; var Lifting: Boolean): Boolean;
    procedure FreeNode(var Node: PBNode);
    function NewNode(Value: Pointer): PBNode;
    function HasChildrens(const Node: TBNode): Boolean;
    procedure SetComparer(const AComparer: TValueComparer);
  protected
    function DefaultComparer(Value1, Value2: Pointer): Integer; virtual;
  public
    constructor Create;
    destructor Destroy; override;
    function Add(Value: Pointer): Boolean;
    procedure Clear;
    function GetEnumerator: TBTreeEnumerator;
    property Root: PBNode read FRoot;
    property Deep: Integer read FDeep;
    property NodeCount: Integer read FNodeCount;
    property Comparer: TValueComparer read FComparer write SetComparer;
  end;

implementation

uses
  SysUtils, Windows;

{ TBTree }

constructor TBTree.Create;
begin
  inherited;
  FComparer := DefaultComparer;
end;

destructor TBTree.Destroy;
begin
  Clear;
  inherited;
end;

function TBTree.Add(Value: Pointer): Boolean;
var
  Lifting: Boolean;
  NewRoot, Node: PBNode;
begin
  Lifting := False;
  Node := FRoot;
  Result := Insert(Node, Value, Lifting);
  if Result then
  begin
    if Lifting then
    begin
      NewRoot := NewNode(Value);
      NewRoot.Childrens[0] := FRoot;
      NewRoot.Childrens[1] := Node;
      FRoot := NewRoot;
      Inc(FDeep);
    end
    else
    begin
      if not Assigned(FRoot) then
        Inc(FDeep);
      FRoot := Node;
    end;
  end;
end;

procedure TBTree.Clear;
begin
  FreeNode(FRoot);
  Assert(FNodeCount = 0, IntToStr(FNodeCount));
  FDeep := 0;
  FNodeCount := 0;
end;

function TBTree.DefaultComparer(Value1, Value2: Pointer): Integer;
begin
  if Integer(Value1) < Integer(Value2) then
    Result := -1
  else if Integer(Value1) > Integer(Value2) then
    Result := +1
  else
    Result := 0;
end;

function TBTree.NewNode(Value: Pointer): PBNode;
begin
  New(Result);
  ZeroMemory(Result, SizeOf(TBNode));
  Result.Values[0] := Value;
  Inc(Result.ValueCount);
  Inc(FNodeCount);
end;

procedure TBTree.FreeNode(var Node: PBNode);
var
  I: Integer;
begin
  if Assigned(Node) then
  begin
    for I := 0 to Node.ValueCount do
      FreeNode(Node.Childrens[I]);
    Dispose(Node);
    Node := nil;
    Dec(FNodeCount);
  end;
end;

procedure TBTree.SetComparer(const AComparer: TValueComparer);
begin
  FComparer := AComparer;
  if not Assigned(AComparer) then
    FComparer := DefaultComparer;
end;

function TBTree.GetEnumerator: TBTreeEnumerator;
begin
  Result := TBTreeEnumerator.Create(Self);
end;

function TBTree.HasChildrens(const Node: TBNode): Boolean;
begin
  Result := (Node.ValueCount > 0) and Assigned(Node.Childrens[0]);
end;

procedure MovePtrs(const Src; var Dest; Count: Cardinal);
var
  Bytes: Integer;
begin
  Bytes := Count * SizeOf(Pointer);
  Move(Src, Dest, Bytes);
  // очистка значений
  if Integer(@Src) < Integer(@Dest) then
  begin
    if Integer(@Src) + Bytes < Integer(@Dest) then
      ZeroMemory(@Src, Bytes)
    else
      ZeroMemory(@Src, Integer(@Dest) - Integer(@Src));
  end
  else if Integer(@Src) > Integer(@Dest) then
  begin
    if Integer(@Dest) + Bytes < Integer(@Src) then
      ZeroMemory(@Src, Bytes)
    else
      ZeroMemory(Pointer(Integer(@Dest) + Bytes), (Integer(@Dest) + Bytes) - Integer(@Src));
  end;
end;

function TBTree.Insert(var Owner: PBNode; var Value: Pointer; var Lifting: Boolean): Boolean;
var
  Left, Right, Index, Comp, N: Integer;
  SiblingNode, Node: PBNode;
begin
  Result := True;
  if not Assigned(Owner) then
  begin
    Owner := NewNode(Value);
    Exit;
  end;

  // ищем индекс элемента большего чем value

  //  Index:= 0;
  //  while Index < Owner.ValueCount do begin
  //    Comp:= FComparer(Value, Owner.Values[Index]);
  //    if Comp = 0 then begin
  //      Result:= False;
  //      //raise Exception.CreateFmt('Value ''%d'' already exists.', [Value]);
  //      Exit
  //    end;
  //    if Comp < 0 then
  //      Break;
  //    Inc(Index);
  //  end;

  // двоичный поиск
  Left := 0;
  Right := Owner.ValueCount - 1;
  while Left <= Right do
  begin
    Index := (Left + Right) div 2;
    Comp := FComparer(Owner.Values[Index], Value);
    if Comp < 0 then
      Left := Index + 1
    else if Comp > 0 then
      Right := Index - 1
    else
    begin
      Result := False;
      Exit;
    end;
  end;
  Index := Left;

  // если owner не лист дерева, то пробуем вставить в дочерний узел
  if HasChildrens(Owner^) then
  begin
    Node := Owner.Childrens[Index];
    Result := Insert(Node, Value, Lifting);
    if not Result then
      Exit;
    if not Lifting then
    begin
      Owner.Childrens[Index] := Node;
      Exit;
    end;
  end
  else
  begin
    Node := nil;
  end;

  // если есть место в текущем узле, вставляем новое значение
  if Owner.ValueCount < CAPACITY then
  begin
    Lifting := False;
    N := Owner.ValueCount - Index;
    if N > 0 then
    begin
      MovePtrs(Owner^.Values[Index], Owner^.Values[Index + 1], N);
      MovePtrs(Owner.Childrens[Index + 1], Owner.Childrens[Index + 2], N);
    end;
    Owner.Values[Index] := Value;
    Owner.Childrens[Index + 1] := Node;
    Inc(Owner.ValueCount);
  end
  else
  begin // иначе - разбиваем текущий узел на пополам
    Lifting := True;
    SiblingNode := NewNode(nil);
    Owner.ValueCount := ORDER;
    SiblingNode.ValueCount := ORDER;

    // если значение вставляется в младшую половину
    if Index < ORDER then
    begin
      // перемещаем старшую половину в новый элемент
      MovePtrs(Owner.Values[ORDER], SiblingNode.Values[0], ORDER);
      MovePtrs(Owner.Childrens[ORDER], SiblingNode.Childrens[0], ORDER + 1);
      // вставляем поднятые значения в текущий элемент
      N := ORDER - Index;
      if N > 0 then
      begin
        MovePtrs(Owner.Values[Index], Owner.Values[Index + 1], N);
        MovePtrs(Owner.Childrens[Index + 1], Owner.Childrens[Index + 2], N);
      end;
      Owner.Values[Index] := Value;
      Owner.Childrens[Index + 1] := Node;
      // поднимаем средний элемент на уровень выше
      Value := Owner.Values[ORDER];
      Owner.Values[ORDER] := nil;// clean
      Owner := SiblingNode;
    end
    else if Index > ORDER then
    begin
      // перемещаем старшую половину в новый элемент
      if ORDER > 1 then
        MovePtrs(Owner.Values[ORDER + 1], SiblingNode.Values[0], ORDER - 1);
      MovePtrs(Owner.Childrens[ORDER + 1], SiblingNode.Childrens[0], ORDER);
      Dec(Index, ORDER + 1);
      // вставляем поднятые значения в новый элемент
      N := (ORDER - 1) - Index;
      if N > 0 then
      begin
        MovePtrs(SiblingNode.Values[Index], SiblingNode.Values[Index + 1], N);
        MovePtrs(SiblingNode.Childrens[Index + 1], SiblingNode.Childrens[Index + 2], N);
      end;
      SiblingNode.Values[Index] := Value;
      SiblingNode.Childrens[Index + 1] := Node;
      // поднимаем средний элемент на уровень выше
      Value := Owner.Values[ORDER];
      Owner.Values[ORDER] := nil;// clean
      Owner := SiblingNode;
    end
    else {if Index = Order then}
    begin
      // перемещаем старшую половину в новый элемент
      MovePtrs(Owner.Values[ORDER], SiblingNode.Values[0], ORDER);
      MovePtrs(Owner.Childrens[ORDER + 1], SiblingNode.Childrens[1], ORDER);
      SiblingNode.Childrens[0] := Node;
      Owner.Values[ORDER] := nil;// clean
      Owner := SiblingNode;
    end;
  end;
end;

{ TBTreeEnumerator }

constructor TBTreeEnumerator.Create(ATree: TBTree);
begin
  FParentStack := TStack.Create;
  FIndexStack := TStack.Create;
  FTree := ATree;
  FNode := ATree.FRoot;
  FIndex := -1;

  FParentStack.Push(nil);
  FIndexStack.Push(Pointer(FIndex));
end;

destructor TBTreeEnumerator.Destroy;
begin
  FParentStack.Free;
  FIndexStack.Free;
  inherited;
end;

function TBTreeEnumerator.GetCurrent: Pointer;
begin
  Result := FNode.Values[FIndex];
end;

function TBTreeEnumerator.MoveNext: Boolean;
begin
  // прямой обход дерева
  if Assigned(FNode) then
  begin
    Inc(FIndex);
    while Assigned(FNode.Childrens[FIndex]) do
    begin
      FParentStack.Push(FNode);
      FIndexStack.Push(Pointer(FIndex));
      FNode := FNode.Childrens[FIndex];
      FIndex := 0;
    end;

    while Assigned(FNode) and (FIndex >= FNode.ValueCount) do
    begin
      FIndex := Integer(FIndexStack.Pop);
      FNode := FParentStack.Pop;
    end;
  end;
  Result := Assigned(FNode);
end;

end.

