unit contact_model;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, Variants, Classes, Contnrs, isoft.protohelper;

type
  TProtoValues = array of Variant;

  { TAddress }

  TAddress = class
  private
    FStreet: String;
    FCity: String;
    function GetProtoValues: TProtoValues;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetProtoValues(const Values: TProtoValues);
    function ToProtoValues: TProtoValues;
    property Street: String read FStreet write FStreet;
    property City: String read FCity write FCity;
  end;

  { TContact }

  TContact = class
  private
    FID: Integer;
    FName: String;
    FAddress: TAddress;
    function GetProtoValues: TProtoValues;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetProtoValues(const Values: TProtoValues);
    function ToProtoValues: TProtoValues;
    property ID: Integer read FID write FID;
    property Name: String read FName write FName;
    property Address: TAddress read FAddress write FAddress;
  end;

  { TCompany }

  TCompany = class
  private
    FName: String;
    FContacts: TObjectList; // Lista de TContact
    function GetProtoValues: TProtoValues;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetProtoValues(const Values: TProtoValues);
    function ToProtoValues: TProtoValues;
    procedure AddContact(const Contact: TContact);
    property Name: String read FName write FName;
    property Contacts: TObjectList read FContacts;
  end;


implementation

{ TAddress }

constructor TAddress.Create;
begin
  FStreet := '';
  FCity := '';
end;

destructor TAddress.Destroy;
begin
  inherited Destroy;
end;


function TAddress.GetProtoValues: TProtoValues;
begin
  // Protobuf: Field 1 = Street, Field 2 = City
  SetLength(Result, 2);

  // CORREÇÃO: Passa a string simples. O TProtoHelper principal
  // (que chama GetProtoValues) fará a serialização binária correta.
  Result[0] := FStreet; // String simples
  Result[1] := FCity;   // String simples
end;

/// contact_model.pas - TAddress.SetProtoValues (FINAL E CORRIGIDO)
procedure TAddress.SetProtoValues(const Values: TProtoValues);
var
  PayloadBytes: TBytes;
  SubBytes: Variant;
begin
  // =========================================================
  // CAMPO 1 (Street)
  // =========================================================
  if Length(Values) > 0 then
  begin
    // Verifica se o campo 1 é um array válido
    if VarIsArray(Values[0]) and (VarArrayHighBound(Values[0], 1) >= 0) then
    begin
        // Verifica o tipo do payload interno (byte array)
        if (VarType(Values[0][0]) and varTypeMask) = varByte then
        begin
          SubBytes := Values[0][0]; // Acessa o payload
          PayloadBytes := TProtoHelper.VarArrayAsBytes(SubBytes);
          FStreet := TProtoHelper.BytesToUTF8(PayloadBytes);
        end;
    end;
  end; // FIM DO CAMPO 1. Não tem 'Exit'


  // =========================================================
  // CAMPO 2 (City)
  // =========================================================
  if Length(Values) > 1 then
  begin
    // Verifica se o campo 2 é um array válido
    if VarIsArray(Values[1]) and (VarArrayHighBound(Values[1], 1) >= 0) then
    begin
        // Verifica o tipo do payload interno (byte array)
        if (VarType(Values[1][0]) and varTypeMask) = varByte then
        begin
          SubBytes := Values[1][0]; // Acessa o payload
          PayloadBytes := TProtoHelper.VarArrayAsBytes(SubBytes);
          FCity := TProtoHelper.BytesToUTF8(PayloadBytes);
        end;
    end;
  end;

  // O processamento termina aqui.
end;

function TAddress.ToProtoValues: TProtoValues;
begin
  result := GetProtoValues;
end;

{ TContact }

constructor TContact.Create;
begin
  FID := 0;
  FName := '';
  FAddress := TAddress.Create;
end;

destructor TContact.Destroy;
begin
  FAddress.Free;
  inherited Destroy;
end;

function TContact.GetProtoValues: TProtoValues;
begin
  // Protobuf: Field 1 = ID, Field 2 = Name, Field 3 = Address
  SetLength(Result, 3);
  // Field 1 (ID)
  Result[0] := FID;
  // Field 2 (Name) - TProtoHelper espera Variant(String) e serializa para Wire Type 2
  Result[1] := FName;
  // Field 3 (Address) - Submensagem (Wire Type 2)
  Result[2] := TProtoHelper.Serialize(FAddress.GetProtoValues);
