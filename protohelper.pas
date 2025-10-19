unit protohelper;

{
  Design by...: Almir Lima
  Date........: 2025-10-16
  Description.: This Helper was developed for serialization and deserialization of a class to protobuf
                without the need to use 'Protoc' to generate the protocol.

  Serialize...: Data := TProtoHelper.Serialize( ProtoValues );
  Deserialize.: TProtoHelper.Deserialize( Data );
}

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, Variants, Classes;

type
  TProtoValues = array of Variant;

  EProtocolViolation = class(Exception);

  { TProtoHelper }
  TProtoHelper = class
  public
    class function Serialize(const Values: TProtoValues): TBytes;
    class function Deserialize(const Bytes: Variant): TProtoValues;

    class function VarArrayAsBytes(const V: Variant): TBytes;
    class function BytesToUTF8(const Data: TBytes): String;
    class function LoadBytesFromFile(const FileName: String): TBytes;
    class function SaveBytesToFile(const FileName: String; const Data: TBytes): Boolean;
    class function GetSubBytesSafe(const Values: TProtoValues; FieldIndex: Integer): Variant;
 end;

 { ===== Global Functions ===== }
 function  BytesOf(const S: UTF8String): TBytes;
 procedure AppendBytes(var Dest: TBytes; const Src: TBytes);
 function  EncodeVarint(Value: QWord): TBytes;
 function  EncodeFixed64(Value: Double): TBytes;
 function  VarArrayAsVariant(const Bytes: TBytes): Variant;
 function  ProtoVarArrayAdd(const V: Variant; const Item: Variant): Variant;
 function  StringToVarArray(const str: String): Variant;
 function  GetStringSafe(const Values: TProtoValues; FieldIndex: Integer): String;

implementation

const
  varAnsiStrHack = 256;

{ ===== Global Functions ===== }
function BytesOf(const S: UTF8String): TBytes;
begin

  SetLength(Result, Length(S));
  if Length(S) > 0 then Move(S[1], Result[0], Length(S));
end;

procedure AppendBytes(var Dest: TBytes; const Src: TBytes);
var
  OldLen, AddLen: Integer;
begin

  AddLen := Length(Src);
  if AddLen = 0 then Exit;

  OldLen := Length(Dest);
  SetLength(Dest, OldLen + AddLen);
  Move(Src[0], Dest[OldLen], AddLen);
end;

function EncodeVarint(Value: QWord): TBytes;
var
  B: Byte;
begin
  SetLength(Result, 0);
  repeat
    B := Value and $7F;
    Value := Value shr 7;
    if Value <> 0 then B := B or $80;
    AppendBytes(Result, TBytes([B]));
  until Value = 0;
end;

function EncodeFixed64(Value: Double): TBytes;
begin
  SetLength(Result, SizeOf(Value));
  Move(Value, Result[0], SizeOf(Value));
end;

function VarArrayAsVariant(const Bytes: TBytes): Variant;
var
  S: Variant;
begin
  if Length(Bytes) = 0 then
    Exit(VarArrayCreate([0, -1], varByte));

  S := VarArrayCreate([0, Length(Bytes) - 1], varByte);
  Move(Bytes[0], VarArrayLock(S)^, Length(Bytes));
  VarArrayUnlock(S);
  Result := S;
end;

function ProtoVarArrayAdd(const V: Variant; const Item: Variant): Variant;
var
  OldHigh: Integer;
begin
  if VarIsEmpty(V) or VarIsNull(V) or ((VarType(V) and varArray) = 0) then
  begin
    Result := VarArrayCreate([0, 0], varVariant);
    Result[0] := Item;
    Exit;
  end;

  Result := V;
  OldHigh := VarArrayHighBound(Result, 1);
  VarArrayRedim(Result, OldHigh + 1);
  Result[OldHigh + 1] := Item;
end;

function StringToVarArray(const str: String): Variant;
begin
  VarArrayAsVariant( BytesOf( UTF8Encode( str ) ) );
end;

// Abstracts all the logic of checking Variant/Array/Byte and converting to String.
function GetStringSafe(const Values: TProtoValues; FieldIndex: Integer): String;
var
  SubBytes: Variant;
  PayloadBytes: TBytes;
begin
  Result := '';

  // Direct and safe access that raises EProtocolViolation if the field is not in the expected format.
  try
    SubBytes := TProtoHelper.GetSubBytesSafe(Values, FieldIndex);
    PayloadBytes := TProtoHelper.VarArrayAsBytes(SubBytes);
    Result := TProtoHelper.BytesToUTF8(PayloadBytes);
  except
    // If the field is absent (EProtocolViolation), the default handling is to propagate,
    on EProtocolViolation do
      // For strict protocol: propagate the error.
      raise;
  end;
