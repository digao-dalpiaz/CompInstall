unit UDelphiVersionCombo;

interface

uses Vcl.StdCtrls;

type
  TDelphiVersionItem = class
  public
    InternalNumber: string;
  end;

  TDelphiVersionComboLoader = class
  public
    class procedure Load(Combo: TComboBox; const DelphiVersions: string);
    class procedure Clear(Combo: TComboBox);
  end;

implementation

uses System.Win.Registry, Winapi.Windows, System.SysUtils,
  UCommon;

class procedure TDelphiVersionComboLoader.Load(Combo: TComboBox;
  const DelphiVersions: string);
var
  R: TRegistry;

  procedure Add(const Key, IniVer, Text: string);
  var
    Item: TDelphiVersionItem;
  begin
    if R.KeyExists(Key) and HasInList(IniVer, DelphiVersions) then
    begin
      Item := TDelphiVersionItem.Create;
      Item.InternalNumber := Key;
      Combo.Items.AddObject(Text, Item);
    end;
  end;

begin
  Clear(Combo);

  R := TRegistry.Create;
  try
    R.RootKey := HKEY_CURRENT_USER;
    if R.OpenKeyReadOnly(BDS_KEY) then
    begin
      Add('3.0', '2005', 'Delphi 2005');
      Add('4.0', '2006', 'Delphi 2006');
      Add('5.0', '2007', 'Delphi 2007');
      Add('6.0', '2009', 'Delphi 2009');
      Add('7.0', '2010', 'Delphi 2010');
      Add('8.0', 'XE', 'Delphi XE');
      Add('9.0', 'XE2', 'Delphi XE2');
      Add('10.0', 'XE3', 'Delphi XE3');
      Add('11.0', 'XE4', 'Delphi XE4');
      Add('12.0', 'XE5', 'Delphi XE5'); //public folder 'RAD Studio'
      Add('14.0', 'XE6', 'Delphi XE6'); //public folder 'Embarcadero\Studio'
      Add('15.0', 'XE7', 'Delphi XE7');
      Add('16.0', 'XE8', 'Delphi XE8');
      Add('17.0', '10', 'Delphi 10 Seattle');
      Add('18.0', '10.1', 'Delphi 10.1 Berlin');
      Add('19.0', '10.2', 'Delphi 10.2 Tokyo');
      Add('20.0', '10.3', 'Delphi 10.3 Rio');
      Add('21.0', '10.4', 'Delphi 10.4 Sydney');
      Add('22.0', '11', 'Delphi 11 Alexandria');
    end;
  finally
    R.Free;
  end;

  if Combo.Items.Count=0 then
    raise Exception.Create('No version of Delphi installed or supported');

  Combo.ItemIndex := Combo.Items.Count-1; //select last version
end;

class procedure TDelphiVersionComboLoader.Clear(Combo: TComboBox);
var
  I: Integer;
begin
  for I := 0 to Combo.Items.Count-1 do
    Combo.Items.Objects[I].Free;

  Combo.Items.Clear;
end;

end.
