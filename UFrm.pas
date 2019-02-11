unit UFrm;

interface

uses Vcl.Forms, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.Buttons,
  Vcl.Controls, System.Classes,
  //
  System.IniFiles, Vcl.Graphics;

type
  TFrm = class(TForm)
    Label1: TLabel;
    EdCompName: TEdit;
    Label2: TLabel;
    EdDV: TComboBox;
    Ck64bit: TCheckBox;
    Label3: TLabel;
    BtnInstall: TBitBtn;
    BtnExit: TBitBtn;
    M: TRichEdit;
    LbVersion: TLabel;
    LinkLabel1: TLinkLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BtnExitClick(Sender: TObject);
    procedure BtnInstallClick(Sender: TObject);
    procedure LinkLabel1LinkClick(Sender: TObject; const Link: string;
      LinkType: TSysLinkType);
  private
    AppDir: String;
    Ini: TIniFile;
    InternalDelphiVersionKey: String;
    MSBuild_Dir: String;

    procedure Compile;
    procedure CompilePackage(const aBat, aPackage, aPlatform: String);
    procedure LoadDelphiVersions;
    procedure AddLibrary;
    procedure Log(const A: String; bBold: Boolean = True; Color: TColor = clBlack);
    procedure PublishFiles(const aPlatform, aFiles: String);
    procedure RegisterBPL(const aPackage: String);
    procedure OnLine(const Text: String);
    procedure FindMSBuild;
  end;

var
  Frm: TFrm;

implementation

{$R *.dfm}

uses System.SysUtils, System.Win.Registry,
  Winapi.Windows, Winapi.Messages, Winapi.ShlObj, Winapi.ShellApi,
  Vcl.Dialogs, System.IOUtils, System.UITypes,
  UCmdExecBuffer;

const BDS_KEY = 'Software\Embarcadero\BDS';

//-- Object to use in Delphi Version ComboBox
type TDelphiVersion = class
  InternalNumber: String;
end;
//--

function HasInList(const Item, List: String): Boolean;
begin
  Result := Pos(';'+Item+';', ';'+List+';')>0;
end;

