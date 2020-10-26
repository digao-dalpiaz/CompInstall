unit UProcess;

interface

uses System.Classes, UDefinitions, Vcl.Graphics;

type
  TProcess = class(TThread)
  public
    constructor Create(D: TDefinitions;
      const InternalDelphiVersionKey: String; Flag64bit: Boolean);
  protected
    procedure Execute; override;
  private
    D: TDefinitions;
    InternalDelphiVersionKey: String;
    Flag64bit: Boolean;

    MSBuildExe: String;

    procedure Log(const A: String; bBold: Boolean = True; Color: TColor = clBlack);

    procedure FindMSBuild;
    procedure Compile;
    procedure CompilePackage(P: TPackage; const aBat, aPlatform: String);
    procedure AddLibrary;
    procedure PublishFiles(P: TPackage; const aPlatform: String);
    procedure RegisterBPL(const aPackage: String);
    procedure OnLine(const Text: String);
  end;

implementation

uses System.Win.Registry, Winapi.Windows, System.SysUtils,
  UCommon, UCmdExecBuffer, System.IOUtils, Winapi.ShlObj,
  UFrm;

constructor TProcess.Create(D: TDefinitions;
      const InternalDelphiVersionKey: String; Flag64bit: Boolean);
begin
  inherited Create(True);
  FreeOnTerminate := True;

  Self.D := D;
  Self.InternalDelphiVersionKey := InternalDelphiVersionKey;
  Self.Flag64bit := Flag64bit;
end;

procedure TProcess.Execute;
begin
  try
    FindMSBuild; //find MSBUILD.EXE to use for compilation

    Log('COMPILE COMPONENT...');
    Compile;

    if D.AddLibrary then
      AddLibrary; //add library paths to Delphi

    Log('COMPONENT INSTALLED!', True, clGreen);
  except
    on E: Exception do
      Log('ERROR: '+E.Message, True, clRed);
  end;

  Synchronize(
    procedure
    begin
      Frm.SetButtons(True);
    end);
end;

procedure TProcess.Log(const A: String; bBold: Boolean = True; Color: TColor = clBlack);
begin
  Synchronize(
    procedure
    begin
      Frm.Log(A, bBold, Color);
    end);
end;

procedure TProcess.Compile;
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

  aBat := TPath.Combine(aRootDir, 'bin\rsvars.bat');
  if not FileExists(aBat) then
    raise Exception.Create('Internal Delphi batch file "rsvars" not found');

  for P in D.Packages do
  begin
    CompilePackage(P, aBat, 'Win32');

    if Flag64bit and P.Allow64bit then
      CompilePackage(P, aBat, 'Win64');

    if P.Install then
      RegisterBPL(P.Name);
  end;
end;

procedure TProcess.CompilePackage(P: TPackage; const aBat, aPlatform: String);
var C: TCmdExecBuffer;
begin
  Log('Compile package '+P.Name+' ('+aPlatform+')');

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

procedure TProcess.OnLine(const Text: String);
begin
  //event for command line execution (line-by-line)
  Log(TrimRight(Text), False);
end;

procedure TProcess.PublishFiles(P: TPackage; const aPlatform: String);
var A, aSource, aDest: String;
begin
  for A in P.PublishFiles do
  begin
    aSource := AppDir+A;
    aDest := AppDir+aPlatform+'\Release\'+A;

    Log(Format('Copy file %s to %s', [A{aSource}, aDest]), False, clPurple);
    TFile.Copy(aSource, aDest, True);
  end;
end;

procedure TProcess.AddLibrary;

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

  if Flag64bit then
    AddKey('Win64');
end;

function GetPublicDocs: String;
var Path: array[0..MAX_PATH] of Char;
begin
  if not ShGetSpecialFolderPath(0, Path, CSIDL_COMMON_DOCUMENTS, False) then
    raise Exception.Create('Could not find Public Documents folder location') ;

  Result := Path;
end;

procedure TProcess.RegisterBPL(const aPackage: String);
var R: TRegistry;
  BplDir, PublicPrefix: String;
  FS: TFormatSettings;
begin
  Log('Install BPL into IDE of '+aPackage);

  FS := TFormatSettings.Create;
  FS.DecimalSeparator := '.';
  if StrToFloat(InternalDelphiVersionKey, FS)<=12 then //Delphi XE5 or below
    PublicPrefix := 'RAD Studio'
  else
    PublicPrefix := 'Embarcadero\Studio';

  BplDir := TPath.Combine(GetPublicDocs, PublicPrefix+'\'+InternalDelphiVersionKey+'\Bpl');

  if not DirectoryExists(BplDir) then
    raise Exception.CreateFmt('Public Delphi folder not found at: %s', [BplDir]);

  R := TRegistry.Create;
  try
    R.RootKey := HKEY_CURRENT_USER;

    if not R.OpenKey(BDS_KEY+'\'+InternalDelphiVersionKey+'\Known Packages', False) then
      raise Exception.Create('Know Packages registry section not found');

    R.WriteString(TPath.Combine(BplDir, aPackage+'.bpl'), D.CompName);

  finally
    R.Free;
  end;
end;

procedure TProcess.FindMSBuild;
var R: TRegistry;
  S: TStringList;
  I: Integer;
  Dir, aFile: String;
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
          aFile := TPath.Combine(Dir, 'MSBUILD.EXE');
          if FileExists(aFile) then
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

  MSBuildExe := aFile;
end;

end.
