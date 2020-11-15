{------------------------------------------------------------------------------
Component Installer app
Developed by Rodrigo Depine Dalpiaz (digao dalpiaz)
Delphi utility app to auto-install component packages into IDE

https://github.com/digao-dalpiaz/CompInstall

Please, read the documentation at GitHub link.
------------------------------------------------------------------------------}

unit UFrm;

interface

uses Vcl.Forms, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.Buttons,
  Vcl.Controls, System.Classes,
  //
  Vcl.Graphics, UDefinitions;

type
  TFrm = class(TForm)
    LbComponentName: TLabel;
    EdCompName: TEdit;
    LbDelphiVersion: TLabel;
    EdDV: TComboBox;
    Ck64bit: TCheckBox;
    LbInstallLog: TLabel;
    BtnInstall: TBitBtn;
    BtnExit: TBitBtn;
    M: TRichEdit;
    LbVersion: TLabel;
    LinkLabel1: TLinkLabel;
    LbComponentVersion: TLabel;
    EdCompVersion: TEdit;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BtnExitClick(Sender: TObject);
    procedure BtnInstallClick(Sender: TObject);
    procedure LinkLabel1LinkClick(Sender: TObject; const Link: string;
      LinkType: TSysLinkType);
    procedure FormShow(Sender: TObject);
  private
    D: TDefinitions;

    procedure LoadDelphiVersions;
  public
    procedure SetButtons(bEnabled: Boolean);
    procedure Log(const A: string; bBold: Boolean = True; Color: TColor = clBlack);
  end;

var
  Frm: TFrm;

implementation

{$R *.dfm}

uses UCommon, UProcess, UGitHub,
  System.SysUtils, System.Win.Registry,
  Winapi.Windows, Winapi.Messages, Winapi.ShellApi, System.UITypes,
  Vcl.Dialogs;

//-- Object to use in Delphi Version ComboBox
type TDelphiVersion = class
  InternalNumber: string;
end;
//--

procedure TFrm.Log(const A: string; bBold: Boolean = True; Color: TColor = clBlack);
begin
  //log text at RichEdit control, with some formatted rules

  M.SelStart := Length(M.Text);

  if bBold then
    M.SelAttributes.Style := [fsBold]
  else
    M.SelAttributes.Style := [];

  M.SelAttributes.Color := Color;

  M.SelText := A+#13#10;

  SendMessage(M.Handle, WM_VSCROLL, SB_BOTTOM, 0); //scroll to bottom
end;

procedure TFrm.FormCreate(Sender: TObject);
begin
  AppDir := ExtractFilePath(Application.ExeName);

  D := TDefinitions.Create;
  try
    D.LoadIniFile(AppDir+'CompInstall.ini');

    EdCompName.Text := D.CompName;
    EdCompVersion.Text := D.CompVersion;

    LoadDelphiVersions; //load list of delphi versions

    Ck64bit.Visible := D.HasAny64bit;

  except
    BtnInstall.Enabled := False;
    raise;
  end;
end;

procedure TFrm.FormDestroy(Sender: TObject);
var I: Integer;
begin
  D.Free;

  //--Free objects of delphi versions list
  for I := 0 to EdDV.Items.Count-1 do
    EdDV.Items.Objects[I].Free;
  //--
end;

procedure TFrm.FormShow(Sender: TObject);
begin
  CheckGitHubUpdate(D.GitHubRepository, D.CompVersion);
end;

procedure TFrm.LinkLabel1LinkClick(Sender: TObject; const Link: string;
  LinkType: TSysLinkType);
begin
  ShellExecute(0, '', PChar(Link), '', '', SW_SHOWNORMAL);
end;

procedure TFrm.BtnExitClick(Sender: TObject);
begin
  Close;
end;

procedure TFrm.LoadDelphiVersions;
var R: TRegistry;

  procedure Add(const Key, IniVer, Text: string);
  var DV: TDelphiVersion;
  begin
    if R.KeyExists(Key) and HasInList(IniVer, D.DelphiVersions) then
    begin
      DV := TDelphiVersion.Create;
      DV.InternalNumber := Key;
      EdDV.Items.AddObject(Text, DV);
    end;
  end;

begin
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
    end;
  finally
    R.Free;
  end;

  if EdDV.Items.Count=0 then
    raise Exception.Create('No version of Delphi installed or supported');

  EdDV.ItemIndex := EdDV.Items.Count-1; //select last version
end;

procedure TFrm.BtnInstallClick(Sender: TObject);
var P: TProcess;
begin
  M.Clear; //clear log

  if EdDV.ItemIndex=-1 then
  begin
    MessageDlg('Select one Delphi version', mtError, [mbOK], 0);
    EdDV.SetFocus;
    Exit;
  end;

  //check if Delphi IDE is running
  if FindWindow('TAppBuilder', nil)<>0 then
  begin
    MessageDlg('Please, close Delphi IDE first!', mtError, [mbOK], 0);
    Exit;
  end;

  SetButtons(False);
  Refresh;

  P := TProcess.Create(D,
    TDelphiVersion(EdDV.Items.Objects[EdDV.ItemIndex]).InternalNumber,
    Ck64bit.Checked and Ck64bit.Visible);

  P.Start;
end;

procedure TFrm.SetButtons(bEnabled: Boolean);
begin
  BtnInstall.Enabled := bEnabled;
  BtnExit.Enabled := bEnabled;
end;

end.
