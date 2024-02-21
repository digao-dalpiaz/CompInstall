unit UProcess;

interface

uses System.Classes, Vcl.Graphics, UDefinitions;

type
  TProcess = class(TThread)
  public
    constructor Create(D: TDefinitions;
      const InternalDelphiVersionKey: string; Flag64bit: Boolean);
  protected
    procedure Execute; override;
  private
    D: TDefinitions;
    InternalDelphiVersionKey: string;
    Flag64bit: Boolean;

    MSBuildExe: string;

    CompilerNotSupportBuilding: Boolean;

    procedure Log(const A: string; bBold: Boolean = True; Color: TColor = clBlack);

    procedure FindMSBuild;
    procedure Compile;
    procedure CompilePackage(P: TPackage; const aBat, aPlatform: string);
    procedure AddLibrary;
    procedure PublishFiles(P: TPackage; const aPlatform: string);
    procedure RegisterBPL(const aPackage: string);
    procedure OnLine(const Text: string);

    function GetOutputPath(const aPlatform: string): string;
    function GetBplDirectory: string;
  end;

implementation

uses System.Win.Registry, Winapi.Windows, System.SysUtils,
  UCommon, UCmdExecBuffer, System.IOUtils, Winapi.ShlObj,
  UFrm;

const
  COMPILING_ERROR_VERSION_NOT_SUPORTED = 'This version of the product does not support command line compiling';

constructor TProcess.Create(D: TDefinitions;
      const InternalDelphiVersionKey: string; Flag64bit: Boolean);
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

procedure TProcess.Log(const A: string; bBold: Boolean = True; Color: TColor = clBlack);
begin
  Synchronize(
    procedure
    begin
      Frm.Log(A, bBold, Color);
    end);
end;

procedure TProcess.Compile;
var
  R: TRegistry;
  aRootDir: string;
  aBat: string;

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

  if Flag64bit and not FileExists(TPath.Combine(aRootDir, 'bin\dcc64.exe')) then
    raise Exception.Create('Delphi 64 bit compiler not found');

  for P in D.Packages do
  begin
    CompilePackage(P, aBat, 'Win32');

    if Flag64bit and P.Allow64bit then
      CompilePackage(P, aBat, 'Win64');

    if P.Install then
      RegisterBPL(P.Name);
  end;
end;

procedure TProcess.CompilePackage(P: TPackage; const aBat, aPlatform: string);
var
  C: TCmdExecBuffer;
  aPath, aFile: string;
begin
  Log('Compile package '+P.Name+' ('+aPlatform+')');

  aPath := TPath.Combine(AppDir, P.Path); //if P.Path blank, Combine ignores automatically
  aFile := TPath.Combine(aPath, P.Name);

  C := TCmdExecBuffer.Create;
  try
    C.OnLine := OnLine;

    C.CommandLine :=
      Format('""%s" & "%s" "%s.dproj" /t:build /p:config=Release /p:platform=%s"',
      [aBat, MSBuildExe, aFile, aPlatform]);

    C.WorkDir := aPath;

    if not C.Exec then
      raise Exception.Create('Could not execute MSBUILD');

    if C.ExitCode<>0 then
      raise Exception.CreateFmt('Error compiling package %s (Exit Code %d)', [P.Name, C.ExitCode]);

    if CompilerNotSupportBuilding then
      raise Exception.Create(COMPILING_ERROR_VERSION_NOT_SUPORTED);
  finally
    C.Free;
  end;

  //publish files
  PublishFiles(P, aPlatform);

  Log('');
end;

procedure TProcess.OnLine(const Text: string);
begin
  //event for command line execution (line-by-line)
  Log(TrimRight(Text), False);

  //MSBUILD does not return error exit code when delphi compiler not supported, so here we check for string message error
  if Text.Contains(COMPILING_ERROR_VERSION_NOT_SUPORTED) then CompilerNotSupportBuilding := True;
end;

procedure TProcess.PublishFiles(P: TPackage; const aPlatform: string);
var
  RelativeFile, aSource, aDest: string;
begin
  for RelativeFile in P.PublishFiles do
  begin
    aSource := AppDir+RelativeFile;
    aDest := GetOutputPath(aPlatform)+'\'+ExtractFileName(RelativeFile);

    Log(Format('Copy file %s to %s', [RelativeFile{aSource}, aDest]), False, clPurple);
    TFile.Copy(aSource, aDest, True);
  end;
end;

procedure TProcess.AddLibrary;

  procedure AddKey(const aPlatform: string);
  var
    Key, A, Dir: string;
    R: TRegistry;
  const SEARCH_KEY = 'Search Path';
  begin
    Log('Add library path to '+aPlatform);

    Key := BDS_KEY+'\'+InternalDelphiVersionKey+'\Library\'+aPlatform;
    Dir := GetOutputPath(aPlatform);

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

function GetPublicDocs: string;
var
  Path: array[0..MAX_PATH] of Char;
begin
  if not ShGetSpecialFolderPath(0, Path, CSIDL_COMMON_DOCUMENTS, False) then
    raise Exception.Create('Could not find Public Documents folder location') ;

  Result := Path;
end;

function TProcess.GetBplDirectory: string;
var
  BplDir, PublicPrefix: string;
  FS: TFormatSettings;
begin
  FS := TFormatSettings.Create;
  FS.DecimalSeparator := '.';
  if StrToFloat(InternalDelphiVersionKey, FS)<=12 then //Delphi XE5 or below
    PublicPrefix := 'RAD Studio'
  else
    PublicPrefix := 'Embarcadero\Studio';

  BplDir := TPath.Combine(GetPublicDocs, PublicPrefix+'\'+InternalDelphiVersionKey+'\Bpl');

  if not DirectoryExists(BplDir) then
    raise Exception.CreateFmt('Public Delphi folder not found at: %s', [BplDir]);

  Result := BplDir;
end;

procedure TProcess.RegisterBPL(const aPackage: string);
var
  R: TRegistry;
  BplDir: string;
begin
  Log('Install BPL into IDE of '+aPackage);

  BplDir := GetBplDirectory;

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
const TOOLS_KEY = 'Software\Microsoft\MSBUILD\ToolsVersions';
var
  R: TRegistry;
  S: TStringList;
  I: Integer;
  Dir, aFile: string;
  Found: Boolean;
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

function TProcess.GetOutputPath(const aPlatform: string): string;
begin
  if not D.OutputPath.IsEmpty then
    Result := D.OutputPath
  else
    Result := '{PLATFORM}\{CONFIG}';

  Result := Result.Replace('{PLATFORM}', aPlatform);
  Result := Result.Replace('{CONFIG}', 'Release');

  Result := AppDir + Result;
end;

end.
