program test_protohelper;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Variants, contact_model, protohelper;

{ ===== Funções utilitárias ===== }

function BytesToHex(const Bytes: TBytes): String;
const
  HexChars: array[0..15] of Char = '0123456789ABCDEF';
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(Bytes) do
    Result += HexChars[Bytes[i] shr 4] + HexChars[Bytes[i] and $F];
end;

{ ===== TESTE PRINCIPAL ===== }

procedure Test;
var
  i: Integer;
  Contact1, Contact2: TContact;
  Company: TCompany;
  Data: TBytes;
begin

  Contact1 := TContact.Create;
  Contact1.ID             := 1;
  Contact1.Name           := 'Almir Lima';
  Contact1.Address.Street := 'Av. Brasil';
  Contact1.Address.City   := 'Cascavel';

  WriteLn('Contact1.GetProtoValues (', Length(Contact1.ToProtoValues), ' bytes):');

  // Serializa
  Data := TProtoHelper.Serialize( Contact1.ToProtoValues );

  WriteLn('Serialized (', Length(Data), ' bytes):');
  WriteLn(BytesToHex(Data));
  WriteLn('Arquivo salvo em: contact1.pb');
  WriteLn('----------------------------------------------------');
  TProtoHelper.SaveBytesToFile('contact1.pb', Data);

  // Desserializa
  Data := TProtoHelper.LoadBytesFromFile('contact1.pb');
  Contact1 := TContact.Create;
  Contact1.SetProtoValues(TProtoHelper.Deserialize(Data));

  WriteLn;
  WriteLn('Deserialized values: contact1.pb');
  WriteLn('ID....: ', Contact1.ID);
  WriteLn('Name..: ', Contact1.Name);
  WriteLn('Street: ', Contact1.Address.Street);
  WriteLn('City..: ', Contact1.Address.City);

  // 2. Contact2: CRIA um NOVO contato com DADOS DIFERENTES
  Contact2 := TContact.Create;
  Contact2.ID := 2; // DIFERENTE
  Contact2.Name := 'Paula Campos'; // DIFERENTE
  Contact2.Address.Street := 'Rua das Flores'; // DIFERENTE
  Contact2.Address.City := 'São Paulo'; // DIFERENTE

  WriteLn('----------------------------------------------------');

  WriteLn('Company');
  WriteLn('');

  Company := TCompany.Create;
  Company.AddContact( Contact1 );
  Company.AddContact( Contact2 );

  // Serializa Company
  WriteLn('Tentanto Serializar Company:');
  WriteLn('');
  Data := TProtoHelper.Serialize( Company.ToProtoValues );
  TProtoHelper.SaveBytesToFile('companies.pb', Data);

  WriteLn('Company Serialized (', Length(Data), ' bytes):');
  WriteLn(BytesToHex(Data));
  WriteLn('Company salvo em: companies.pb');
  WriteLn('----------------------------------------------------');


  // Desserializa
  Data := TProtoHelper.LoadBytesFromFile('companies.pb');
  Company.SetProtoValues( TProtoHelper.Deserialize( Data ) );

  WriteLn;
  WriteLn('Deserialized values: companies.pb');
  for i := 0 to Company.Contacts.Count - 1 do
  begin
    // FAZ O TYPE CAST EXPLÍCITO: TObjectList retorna TObject, precisamos de TContact
    Contact1 := Company.Contacts[i] as TContact;

    WriteLn('Index.: ', i );
    WriteLn('ID....: ', Contact1.ID); // Acessa o objeto Contact (TContact)
    WriteLn('Name..: ', Contact1.Name);
    WriteLn('Street: ', Contact1.Address.Street);
    WriteLn('City..: ', Contact1.Address.City);
    WriteLn('--------------------------------------------');
  end;
end;


begin
  Test;
 // ReadLn;
end.