end;

{ ===== TProtoHelper: Load from File ===== }
class function TProtoHelper.LoadBytesFromFile(const FileName: String): TBytes;
var
  FS: TFileStream;
begin
  Result := nil;
  if not FileExists(FileName) then Exit;

  FS := nil;
  try
    FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    SetLength(Result, FS.Size);
    FS.Read(Result[0], FS.Size);
  finally
    FS.Free;
  end;
end;

{ ===== TProtoHelper: Save Bytes to File ===== }
class function TProtoHelper.SaveBytesToFile(const FileName: String; const Data: TBytes): Boolean;
var
  F: TFileStream;
begin

  Result := False;

  if Length(Data) = 0 then Exit;

  F := TFileStream.Create(FileName, fmCreate);
  try

    F.WriteBuffer(Data[0], Length(Data));

    Result := True;
  finally
    F.Free;
  end;
end;
{ ============================================================ }


{ ===== TProtoHelper: Public Conversion Functions ===== }
class function TProtoHelper.VarArrayAsBytes(const V: Variant): TBytes;
var
  Len: Integer;
begin
  SetLength(Result, 0);
  if not VarIsArray(V) then Exit;
  if VarArrayDimCount(V) <> 1 then Exit;
  Len := VarArrayHighBound(V, 1) + 1;
  if Len <= 0 then Exit;
  SetLength(Result, Len);
  Move(VarArrayLock(V)^, Result[0], Len);
  VarArrayUnlock(V);
end;

class function TProtoHelper.BytesToUTF8(const Data: TBytes): String;
var
  RawStr: RawByteString;
begin
  if Length(Data) = 0 then
  begin
    Result := '';
    Exit;
  end;

  // 1. Converts TBytes to RawByteString (Low-Level Pointer Move)
  SetLength(RawStr, Length(Data));
  Move(Data[0], RawStr[1], Length(Data));

  // 2. Converts RawByteString to String (Unicode/UTF-16) and decodes from UTF8
  Result := String( RawStr );
  System.UTF8Decode( Result );
end;

class function TProtoHelper.GetSubBytesSafe(const Values: TProtoValues; FieldIndex: Integer): Variant;
var
  ArrayIdx: Integer;
begin
  ArrayIdx := FieldIndex - 1;

  // 1. Checks if field exists
  if (Length(Values) <= ArrayIdx) then
    raise EProtocolViolation.Create(Format('Field %d missing in deserialization.', [FieldIndex]));

  // The value in the array must be an array of Variant (because of ProtoVarArrayAdd)
  if not VarIsArray(Values[ArrayIdx]) or (VarArrayHighBound(Values[ArrayIdx], 1) < 0) then
    raise EProtocolViolation.Create(Format('Field %d is not a valid array.', [FieldIndex]));

  // The actual payload is the first element (index 0) of this array
  Result := Values[ArrayIdx][0];

  // 2. Checks if the payload is of binary type (varByte)
  if (VarType(Result) and varTypeMask) <> varByte then
    raise EProtocolViolation.Create(Format('Field %d has unexpected type (not binary).', [FieldIndex]));
end;

{ ===== Serialization ===== }
class function TProtoHelper.Serialize(const Values: TProtoValues): TBytes;

  procedure AppendKey(var Dest: TBytes; FieldIndex, WireType: Integer);
  begin
    AppendBytes(Dest, EncodeVarint(QWord((FieldIndex shl 3) or WireType)));
  end;

  procedure AppendLenDelimited(var Dest: TBytes; FieldIndex: Integer; const Payload: TBytes);
  begin
    AppendKey(Dest, FieldIndex, 2);
    AppendBytes(Dest, EncodeVarint(Length(Payload)));
    AppendBytes(Dest, Payload);
  end;

var
  i: Integer;
  V: Variant;
  VarTElement: Integer;
  S: UTF8String;
  Payload: TBytes;
  j, Count: Integer;
  ContactVals: Variant;
