unit UFrm;

interface

uses Vcl.Forms, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.Buttons,
  Vcl.Controls, System.Classes,
  //
  Vcl.Graphics, UDefinitions;

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
    InternalDelphiVersionKey: String;
    MSBuild_Dir: String;

    D: TDefinitions;

    procedure Compile;
    procedure CompilePackage(P: TPackage; const aBat, aPlatform: String);
    procedure LoadDelphiVersions;
    procedure AddLibrary;
    procedure Log(const A: String; bBold: Boolean = True; Color: TColor = clBlack);
    procedure PublishFiles(P: TPackage; const aPlatform: String);
    procedure RegisterBPL(const aPackage: String);
    procedure OnLine(const Text: String);
    procedure FindMSBuild;
    function Is64bit_Set: Boolean;
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
const SEP = ';';
begin
  //returns if Item is contained in the List splited by SEP character
  Result := Pos(SEP+Item+SEP, SEP+List+SEP)>0;
end;

function AddBarDir(const Dir: String): String;
begin
  //just a smaller function shortcut
  Result := IncludeTrailingPathDelimiter(Dir);
end;

procedure TFrm.Log(const A: String; bBold: Boolean = True; Color: TColor = clBlack);
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

    LoadDelphiVersions; //load list of delphi versions

    Ck64bit.Visible := D.HasAny64bit;

    FindMSBuild; //find MSBUILD.EXE to use for compilation

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

procedure TFrm.LinkLabel1LinkClick(Sender: TObject; const Link: string;
  LinkType: TSysLinkType);
begin
  ShellExecute(0, '', PChar(Link), '', '', SW_SHOWNORMAL);
end;

procedure TFrm.BtnExitClick(Sender: TObject);
begin
  Close;
end;

function TFrm.Is64bit_Set: Boolean;
begin
  Result := Ck64bit.Checked and Ck64bit.Visible;
end;

procedure TFrm.LoadDelphiVersions;
var R: TRegistry;

  procedure Add(const Key, IniVer, Text: String);
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

    if D.AddLibrary then
      AddLibrary; //add library paths to Delphi

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
  aBat: String;

  P: TPackage;
begin
  R := TRegistry.Create;
  try
    R.RootKey := HKEY_CURRENT_USER;
    if not R.OpenKeyReadOnly(BDS_KEY+'\'+InternalDelphiVersionKey) then
      raise Exception.Create('Main registry of Delphi version not found');

    aRootDir := R.ReadString('RootDir');

    if aRootDir='' then
      raise Exception.Create('Unable to get Delphi root folder');

  finally
    R.Free;
  end;

  if not DirectoryExists(aRootDir) then
    raise Exception.Create('Delphi root folder does not exist');

  aBat := AddBarDir(aRootDir)+'bin\rsvars.bat';
  if not FileExists(aBat) then
    raise Exception.Create('Internal Delphi batch file "rsvars" not found');

  for P in D.Packages do
  begin
      CompilePackage(P, aBat, 'Win32');

      if Is64bit_Set and P.Allow64bit then
        CompilePackage(P, aBat, 'Win64');

      if P.Install then
        RegisterBPL(P.Name);
  end;
end;

procedure TFrm.CompilePackage(P: TPackage; const aBat, aPlatform: String);
var C: TCmdExecBuffer;
  MSBuildExe: String;
begin
  Log('Compile package '+P.Name+' ('+aPlatform+')');

  MSBuildExe := AddBarDir(MSBuild_Dir)+'MSBUILD.EXE';

  C := TCmdExecBuffer.Create;
  try
    C.OnLine := OnLine;

    C.CommandLine :=
      Format('%s & "%s" "%s.dproj" /t:build /p:config=Release /p:platform=%s',
      [aBat, MSBuildExe, AppDir+P.Name, aPlatform]);

    C.WorkDir := AppDir;

    if not C.Exec then
      raise Exception.Create('Could not execute MSBUILD');

    if C.ExitCode<>0 then
      raise Exception.CreateFmt('Error compiling package %s (Exit Code %d)', [P.Name, C.ExitCode]);
  finally
    C.Free;
  end;

  //publish files
  PublishFiles(P, aPlatform);

  Log('');
end;

procedure TFrm.OnLine(const Text: String);
begin
  //event for command line execution (line-by-line)
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
        raise Exception.Create('Registry key for library '+aPlatform+' not found');

      A := R.ReadString(SEARCH_KEY);
      if not HasInList(Dir, A) then
        R.WriteString(SEARCH_KEY, A+';'+Dir);

    finally
      R.Free;
    end;
  end;

begin
  AddKey('Win32');

  if Is64bit_Set then
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

    R.WriteString(AddBarDir(BplDir)+aPackage+'.bpl', D.CompName);

  finally
    R.Free;
  end;
end;

procedure TFrm.PublishFiles(P: TPackage; const aPlatform: String);
var A, aSource, aDest: String;
begin
  for A in P.PublishFiles do
  begin
    aSource := AppDir+A;
    aDest := AppDir+aPlatform+'\Release\'+A;

    Log(Format('Copy file %s to %s', [A{aSource}, aDest]), False);
    TFile.Copy(aSource, aDest, True);
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

      S.Sort; //sort msbuild versions

      Found := False;
      for I := S.Count-1 downto 0 do //iterate versions from last to first
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