function PVToEnter(const A: String): String;
begin
  Result := StringReplace(A, ';', #13#10, [rfReplaceAll]);
end;

function AddBarDir(const Dir: String): String;
begin
  Result := IncludeTrailingPathDelimiter(Dir);
end;

procedure TFrm.Log(const A: String; bBold: Boolean = True; Color: TColor = clBlack);
begin
  M.SelStart := Length(M.Text);

  if bBold then
    M.SelAttributes.Style := [fsBold]
  else
    M.SelAttributes.Style := [];

  M.SelAttributes.Color := Color;

  M.SelText := A+#13#10;

  SendMessage(M.Handle, WM_VSCROLL, SB_BOTTOM, 0);

  //M.SelStart := Length(M.Text);
end;

procedure TFrm.FormCreate(Sender: TObject);
var aIniArq: String;
begin
  AppDir := ExtractFilePath(Application.ExeName);
  aIniArq := AppDir+'CompInstall.ini';
  try
    if not FileExists(aIniArq) then
      raise Exception.Create('Ini file not found');

    Ini := TIniFile.Create(aIniArq);

    EdCompName.Text := Ini.ReadString('General', 'Name', '');
    if EdCompName.Text='' then
      raise Exception.Create('Component name not specifyed at ini file');

    Ck64bit.Visible := Ini.ReadBool('General', 'Allow64bit', False);

    LoadDelphiVersions; //load list of delphi versions

    FindMSBuild;

  except
    BtnInstall.Enabled := False;
    raise;
  end;
end;

procedure TFrm.FormDestroy(Sender: TObject);
var I: Integer;
begin
  if Assigned(Ini) then Ini.Free;

  //--Free objects of delphi versions list
  for I := 0 to EdDV.Items.Count-1 do
    EdDV.Items.Objects[I].Free;
  //--
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
  aAllowedVersions: String;

  procedure Add(const Key, IniVer, Text: String);
  var DV: TDelphiVersion;
  begin
    if R.KeyExists(Key) and HasInList(IniVer, aAllowedVersions) then
    begin
      DV := TDelphiVersion.Create;
      DV.InternalNumber := Key;
      EdDV.Items.AddObject(Text, DV);
    end;
  end;

begin
  aAllowedVersions := Ini.ReadString('General', 'DelphiVersions', ''); //list splited by ";"
  if aAllowedVersions='' then
    raise Exception.Create('No Delphi version specifyed at ini file');

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
      Add('12.0', 'XE5', 'Delphi XE5');
      Add('14.0', 'XE6', 'Delphi XE6');
      Add('15.0', 'XE7', 'Delphi XE7');
      Add('16.0', 'XE8', 'Delphi XE8');
      Add('17.0', '10', 'Delphi 10 Seattle');
      Add('18.0', '10.1', 'Delphi 10.1 Berlin');
      Add('19.0', '10.2', 'Delphi 10.2 Tokyo');
      Add('20.0', '10.3', 'Delphi 10.3 Rio');
    end;
  finally
    R.Free;
  end;

  if EdDV.Items.Count=0 then
    raise Exception.Create('None Delphi version installed or supported');

  EdDV.ItemIndex := EdDV.Items.Count-1; //select last version
end;

procedure TFrm.BtnInstallClick(Sender: TObject);
begin
  M.Clear; //clear log

  if EdDV.ItemIndex=-1 then
  begin
    MessageDlg('Select a Delphi version', mtError, [mbOK], 0);
    EdDV.SetFocus;
    Exit;
  end;

  InternalDelphiVersionKey := TDelphiVersion(EdDV.Items.Objects[EdDV.ItemIndex]).InternalNumber;

  //check if Delphi IDE is running
  if FindWindow('TAppBuilder', nil)<>0 then
  begin
    MessageDlg('Please, close Delphi IDE first!', mtError, [mbOK], 0);
    Exit;
  end;

  BtnInstall.Enabled := False;
  BtnExit.Enabled := False;
  Refresh;

  try
    Log('COMPILE COMPONENT...');
    Compile;

    if Ini.ReadBool('General', 'AddLibrary', False) then
      AddLibrary;

    Log('COMPONENT INSTALLED!', True, clGreen);
  except
    on E: Exception do
      Log('ERROR: '+E.Message, True, clRed);
  end;

  BtnInstall.Enabled := True;
  BtnExit.Enabled := True;
end;

procedure TFrm.Compile;
var R: TRegistry;
  aRootDir: String;
  aBat, aPac, aSec, aPubFiles: String;

  S: TStringList;
begin
  R := TRegistry.Create;
  try
    R.RootKey := HKEY_CURRENT_USER;
    if not R.OpenKeyReadOnly(BDS_KEY+'\'+InternalDelphiVersionKey) then
      raise Exception.Create('Main Registry of delphi version not found');

    aRootDir := R.ReadString('RootDir');

    if aRootDir='' then
      raise Exception.Create('Can not get Delphi Root Folder');

  finally
    R.Free;
  end;

  if not DirectoryExists(aRootDir) then
    raise Exception.Create('Delphi root folder does not exist');

  aBat := AddBarDir(aRootDir)+'bin\rsvars.bat';
  if not FileExists(aBat) then
    raise Exception.Create('Internal Delphi Batch file "rsvars" not found');

  S := TStringList.Create;
  try
    S.Text := PVToEnter(Ini.ReadString('General', 'Packages', ''));

    if S.Count=0 then
      raise Exception.Create('No package found in the Ini file');

    for aPac in S do
    begin
      aSec := 'P_'+aPac; //section of package in the ini file

      aPubFiles := Ini.ReadString(aSec, 'PublishFiles', ''); //list of files to publish

      CompilePackage(aBat, aPac, 'Win32');
      PublishFiles('Win32', aPubFiles);

      if Ck64bit.Visible and Ck64bit.Checked then
        if Ini.ReadBool(aSec, 'Allow64bit', False) then
      begin
        CompilePackage(aBat, aPac, 'Win64');
        PublishFiles('Win64', aPubFiles);
      end;

      if Ini.ReadBool(aSec, 'Install', False) then
        RegisterBPL(aPac);
    end;
  finally
    S.Free;
  end;
end;

procedure TFrm.CompilePackage(const aBat, aPackage, aPlatform: String);
var C: TCmdExecBuffer;
  MSBuildExe: String;
begin
  Log('Compile package '+aPackage+' ('+aPlatform+')');

  MSBuildExe := AddBarDir(MSBuild_Dir)+'MSBUILD.EXE';

  C := TCmdExecBuffer.Create;
  try
    C.OnLine := OnLine;

    C.CommandLine :=
      Format('%s & "%s" "%s.dproj" /t:build /p:config=Release /p:platform=%s',
      [aBat, MSBuildExe, AppDir+aPackage, aPlatform]);

    C.WorkDir := AppDir;

    if not C.Exec then
      raise Exception.Create('Could not execute MSBUILD');

    if C.ExitCode<>0 then
      raise Exception.CreateFmt('Error compiling package %s (Exit Code %d)', [aPackage, C.ExitCode]);
  finally
    C.Free;
  end;

  Log('');
end;

procedure TFrm.OnLine(const Text: String);
begin
  Log(TrimRight(Text), False);
end;

procedure TFrm.AddLibrary;

  procedure AddKey(const aPlatform: String);
  var Key, A, Dir: String;
    R: TRegistry;
  const SEARCH_KEY = 'Search Path';
  begin
    Log('Add library path to '+aPlatform);

    Key := BDS_KEY+'\'+InternalDelphiVersionKey+'\Library\'+aPlatform;
    Dir := AppDir+aPlatform+'\Release';

    R := TRegistry.Create;
    try
      R.RootKey := HKEY_CURRENT_USER;

      if not R.OpenKey(Key, False) then
        raise Exception.Create('Registry key for Library '+aPlatform+' not found');

      A := R.ReadString(SEARCH_KEY);
      if not HasInList(Dir, A) then
        R.WriteString(SEARCH_KEY, A+';'+Dir);

    finally
      R.Free;
    end;
  end;

begin
  AddKey('Win32');

  if Ck64bit.Visible and Ck64bit.Checked then
    AddKey('Win64');
end;

function GetPublicDocs: String;
var Path: array[0..MAX_PATH] of Char;
begin
  if not ShGetSpecialFolderPath(0, Path, CSIDL_COMMON_DOCUMENTS, False) then
    raise Exception.Create('Could not find Public Documents folder location') ;

  Result := Path;
end;

procedure TFrm.RegisterBPL(const aPackage: String);
var R: TRegistry;
  BplDir: String;
begin
  Log('Install BPL into IDE of '+aPackage);

  BplDir := AddBarDir(GetPublicDocs)+'Embarcadero\Studio\'+InternalDelphiVersionKey+'\Bpl';

  R := TRegistry.Create;
  try
    R.RootKey := HKEY_CURRENT_USER;

    if not R.OpenKey(BDS_KEY+'\'+InternalDelphiVersionKey+'\Known Packages', False) then
      raise Exception.Create('Know Packages registry section not found');

    R.WriteString(AddBarDir(BplDir)+aPackage+'.bpl', EdCompName.Text);

  finally
    R.Free;
  end;
end;

procedure TFrm.PublishFiles(const aPlatform, aFiles: String);
var S: TStringList;
  A, aSource, aDest: String;
begin
  S := TStringList.Create;
  try
    S.Text := PVToEnter(aFiles);

    for A in S do
    begin
      aSource := AppDir+A;
      aDest := AppDir+aPlatform+'\Release\'+A;

      Log(Format('Copy file %s to %s', [A{aSource}, aDest]), False);
      TFile.Copy(aSource, aDest, True);
    end;

  finally
    S.Free;
  end;
end;

procedure TFrm.FindMSBuild;
var R: TRegistry;
  S: TStringList;
  I: Integer;
  Dir: String;
  Found: Boolean;
const TOOLS_KEY = 'Software\Microsoft\MSBUILD\ToolsVersions';
begin
  R := TRegistry.Create;
  try
    R.RootKey := HKEY_LOCAL_MACHINE;

    if not R.OpenKeyReadOnly(TOOLS_KEY) then
      raise Exception.Create('MSBUILD not found');

    S := TStringList.Create;
    try
      R.GetKeyNames(S);

      R.CloseKey;

      if S.Count=0 then
        raise Exception.Create('There is no .NET Framework version available');

      S.Sort;

      Found := False;
      for I := S.Count-1 downto 0 do
      begin
        if not R.OpenKeyReadOnly(TOOLS_KEY+'\'+S[I]) then
          raise Exception.Create('Internal error on reading .NET version key');

        Dir := R.ReadString('MSBuildToolsPath');
        R.CloseKey;

        if Dir<>'' then
        begin
          if FileExists(AddBarDir(Dir)+'MSBUILD.EXE') then
          begin
            //msbuild found
            Found := True;
            Break;
          end;
        end;
      end;

    finally
      S.Free;
    end;

  finally
    R.Free;
  end;

  if not Found then
    raise Exception.Create('MSBUILD not found in any .NET Framework version');

  MSBuild_Dir := Dir;

  //Log('MSBUILD path: '+MSBuild_Dir);
end;

end.