end;

// contact_model.pas - TContact.SetProtoValues (Versão Clean Code)
procedure TContact.SetProtoValues(const Values: TProtoValues);
var
  SubBytes: Variant;
  SubVals: TProtoValues;
begin
  // FIELD 1: ID (Varint)
  // Assumimos que o campo 1 (ID) existe no índice 0
  if Length(Values) > 0 then
    FID := Values[0];

  // =========================================================
  // FIELD 2: Name (String) - Campo 2
  // =========================================================
  try
    SubBytes := TProtoHelper.GetSubBytesSafe(Values, 2); // Acesso Seguro
    FName := TProtoHelper.BytesToUTF8(TProtoHelper.VarArrayAsBytes(SubBytes));
  except
    on EProtocolViolation do
      // Se quiser que o campo possa ser opcional, trate a exceção aqui,
      // mas se o protocolo for rígido, deixe a exceção propagar.
      raise;
  end;

  // =========================================================
  // FIELD 3: Address (Submensagem) - Campo 3
  // =========================================================
  try
    SubBytes := TProtoHelper.GetSubBytesSafe(Values, 3); // Acesso Seguro

    if not Assigned(FAddress) then
      FAddress := TAddress.Create;

    // Desserialização recursiva
    SubVals := TProtoHelper.Deserialize(TProtoHelper.VarArrayAsBytes(SubBytes));
    FAddress.SetProtoValues(SubVals);
  except
    on EProtocolViolation do
      raise; // Deixa o erro de protocolo claro.
  end;
end;

function TContact.ToProtoValues: TProtoValues;
begin
  result := GetProtoValues;
end;


{ TCompany }

constructor TCompany.Create;
begin
  FName := 'Isoft Sistemas';
  FContacts := TObjectList.Create(True);
end;

destructor TCompany.Destroy;
begin
  FContacts.Free;
  inherited Destroy;
end;

function TCompany.GetProtoValues: TProtoValues;
var
  i: Integer;
  Contact: TContact;
  ContactVals: Variant;
begin
  // Protobuf: Field 1 = Name, Field 2 = repeated Contact
  SetLength(Result, 2);

  // Field 1 (Name)
  Result[0] := FName;

  // Field 2 (repeated Contact) - Cria um Variant array of Variant
  if FContacts.Count > 0 then
  begin
    ContactVals := VarArrayCreate([0, FContacts.Count - 1], varVariant);

    for i := 0 to FContacts.Count - 1 do
    begin
      Contact := FContacts[i] as TContact;
      // Armazena o TProtoValues de cada contato no array de Variant
      ContactVals[i] := Contact.GetProtoValues;
    end;
    Result[1] := ContactVals;
  end;
end;

procedure TCompany.SetProtoValues(const Values: TProtoValues);
var
  SubBytes: Variant;
  SubVals: TProtoValues;
  Contact: TContact;
  i: Integer;
begin
  // FIELD 1 (Name)
  // ... (Você precisará de lógica similar à de TContact para desserializar FName)

  // FIELD 2 (repeated Contact)
  if (Length(Values) > 1) and VarIsArray(Values[1]) and
     ((VarType(Values[1]) and not varArray) = varVariant) // Checa Variant array of Variant
  then
  begin
    FContacts.Clear; // Limpa a lista antes de popular

    // Itera sobre o Variant array of Variant
    for i := VarArrayLowBound(Values[1], 1) to VarArrayHighBound(Values[1], 1) do
    begin
      // Cada elemento é um array de byte (payload binário do contato)
      SubBytes := Values[1][i];

      // Desserializa o payload binário do contato para TProtoValues
      SubVals := TProtoHelper.Deserialize(TProtoHelper.VarArrayAsBytes(SubBytes));

      // Cria e popula o novo objeto TContact
      Contact := TContact.Create;
      Contact.SetProtoValues(SubVals);

      // Adiciona à lista
      FContacts.Add(Contact);
    end;
  end;
end;

function TCompany.ToProtoValues: TProtoValues;
begin
  result := GetProtoValues;
end;

procedure TCompany.AddContact(const Contact: TContact);
begin
  // O TObjectList já está configurado para ser 'dono' dos objetos,
  // então basta adicionar o TContact fornecido à lista.
  FContacts.Add(Contact);
end;

end.
