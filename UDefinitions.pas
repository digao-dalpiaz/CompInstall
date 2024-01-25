unit UDefinitions;

interface

uses System.Generics.Collections, System.Classes;

const DEFINITIONS_VERSION = 2; //current definitions template

type
  TPackage = class
  public
    Name: string;
    Path: string;
    Allow64bit: Boolean;
    PublishFiles: TStringList;
    Install: Boolean;

    constructor Create;
    destructor Destroy; override;
  end;
  TPackages = class(TObjectList<TPackage>);

  TDefinitions = class
  public
    IniVersion: Integer;
    CompName: string;
    CompVersion: string;
    DelphiVersions: string;
    AddLibrary: Boolean;
    OutputPath: string;
    Packages: TPackages;

    GitHubRepository: string;

    procedure LoadIniFile(const aFile: string);

    function HasAny64bit: Boolean;

    constructor Create;
    destructor Destroy; override;
  end;

implementation

uses System.IniFiles, System.SysUtils;

function PVToEnter(const A: string): string;
begin
  //replaces all ";" to ENTER definition
  Result := StringReplace(A, ';', #13#10, [rfReplaceAll]);
end;

procedure TDefinitions.LoadIniFile(const aFile: string);
var
  Ini: TIniFile;
  A, Sec: string;
  S: TStringList;
  P: TPackage;
begin
  if not FileExists(aFile) then
    raise Exception.Create('Ini file not found');

  Ini := TIniFile.Create(aFile);
  try
    IniVersion := Ini.ReadInteger('Template', 'IniVersion', 1);
    if IniVersion>DEFINITIONS_VERSION then
      raise Exception.Create('Unsupported ini version. You probably need to update Component Installer!');

    CompName := Ini.ReadString('General', 'Name', '');
    if CompName='' then
      raise Exception.Create('Component name not specifyed at ini file');

    CompVersion := Ini.ReadString('General', 'Version', '');
    if CompVersion='' then
      raise Exception.Create('Component version not specifyed at ini file');

    DelphiVersions := Ini.ReadString('General', 'DelphiVersions', ''); //splitted by ";"
    if DelphiVersions='' then
      raise Exception.Create('No Delphi version specifyed at ini file');

    AddLibrary := Ini.ReadBool('General', 'AddLibrary', False);
    OutputPath := Ini.ReadString('General', 'OutputPath', '');

    S := TStringList.Create;
    try
      S.Text := PVToEnter( Ini.ReadString('General', 'Packages', '') );
      if S.Count=0 then
        raise Exception.Create('No package found in the ini file');

      for A in S do
      begin
        P := TPackage.Create;
        Packages.Add(P);

        Sec := 'P_'+A;

        P.Name := A;
        P.Path := Ini.ReadString(Sec, 'Path', '');
        P.Allow64bit := Ini.ReadBool(Sec, 'Allow64bit', False);
        P.PublishFiles.Text := PVToEnter( Ini.ReadString(Sec, 'PublishFiles', '') );
        P.Install := Ini.ReadBool(Sec, 'Install', False);
      end;

    finally
      S.Free;
    end;

    GitHubRepository := Ini.ReadString('GitHub', 'Repository', '');

  finally
    Ini.Free;
  end;
end;

{ TDefinitions }

constructor TDefinitions.Create;
begin
  inherited;
  Packages := TPackages.Create;
end;

destructor TDefinitions.Destroy;
begin
  Packages.Free;
  inherited;
end;

function TDefinitions.HasAny64bit: Boolean;
var
  P: TPackage;
begin
  Result := False;

  for P in Packages do
    if P.Allow64bit then
    begin
      Result := True;
      Break;
    end;
end;

{ TPackage }

constructor TPackage.Create;
begin
  inherited;
  PublishFiles := TStringList.Create;
end;

destructor TPackage.Destroy;
begin
  PublishFiles.Free;
  inherited;
end;

end.