begin
  SetLength(Result, 0);

  for i := 0 to High(Values) do
  begin
    V := Values[i];
    if VarIsEmpty(V) or VarIsNull(V) then Continue;

    VarTElement := VarType(V) and VarTypeMask;

    // ======== 1. CHECKING ARRAYS / SUBMESSAGES (Complex) ========
    if VarIsArray(V) and (VarArrayDimCount(V) = 1) then
    begin
      VarTElement := VarType(V) and not varArray;

      // (A) Nested message encoded as byte array
      if VarTElement = varByte then
      begin
        Payload := VarArrayAsBytes(V);
        if Length(Payload) > 0 then
          AppendLenDelimited(Result, i+1, Payload)
        else
          ;
        Continue;
      end;

      // (B) Submessage List (Variant Array) - REPEATED FIELD
      if VarTElement = varVariant then
      begin
        Count := VarArrayHighBound(V, 1) + 1;

        for j := 0 to Count - 1 do
        begin
          ContactVals := V[j];
          Payload := Serialize(TProtoValues(ContactVals));
          AppendLenDelimited(Result, i+1, Payload);
        end;
        Continue;
      end;
    end;

    // ======== 2. SIMPLE TYPE CHECKING (Strings) ========
    if (VarType(V) in [varString, varOleStr, varUString, varDispatch]) or
       (VarType(V) = varAnsiStrHack)
    then begin
      S := UTF8Encode(VarToStr(V));
      SetLength(Payload, 0);
      AppendBytes(Payload, BytesOf(S));
      AppendLenDelimited(Result, i+1, Payload);
      Continue;
    end;

    // ======== 3. SIMPLE TYPE CHECKING (Floats) ========
    if (VarTElement in [varDouble, varSingle, varCurrency]) then
    begin
      Continue;
    end;

    // ======== 4. SIMPLE TYPE CHECKING (Integer and Booleans) ========
    if (VarTElement in [varSmallint, varInteger, varShortInt, varLongWord, varInt64, varByte, varBoolean]) then
    begin
      AppendKey(Result, i+1, 0);
      AppendBytes(Result, EncodeVarint(QWord(Int64(V))));
      Continue;
    end;
  end;
end;

{ ===== Desserialization ===== }

class function TProtoHelper.Deserialize(const Bytes: Variant): TProtoValues;

  function DecodeVarint(const Buf: TBytes; var P: SizeInt): QWord;
  var
    Shift: Integer;
    B: Byte;
    Res: QWord;
  begin
    Res := 0;
    Shift := 0;
    while (P < Length(Buf)) do
    begin
      B := Buf[P];
      Inc(P);
      Res := Res or (QWord(B and $7F) shl Shift);
      if (B and $80) = 0 then Break;
      Inc(Shift, 7);
    end;
    Result := Res;
  end;

  function DecodeFixed64(const Buf: TBytes; var P: SizeInt): Double;
  begin
    if (P + 8) > Length(Buf) then Exit(0.0);
    Move(Buf[P], Result, 8);
    Inc(P, 8);
  end;

var
  Raw: TBytes;
  P: SizeInt;
  Key: QWord;
  FieldNo, Wire: Integer;
  Len: QWord;
  S: Variant;
  NeedLen: SizeInt;
  MaxField: Integer;
begin
  SetLength(Result, 0);

  if VarIsArray(Bytes) and ((VarType(Bytes) and VarTypeMask) = varByte) then
    Raw := VarArrayAsBytes(Bytes)
  else
  begin
    SetLength(Raw, 0);
    Exit;
  end;

  P := 0;
  MaxField := -1;

  // First pass: Finds largest FieldNo
  while P < Length(Raw) do
  begin
    Key := DecodeVarint(Raw, P);
    FieldNo := Integer(Key shr 3);
    Wire := Integer(Key and 7);
    if FieldNo > MaxField then MaxField := FieldNo;

    case Wire of
      0: begin DecodeVarint(Raw, P); end;
      1: begin Inc(P, 8); end;
      2: begin Len := DecodeVarint(Raw, P); Inc(P, Len); end;
      5: begin Inc(P, 4); end;
      else Break;
    end;
  end;

  if MaxField < 1 then Exit;
  SetLength(Result, MaxField);

  // Second pass: fill Result[FieldNo-1]
  P := 0;
  while P < Length(Raw) do
  begin
    Key := DecodeVarint(Raw, P);
    FieldNo := Integer(Key shr 3);
    Wire := Integer(Key and 7);
    if (FieldNo < 1) or (FieldNo > MaxField) then Break;

    case Wire of
      0: begin
          Result[FieldNo-1] := Int64(DecodeVarint(Raw, P));
         end;
      1: begin
          Result[FieldNo-1] := DecodeFixed64(Raw, P);
         end;
      2: begin
          Len := DecodeVarint(Raw, P);
          NeedLen := P + Len;
          if (Len > 0) and (NeedLen <= Length(Raw)) then
          begin
            S := VarArrayCreate([0, NeedLen - P - 1], varByte);
            Move(Raw[P], VarArrayLock(S)^, NeedLen - P);
            VarArrayUnlock(S);

            Result[FieldNo-1] := ProtoVarArrayAdd(Result[FieldNo-1], S);

            P := NeedLen;
          end
          else
          begin
            if VarIsEmpty(Result[FieldNo-1]) then
               Result[FieldNo-1] := VarArrayCreate([0, -1], varVariant);
          end;
         end;
      5: begin
          Inc(P, 4);
         end;
      else
        Break;
    end;
  end;
end;

end.
